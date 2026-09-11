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

  /// The library of imported pieces, kept between sessions.
  private let library = ScoreLibrary()

  /// Pieces the player imported, read from the library.
  @State private var imported: [Score] = []

  /// Why the last import was refused, if it was.
  @State private var importError: String?

  /// The piece the player asked to delete, awaiting their certainty.
  ///
  /// Deleting removes the file itself from the Pianova folder — destroying
  /// the owner's file without asking is not a gesture, it is an accident
  /// waiting to happen.
  @State private var pendingRemoval: String?

  /// How the open piece is being worked at.
  @State private var mode: PlayMode = .free

  var body: some View {
    // One container animating between the two, so entering a piece pushes the
    // list away and leaving brings it back — the motion says where you went.
    ZStack {
      content
    }
    .animation(.spring(duration: 0.35, bounce: 0.12), value: playing?.title)
  }

  @ViewBuilder private var content: some View {
    if let score = playing {
      // Its own title bar, because selection has to take it over: while a
      // passage is picked out there is no way back to the list, the way Photos
      // hides the back button while photos are selected.
      PieceView(
        score: score, mode: mode, hub: hub, onFinished: { playing = nil },
        onBack: { playing = nil }
      )
      .padding(.horizontal, 32)
      .padding(.top, 20)
      .padding(.bottom, 32)
      .id(score.title)
      .transition(
        .asymmetric(
          insertion: .move(edge: .trailing).combined(with: .opacity),
          removal: .move(edge: .trailing).combined(with: .opacity)))
    } else {
      list
        .transition(
          .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)))
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
            FileChooser.pick(types: Self.musicXMLTypes) { url in
              guard let url else { return }
              open(url)
            }
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
    .onAppear { imported = library.scores().reversed() }
    .confirmationDialog(
      "Apagar \"\(pendingRemoval ?? "")\"?",
      isPresented: Binding(
        get: { pendingRemoval != nil },
        set: { if !$0 { pendingRemoval = nil } }),
      titleVisibility: .visible
    ) {
      Button("Apagar", role: .destructive) {
        if let title = pendingRemoval {
          library.remove(titled: title)
          imported = library.scores().reversed()
        }
        pendingRemoval = nil
      }
      Button("Cancelar", role: .cancel) { pendingRemoval = nil }
    } message: {
      Text("O arquivo sai também da pasta Pianova do app Arquivos.")
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
    // `.data` is deliberately included. Without it the picker greys out
    // anything whose extension the system does not already know, and a
    // `.musicxml` file on a device that has never seen one is exactly that —
    // the picker opens onto a list where nothing can be chosen. Refusing a
    // wrong file with a reason is better than not being able to pick it.
    [UTType(filenameExtension: "musicxml"), .xml, .init(filenameExtension: "mxl"), .data]
      .compactMap { $0 }
  }

  /// Imports one file, reporting the reason when it will not open.
  private func open(_ url: URL) {
    importError = nil

    // Sandboxed picks arrive as security-scoped URLs and read as empty without
    // this, which looks exactly like a corrupt file.
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    do {
      // The library is the source of truth and it deduplicates by title;
      // inserting into the list by hand showed two rows of the same piece
      // whenever the title already lived there.
      _ = try library.add(url)
      imported = library.scores().reversed()
    } catch let error as MusicXMLError {
      importError = error.message
    } catch {
      importError = "Não consegui ler \(url.lastPathComponent)."
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

        if imported.contains(where: { $0.title == score.title }) {
          Button {
            pendingRemoval = score.title
          } label: {
            Image(systemName: "trash")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .help("Remover do repertório")
        }

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
