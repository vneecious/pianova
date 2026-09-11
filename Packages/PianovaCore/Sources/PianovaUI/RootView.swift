import Course
import Progress
import ScoreModel
import Sound
import SwiftUI
import UniformTypeIdentifiers

/// The app shell: the course trail, free practice, and the lesson runner.
public struct RootView: View {
  /// Where the app is.
  private enum Screen: Hashable {
    /// The course trail.
    case trail
    /// Pick any unlocked activity to repeat.
    case free
    /// The endless drill, which never finishes.
    case drill
    /// Continuous reading, where the line does not wait.
    case reading
    /// Every piece in the app, playable on its own.
    case repertoire
    /// Running a lesson. Which one lives in `lessonController`.
    case lesson
  }

  /// Observed, not owned: the app creates the hub and keeps it alive.
  ///
  /// Wrapping it in a second `@StateObject` here gave the same instance two
  /// owners and corrupted its reference count.
  @ObservedObject private var hub: MIDIHub

  @State private var screen: Screen = .trail
  @State private var unlocksEverything = false
  @Environment(\.colorScheme) private var colorScheme

  /// The theme, remembered between sessions.
  @AppStorage("pianova.appearance") private var appearanceChoice = Appearance.system.rawValue
  @EnvironmentObject private var tones: TonePlayer
  @EnvironmentObject private var profile: ProfileController
  @State private var lessonController: LessonController?
  @StateObject private var drill = DrillController()
  @EnvironmentObject private var metronome: Metronome

  /// Creates the shell.
  /// - Parameter hub: The shared instrument connection.
  public init(hub: MIDIHub) {
    self.hub = hub
  }

  /// The app shell.
  public var body: some View {
    Group {
      switch screen {
      case .trail, .free, .drill, .reading, .repertoire:
        home
      case .lesson:
        lessonScreen
      }
    }
    .frame(minWidth: 820, minHeight: 620)
    .background(Theme.background(colorScheme))
    .tint(Theme.accent)
    .preferredColorScheme(appearance.colorScheme)
    .onAppear {
      // The sound routing follows the instrument: plug the piano in and the app
      // starts playing through it without anyone pressing anything.
      hub.onInstrumentChanged = { tones.connectInstrument() }
      hub.start()
      tones.connectInstrument()
    }
  }

  /// Trail state, rebuilt from the stored profile each time it is read.
  private var progress: CourseProgress {
    profile.courseProgress(unlocksEverything: unlocksEverything)
  }

  private var home: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .background(Theme.surface(colorScheme))
      Divider().overlay(Theme.border(colorScheme))

