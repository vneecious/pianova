import AVFoundation
import Accelerate
import CoreML
import Foundation
import ScoreModel

/// Transcribes audio into notes with the Basic Pitch model (rule 153).
///
/// Hand-rolled spectral analysis loses chords and two hands; this model was
/// trained on thousands of hours of real playing and does not. It runs on
/// the device, from a 272 KB package that travels with the app — see
/// `Models/README.md` for its interface and licence.
///
/// What it answers is "what sounded", never "what counts": the score still
/// decides that (rule 151).
public final class NeuralEar {
  /// One note the model heard.
  public struct Heard: Equatable, Sendable {
    /// Which key.
    public let pitch: Pitch

    /// Seconds from the start of the audio handed in.
    public let time: TimeInterval

    /// How confident the model is, 0...1.
    public let confidence: Double
  }

  /// The model wants exactly this many samples, at exactly this rate.
  private static let modelRate = 22_050.0
  private static let windowSamples = 43_844
  private static let frames = 172
  private static let keys = 88

  /// Samples per output frame — the window divided by its frames.
  private static let frameHop = 256

  /// The lowest key the model knows: A0.
  private static let lowestMIDI = 21

  private let model: MLModel
  private let sampleRate: Double
  private let converter: AVAudioConverter?
  private let inputFormat: AVAudioFormat?
  private let modelFormat: AVAudioFormat?

  /// Whether the model is loaded and the ear can listen.
  public var isReady: Bool { true }

  /// Loads the model, compiling it on first use.
  /// - Parameter sampleRate: The rate audio will arrive at.
  /// - Throws: If the model is missing from the bundle or will not compile.
  public init(sampleRate: Double) throws {
    self.sampleRate = sampleRate

    guard let package = Bundle.module.url(forResource: "Models/nmp", withExtension: "mlpackage")
    else { throw EarError.modelMissing }

    // Compiling takes a moment, so the result is kept beside the app's other
    // caches and reused; a new build compiles once more and no more.
    let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    let compiled = cache?.appendingPathComponent("pianova-nmp.mlmodelc")

    if let compiled, FileManager.default.fileExists(atPath: compiled.path),
      let cached = try? MLModel(contentsOf: compiled)
    {
      model = cached
    } else {
      let fresh = try MLModel.compileModel(at: package)
      model = try MLModel(contentsOf: fresh)
      if let compiled {
        try? FileManager.default.removeItem(at: compiled)
        try? FileManager.default.copyItem(at: fresh, to: compiled)
      }
    }

    // Resampling to the model's rate, done by the system's converter.
    inputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    modelFormat = AVAudioFormat(standardFormatWithSampleRate: Self.modelRate, channels: 1)
    if let inputFormat, let modelFormat, sampleRate != Self.modelRate {
      converter = AVAudioConverter(from: inputFormat, to: modelFormat)
    } else {
      converter = nil
    }
  }

  /// What can go wrong loading the ear.
  public enum EarError: Error {
    /// The model is not in the bundle.
    case modelMissing
  }

  /// How strong an onset has to be to count as a note.
  ///
  /// The reference implementation's own default; below it the model is
  /// guessing, and a guess is not a finger.
  public var onsetThreshold = 0.5

  /// The notes the score is waiting for, heard with an open ear (rule 151).
  ///
  /// Missing what the page asks for stalls the study; an extra guess on the
  /// right note only repeats what the finger already did. Doubt is settled
  /// in favour of what is written.
  public var lenientPitches: Set<Pitch> = []

  /// How much lower the bar sits for an expected note.
  public var lenientThreshold = 0.15

  /// The bar one key has to clear.
  private func threshold(forKey key: Int) -> Double {
    let pitch = Pitch(UInt8(Self.lowestMIDI + key))
    return lenientPitches.contains(pitch) ? lenientThreshold : onsetThreshold
  }

  /// Hears whatever is in a stretch of audio.
  ///
  /// The audio is resampled, walked window by window, and every onset peak
  /// becomes a note. Windows overlap and only their fresh half is read, so
  /// a note is reported once.
  /// - Parameter samples: Mono audio at the ear's rate.
  /// - Returns: The notes heard, in time order.
  public func listen(to samples: [Float]) -> [Heard] {
    let audio = resampled(samples)
    guard audio.count >= Self.windowSamples else { return [] }

    var heard: [Heard] = []
    var offset = 0
    let stride = Self.windowSamples / 2

    while offset + Self.windowSamples <= audio.count {
      let window = Array(audio[offset..<(offset + Self.windowSamples)])
      guard let onsets = onsetMatrix(for: window) else { break }

      // Edge frames see half a window of context; the middle is where the
      // model is sure, so overlapping windows read only their own middle.
      let first = offset == 0 ? 0 : Self.frames / 4
      let last = Self.frames - Self.frames / 4

      for frame in max(first, 1)..<min(last, Self.frames - 1) {
        for key in 0..<Self.keys {
          let value = onsets[frame * Self.keys + key]
          guard Double(value) > threshold(forKey: key),
            value >= onsets[(frame - 1) * Self.keys + key],
            value > onsets[(frame + 1) * Self.keys + key]
          else { continue }

          let sample = offset + frame * Self.frameHop
          heard.append(
            Heard(
              pitch: Pitch(UInt8(Self.lowestMIDI + key)),
              time: Double(sample) / Self.modelRate,
              confidence: Double(value)))
        }
      }
      offset += stride
    }

    return heard.sorted { $0.time < $1.time }
  }

  // MARK: - Listening live

