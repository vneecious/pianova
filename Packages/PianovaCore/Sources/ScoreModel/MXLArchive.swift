import Compression
import Foundation

/// Reads the zip envelope a compressed MusicXML (.mxl) comes in (rule 146).
///
/// Foundation ships no zip reader, and a dependency for two stable headers is
/// a bad trade: only what .mxl files actually use is read here — stored and
/// deflated entries, found through the central directory.
enum MXLArchive {
  /// Whether the bytes start like a zip archive.
  static func isZip(_ data: Data) -> Bool {
    data.count >= 4 && data.prefix(4).elementsEqual([0x50, 0x4B, 0x03, 0x04])
  }

  /// The MusicXML inside an .mxl: what the container points at, or the first
  /// score-looking entry when the container is missing.
  static func musicXML(in data: Data) -> Data? {
    let files = entries(in: data)

    if let container = files["META-INF/container.xml"],
      let path = rootfilePath(in: container),
      let rooted = files[path]
    {
      return rooted
    }

    return
      files
      .filter { name, _ in
        let lowered = name.lowercased()
        return !name.hasPrefix("META-INF/")
          && (lowered.hasSuffix(".xml") || lowered.hasSuffix(".musicxml"))
      }
      .min { $0.key < $1.key }?
      .value
  }

  /// Every file in the archive, by path.
  static func entries(in data: Data) -> [String: Data] {
    let bytes = [UInt8](data)
    guard let directory = centralDirectoryOffset(bytes) else { return [:] }

    var files: [String: Data] = [:]
    var cursor = directory

    // Central directory entry: signature 0x02014b50, then fixed fields at
    // the offsets the format fixed in 1989.
    while cursor + 46 <= bytes.count, read4(bytes, cursor) == 0x0201_4B50 {
      let method = read2(bytes, cursor + 10)
      let compressedSize = Int(read4(bytes, cursor + 20))
      let plainSize = Int(read4(bytes, cursor + 24))
      let nameLength = Int(read2(bytes, cursor + 28))
      let extraLength = Int(read2(bytes, cursor + 30))
      let commentLength = Int(read2(bytes, cursor + 32))
      let localOffset = Int(read4(bytes, cursor + 42))

      guard cursor + 46 + nameLength <= bytes.count else { break }
      let name = String(
        decoding: bytes[(cursor + 46)..<(cursor + 46 + nameLength)], as: UTF8.self)

      // The local header repeats the name and may carry its own extra field,
      // so the data offset comes from the local lengths, not the central ones.
      if localOffset + 30 <= bytes.count, read4(bytes, localOffset) == 0x0403_4B50 {
        let localName = Int(read2(bytes, localOffset + 26))
        let localExtra = Int(read2(bytes, localOffset + 28))
        let start = localOffset + 30 + localName + localExtra

        if start + compressedSize <= bytes.count {
          let raw = Array(bytes[start..<(start + compressedSize)])
          switch method {
          case 0:
            files[name] = Data(raw)
          case 8:
            if let plain = inflate(raw, size: plainSize) { files[name] = plain }
          default:
            break
          }
        }
      }

      cursor += 46 + nameLength + extraLength + commentLength
    }

    return files
  }

  /// Where the central directory starts, from the end-of-directory record.
  private static func centralDirectoryOffset(_ bytes: [UInt8]) -> Int? {
    guard bytes.count >= 22 else { return nil }

    // The record sits at the very end, pushed back only by the archive
    // comment — scanned for from the tail, as every reader does.
    var cursor = bytes.count - 22
    let floor = max(0, bytes.count - 22 - 65_535)
    while cursor >= floor {
      if read4(bytes, cursor) == 0x0605_4B50 {
        return Int(read4(bytes, cursor + 16))
      }
      cursor -= 1
    }
    return nil
  }

  /// Decompresses one raw-deflate entry to its known size.
  private static func inflate(_ raw: [UInt8], size: Int) -> Data? {
    guard size > 0 else { return Data() }
    var plain = [UInt8](repeating: 0, count: size)

    let written = raw.withUnsafeBufferPointer { source -> Int in
      guard let base = source.baseAddress else { return 0 }
      return compression_decode_buffer(&plain, size, base, raw.count, nil, COMPRESSION_ZLIB)
    }
    guard written == size else { return nil }
    return Data(plain)
  }

  /// The `full-path` the container's first rootfile points at.
  private static func rootfilePath(in container: Data) -> String? {
    final class Finder: NSObject, XMLParserDelegate {
      var path: String?
      func parser(
        _ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
        qualifiedName: String?, attributes: [String: String]
      ) {
        guard element == "rootfile", path == nil else { return }
        path = attributes["full-path"]
        parser.abortParsing()
      }
    }

    let finder = Finder()
    let parser = XMLParser(data: container)
    parser.delegate = finder
    parser.parse()
    return finder.path
  }

  private static func read2(_ bytes: [UInt8], _ at: Int) -> UInt32 {
    UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8
  }

  private static func read4(_ bytes: [UInt8], _ at: Int) -> UInt32 {
    read2(bytes, at) | read2(bytes, at + 2) << 16
  }
}
