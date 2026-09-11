import Course
import Progress
import ScoreModel
import Sound
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

/// The app shell: play, practise, and the trail.
///
/// Three places, in the order the player lives in them. Playing pieces is the
/// reason for studying piano, so the app opens there; practising is one hub
/// with its modes inside; the trail is the course, kept and last.
public struct RootView: View {
  /// Where the app is.
  private enum Screen: Hashable {
    /// Every piece in the app, playable on its own. Home.
    case play
    /// The practice hub: drill, reading, repeatable activities.
    case practice
    /// The course trail.
    case trail
    /// The endless drill, which never finishes.
    case drill
    /// Continuous reading, where the line does not wait.
    case reading
    /// Running a lesson. Which one lives in `lessonController`.
    case lesson
  }

  /// Observed, not owned: the app creates the hub and keeps it alive.
  ///
  /// Wrapping it in a second `@StateObject` here gave the same instance two
  /// owners and corrupted its reference count.
  @ObservedObject private var hub: MIDIHub

  @State private var screen: Screen = .play
  @Environment(\.scenePhase) private var scenePhase
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
      case .play, .practice, .trail, .drill, .reading:
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
      keepScreenAwake(true)
    }
    // The system counts only touches on the glass as activity, and practising
    // happens on the piano — the iPad slept mid-exercise. Awake while the app
    // is up; back to normal the moment it leaves the front.
    .onChange(of: scenePhase) { _, phase in
      keepScreenAwake(phase == .active)
    }
  }

  /// Keeps the display on while practising, where no finger touches the glass.
  private func keepScreenAwake(_ awake: Bool) {
    #if canImport(UIKit)
    UIApplication.shared.isIdleTimerDisabled = awake
    #endif
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
      case .practice:
        PracticeHubView(
          progress: progress,
          onDrill: { screen = .drill },
          onReading: { screen = .reading },
          onPick: { start($0) })
      case .drill:
        DrillView(controller: drill, hub: hub, onExit: { screen = .practice })
      case .reading:
        ReadingView(hub: hub, tones: tones, onExit: { screen = .practice })
      case .trail:
        CourseTrailView(progress: progress) { start($0) }
      default:
        RepertoireView(hub: hub)
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
        Text("Tocar").tag(Screen.play)
        Text("Praticar").tag(Screen.practice)
        Text("Trilha").tag(Screen.trail)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 300)

      Button {
        tones.isMuted.toggle()
      } label: {
        Image(systemName: tones.isMuted ? "speaker.slash" : "speaker.wave.2")
          .foregroundStyle(tones.isMuted ? .secondary : ItemState.current.color)
      }
      .buttonStyle(.borderless)
      .help(tones.isMuted ? "Som do teclado desligado" : "Som do teclado ligado")

      metronomeControl

      settingsMenu
    }
    .padding(.horizontal, 32)
    .padding(.vertical, 20)
  }

  /// Everything set once and left alone, folded into one menu.
  ///
  /// These were seven bare icons in a row — a cockpit, when what the top bar
  /// owes the player is the two live controls (sound, pulse) and one door to
  /// the rest.
  private var settingsMenu: some View {
    Menu {
      Button {
        appearance = appearance.next
      } label: {
        Label("Tema: \(appearance.title)", systemImage: appearance.symbol)
      }

      Button {
        tones.routesToInstrument.toggle()
      } label: {
        Label(
          tones.isRoutingToInstrument
            ? "Som saindo pelo piano — trocar para o app"
            : "Som saindo pelo app — trocar para o piano",
          systemImage: tones.isRoutingToInstrument ? "pianokeys.inverse" : "pianokeys")
      }

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
        Label(
          tones.loadedBankName.map { "Piano amostrado: \($0)" }
            ?? "Instalar um banco de som (.sf2)",
          systemImage: "waveform")
      }

      Button {
        hub.start()
        tones.connectInstrument()
      } label: {
        Label("Procurar o instrumento de novo", systemImage: "arrow.clockwise")
      }

      Divider()

      Button {
        unlocksEverything.toggle()
      } label: {
        Label(
          unlocksEverything ? "Travar a trilha de novo" : "Destravar a trilha inteira",
          systemImage: unlocksEverything ? "lock.open" : "lock")
      }
    } label: {
      Image(systemName: "ellipsis.circle")
        .foregroundStyle(.secondary)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
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
      get: {
        switch screen {
        case .lesson: return .trail
        case .drill, .reading: return .practice
        default: return screen
        }
      },
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