      switch screen {
      case .free:
        FreePracticeView(progress: progress) { start($0) }
      case .drill:
        DrillView(controller: drill, hub: hub, onExit: { screen = .trail })
      case .reading:
        ReadingView(hub: hub, tones: tones, onExit: { screen = .trail })
      case .repertoire:
        RepertoireView(hub: hub)
      default:
        CourseTrailView(progress: progress) { start($0) }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Pianova")
          .font(.system(size: 24, weight: .semibold, design: .serif))
        HStack(spacing: 10) {
          Text(instrumentLine)
          if profile.streak > 0 {
            Text("· \(profile.streak) dia\(profile.streak == 1 ? "" : "s") seguidos")
              .foregroundStyle(ItemState.done.color)
          }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      }

      Spacer()

      Picker("", selection: tabBinding) {
        Text("Trilha").tag(Screen.trail)
        Text("Livre").tag(Screen.free)
        Text("Treino").tag(Screen.drill)
        Text("Leitura").tag(Screen.reading)
        Text("Repertório").tag(Screen.repertoire)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 420)

      Button {
        tones.isMuted.toggle()
      } label: {
        Image(systemName: tones.isMuted ? "speaker.slash" : "speaker.wave.2")
          .foregroundStyle(tones.isMuted ? .secondary : ItemState.current.color)
      }
      .buttonStyle(.borderless)
      .help(tones.isMuted ? "Som do teclado desligado" : "Som do teclado ligado")

      Button {
        unlocksEverything.toggle()
      } label: {
        Image(systemName: unlocksEverything ? "lock.open" : "lock")
          .foregroundStyle(unlocksEverything ? ItemState.current.color : .secondary)
      }
      .buttonStyle(.borderless)
      .help(
        unlocksEverything
          ? "Trilha destravada — todas as lições abertas"
          : "Destravar a trilha inteira, para testar")

      Button {
        appearance = appearance.next
      } label: {
        Image(systemName: appearance.symbol)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.borderless)
      .help("Tema: \(appearance.title)")

      metronomeControl

      Button {
        let types = [UTType(filenameExtension: "sf2"), UTType(filenameExtension: "dls"), .data]
          .compactMap { $0 }
        FileChooser.pick(types: types) { url in
          guard let url else { return }
          let scoped = url.startAccessingSecurityScopedResource()
          defer { if scoped { url.stopAccessingSecurityScopedResource() } }
          try? tones.installBank(from: url)
        }
      } label: {
        Image(systemName: "waveform")
          .foregroundStyle(tones.loadedBankName == nil ? .secondary : ItemState.done.color)
      }
      .buttonStyle(.borderless)
      .help(
        tones.loadedBankName.map { "Piano amostrado: \($0)" }
          ?? "Sem banco de som — instalar um .sf2")

      Button {
        tones.routesToInstrument.toggle()
      } label: {
        Image(systemName: tones.isRoutingToInstrument ? "pianokeys.inverse" : "pianokeys")
          .foregroundStyle(tones.isRoutingToInstrument ? ItemState.current.color : .secondary)
      }
      .buttonStyle(.borderless)
      .help(
        tones.isRoutingToInstrument
          ? "Som saindo pelo seu piano — toque para ouvir o app"
          : "Som saindo pelo app — toque para usar o seu piano")

      Button {
        hub.start()
        tones.connectInstrument()
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.borderless)
      .help("Procurar o instrumento de novo")
    }
    .padding(.horizontal, 32)
    .padding(.vertical, 20)
  }

  /// The metronome: a switch, and its dial once it is running.
  ///
  /// Kept in the top bar rather than inside an exercise, because it is the
  /// player's own pulse and has to survive changing screens.
  @ViewBuilder
  private var metronomeControl: some View {
    HStack(spacing: 6) {
      Button {
        metronome.toggle()
      } label: {
        Image(systemName: "metronome")
          .foregroundStyle(metronome.isOn ? ItemState.current.color : .secondary)
      }
      .buttonStyle(.borderless)
      .help(metronome.isOn ? "Desligar o metrônomo" : "Ligar o metrônomo")

      if metronome.isOn {
        Button {
          metronome.tempo -= 4
        } label: {
          Image(systemName: "minus")
        }
        .buttonStyle(.borderless)

        Text("\(Int(metronome.tempo))")
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .monospacedDigit()
          .frame(width: 26)

        Button {
          metronome.tempo += 4
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.borderless)

        Picker("", selection: metronome.beatsPerBarBinding) {
          ForEach([2, 3, 4, 6], id: \.self) { Text("\($0)/4").tag($0) }
        }
        .labelsHidden()
        .frame(width: 72)
      }
    }
  }

  /// The theme, as a value rather than the stored string.
  private var appearance: Appearance {
    get { Appearance(rawValue: appearanceChoice) ?? .system }
    nonmutating set { appearanceChoice = newValue.rawValue }
  }

  private var instrumentLine: String {
    hub.isConnected
      ? hub.sourceNames.joined(separator: ", ")
      : (hub.connectionError ?? "Sem instrumento")
  }

  private var tabBinding: Binding<Screen> {
    Binding(
      get: { screen == .lesson ? .trail : screen },
      set: { screen = $0 })
  }

  @ViewBuilder
  private var lessonScreen: some View {
    if let controller = lessonController {
      LessonView(controller: controller, hub: hub) { finished in
        if finished {
          profile.complete(controller.lesson)
        }
        lessonController = nil
        screen = .trail
      }
    }
  }

  private func start(_ lesson: Lesson) {
    lessonController = LessonController(lesson: lesson)
    screen = .lesson
  }
}
