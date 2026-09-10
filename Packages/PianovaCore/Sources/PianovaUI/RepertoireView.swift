import Course
import ExerciseEngine
import ScoreModel
import Sound
import SwiftUI
import UniformTypeIdentifiers

/// Every piece in the app, playable on its own.
///
/// A piece locked inside the lesson that uses it can only be reached by taking
/// that lesson again. But playing music is the reason for studying piano, and
/// wanting to sit down and play something is not a detour from the course.
///
/// Nothing here touches progress: this is the repertoire, not the syllabus.
struct RepertoireView: View {
  @ObservedObject var hub: MIDIHub

  @EnvironmentObject private var tones: TonePlayer

  /// The piece open right now, if any.
  @State private var playing: Score?

  /// Pieces the player imported this session.
  @State private var imported: [Score] = []

  /// Whether the file importer is on screen.
  @State private var isImporting = false

  /// Why the last import was refused, if it was.
  @State private var importError: String?

  /// How the open piece is being worked at.
  @State private var mode: PlayMode = .free

  var body: some View {
    if let score = playing {
      PieceView(score: score, mode: mode, hub: hub, onFinished: { playing = nil })
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .id(score.title)
        .safeAreaInset(edge: .top, spacing: 0) {
          // Its own row rather than an overlay: floated over the corner it sat on
          // top of the progress counter, and two numbers stacked on a button is
          // not something anyone can read.
          HStack {
            Button {
              playing = nil
            } label: {
              Label("Repertório", systemImage: "chevron.left")
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
          }
          .padding(.horizontal, 32)
          .padding(.top, 20)
          .padding(.bottom, 8)
        }
    } else {
      list
    }
  }

  private var list: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .firstTextBaseline) {
          Text("Escolha o que tocar")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)

          Spacer()

          Picker("", selection: $mode) {
            ForEach(PlayMode.allCases) { Text($0.title).tag($0) }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .frame(width: 190)

          Button {
            isImporting = true
          } label: {
            Label("Importar MusicXML", systemImage: "square.and.arrow.down")
              .font(.system(size: 12))
          }
        }
        .padding(.bottom, 6)

        Text(mode.detail)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .padding(.bottom, 14)

        if let importError {
          Text(importError)
            .font(.system(size: 12))
            .foregroundStyle(ItemState.failed.color)
            .padding(.bottom, 12)
        }

        if !imported.isEmpty {
          sectionTitle("Suas partituras")
          ForEach(Array(imported.enumerated()), id: \.offset) { _, score in
            row(score)
            Divider()
          }
          sectionTitle("Do curso")
        }

        ForEach(Array(Course.repertoire.enumerated()), id: \.offset) { _, score in
          row(score)
          Divider()
        }
      }
      .frame(maxWidth: 720, alignment: .leading)
      .padding(32)
    }
    .fileImporter(
      isPresented: $isImporting,
      allowedContentTypes: Self.musicXMLTypes,
      allowsMultipleSelection: false
    ) { result in
      load(result)
    }
  }

  private func sectionTitle(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .textCase(.uppercase)
      .padding(.top, 18)
      .padding(.bottom, 6)
  }

  /// What a MusicXML file can call itself.
  ///
  /// Publishers disagree: some export `.musicxml`, some `.xml`, and the plain
  /// XML type has to be allowed or half the files on IMSLP cannot be picked.
  private static var musicXMLTypes: [UTType] {
    [UTType(filenameExtension: "musicxml"), .xml, .init(filenameExtension: "mxl")]
      .compactMap { $0 }
  }

  /// Reads a picked file, or says why it could not.
  private func load(_ result: Result<[URL], Error>) {
    importError = nil

    do {
      guard let url = try result.get().first else { return }

      // Sandboxed picks arrive as security-scoped URLs and read as empty
      // without this, which looks exactly like a corrupt file.
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }

      imported.insert(try MusicXMLImporter.score(at: url), at: 0)
    } catch let error as MusicXMLError {
      importError = error.message
    } catch {
      importError = "Não consegui abrir o arquivo."
    }
  }

  private func row(_ score: Score) -> some View {
    Button {
      playing = score
    } label: {
      HStack(alignment: .center, spacing: 14) {
        unitBadge(Course.unit(playing: score))

        VStack(alignment: .leading, spacing: 3) {
          Text(score.title)
            .font(.system(size: 16, weight: .medium))
          Text(details(of: score))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)

        if score.isTwoHanded {
          Text("duas mãos")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }

        Image(systemName: "play.circle")
          .font(.system(size: 20))
          .foregroundStyle(ItemState.current.color)
      }
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  /// The unit a piece belongs to, which is what says how hard it is.
  private func unitBadge(_ unit: Int?) -> some View {
    Text(unit.map(String.init) ?? "—")
      .font(.system(size: 12, weight: .bold, design: .rounded))
      .foregroundStyle(.white)
      .frame(width: 26, height: 26)
      .background(Color.primary.opacity(0.35), in: Circle())
  }

  /// Composer, key and time signature, on one line.
  private func details(of score: Score) -> String {
    var parts = [score.composer, score.timeSignature.label]

    if score.key.accidentalCount > 0 {
      let sign = score.key.usesSharps ? "♯" : "♭"
      parts.append("\(score.key.accidentalCount)\(sign)")
    }
    if score.hasPickup { parts.append("anacruse") }

    return parts.joined(separator: " · ")
  }

  /// A piece becomes one item per onset, exactly as it does inside a lesson.
  private static func exercise(for score: Score) -> Exercise {
    Exercise(items: score.onsets.map { ExerciseItem(pitches: Set($0.pitches)) })
  }
}