  /// Audio waiting to be looked at, already at the model's rate.
  private var live: [Float] = []

  /// How much of `live` has already been reported on, in samples.
  private var reportedUpTo = 0

  /// How far the stream has travelled, for absolute times.
  private var streamOrigin = 0

  /// How often the model runs on the live stream, in model samples.
  ///
  /// ~128 ms: often enough that the page answers while the key is still
  /// down, rare enough that a tablet is not kept busy transcribing.
  private static let liveStride = 2_816

  /// Frames at the window's end that are not read yet.
  ///
  /// The model sees less to the right of them than it will once more audio
  /// arrives, and a half-informed onset is a ghost. Eight frames ≈ 93 ms.
  /// Frames at the window's end left for later.
  ///
  /// The model sees less to the right of them than it will once more audio
  /// arrives, and a half-informed onset is a ghost. Twenty frames (~230 ms)
  /// is where the curve bends: measured on the owner's own playing, recall
  /// climbs from 77% to 87% there, and barely moves for four times the wait.
  public var edgeMargin = 20

  /// Feeds live audio and returns whatever it newly heard (rule 153).
  ///
  /// Each note is reported once: the window slides, but only frames never
  /// looked at before are read.
  /// - Parameter samples: Mono audio at the ear's rate, as it arrives.
  /// - Returns: Notes heard since the last call, in time order.
  public func hear(_ samples: [Float]) -> [Heard] {
    live.append(contentsOf: resampled(samples))
    var heard: [Heard] = []

    while live.count >= Self.windowSamples {
      let window = Array(live.prefix(Self.windowSamples))
      if let onsets = onsetMatrix(for: window) {
        let readable = Self.frames - edgeMargin
        let from = max(1, (reportedUpTo - streamOrigin) / Self.frameHop)

        for frame in from..<max(from, readable) {
          for key in 0..<Self.keys {
            let value = onsets[frame * Self.keys + key]
            guard Double(value) > threshold(forKey: key),
              value >= onsets[(frame - 1) * Self.keys + key],
              frame + 1 >= Self.frames || value > onsets[(frame + 1) * Self.keys + key]
            else { continue }

            heard.append(
              Heard(
                pitch: Pitch(UInt8(Self.lowestMIDI + key)),
                time: Double(streamOrigin + frame * Self.frameHop) / Self.modelRate,
                confidence: Double(value)))
          }
        }
        reportedUpTo = streamOrigin + readable * Self.frameHop
      }

      live.removeFirst(Self.liveStride)
      streamOrigin += Self.liveStride
    }

    return heard.sorted { $0.time < $1.time }
  }

  /// Forgets the live stream — a fresh run starts deaf to the last one.
  public func reset() {
    live.removeAll()
    reportedUpTo = 0
    streamOrigin = 0
  }

  // MARK: - The model itself

  /// Runs one window and returns its onset matrix, frame-major.
  ///
  /// The row stride is read from the array rather than assumed: it is not
  /// the key count, and assuming it read staircase garbage the first time.
  private func onsetMatrix(for window: [Float]) -> [Float]? {
    guard
      let input = try? MLMultiArray(
        shape: [1, NSNumber(value: Self.windowSamples), 1], dataType: .float32)
    else { return nil }

    let pointer = input.dataPointer.bindMemory(to: Float.self, capacity: Self.windowSamples)
    window.withUnsafeBufferPointer { buffer in
      guard let base = buffer.baseAddress else { return }
      pointer.update(from: base, count: Self.windowSamples)
    }

    guard
      let output = try? model.prediction(
        from: MLDictionaryFeatureProvider(dictionary: ["input_2": input])),
      let onsets = output.featureValue(for: "Identity_2")?.multiArrayValue
    else { return nil }

    let rowStride = onsets.strides[1].intValue
    let keyStride = onsets.strides[2].intValue
    let source = onsets.dataPointer.bindMemory(to: Float.self, capacity: onsets.count)

    var matrix = [Float](repeating: 0, count: Self.frames * Self.keys)
    for frame in 0..<Self.frames {
      for key in 0..<Self.keys {
        matrix[frame * Self.keys + key] = source[frame * rowStride + key * keyStride]
      }
    }
    return matrix
  }

  /// Brings audio to the model's own rate.
  private func resampled(_ samples: [Float]) -> [Float] {
    guard let converter, let inputFormat, let modelFormat, !samples.isEmpty else {
      return samples
    }
    guard
      let source = AVAudioPCMBuffer(
        pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(samples.count))
    else { return samples }

    source.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { buffer in
      guard let base = buffer.baseAddress, let channel = source.floatChannelData?.pointee
      else { return }
      channel.update(from: base, count: samples.count)
    }

    let capacity = AVAudioFrameCount(Double(samples.count) * Self.modelRate / sampleRate) + 2048
    guard let target = AVAudioPCMBuffer(pcmFormat: modelFormat, frameCapacity: capacity) else {
      return samples
    }

    // Each call is its own little conversion: without this the converter
    // stays in the end-of-stream it was left in, and every chunk after the
    // first resamples to nothing — which is silence to the model.
    converter.reset()

    var fed = false
    _ = converter.convert(to: target, error: nil) { _, status in
      if fed {
        status.pointee = .endOfStream
        return nil
      }
      fed = true
      status.pointee = .haveData
      return source
    }

    guard let channel = target.floatChannelData?.pointee else { return samples }
    return Array(UnsafeBufferPointer(start: channel, count: Int(target.frameLength)))
  }
}
