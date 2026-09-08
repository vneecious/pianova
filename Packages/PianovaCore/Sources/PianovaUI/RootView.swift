import Course
import Progress
import ScoreModel
import Sound
import SwiftUI

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
  @EnvironmentObject private var tones: TonePlayer
  @EnvironmentObject private var profile: ProfileController
  @State private var lessonController: LessonController?
  @StateObject private var drill = DrillController()

  /// Creates the shell.
  /// - Parameter hub: The shared instrument connection.
  public init(hub: MIDIHub) {
    self.hub = hub
  }

  /// The app shell.
  public var body: some View {
    Group {
      switch screen {
      case .trail, .free, .drill, .reading:
        home
      case .lesson:
        lessonScreen
      }
    }
    .frame(minWidth: 820, minHeight: 620)
    .onAppear { hub.start() }
  }

  /// Trail state, rebuilt from the stored profile each time it is read.
  private var progress: CourseProgress {
    profile.courseProgress(unlocksEverything: unlocksEverything)
  }

  private var home: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()

      switch screen {
      case .free:
        FreePracticeView(progress: progress) { start($0) }
      case .drill:
        DrillView(controller: drill, hub: hub, onExit: { screen = .trail })
      case .reading:
        ReadingView(hub: hub, tones: tones, onExit: { screen = .trail })
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
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 320)

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
        hub.start()
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.borderless)
      .help("Procurar o instrumento de novo")
    }
    .padding(.horizontal, 32)
    .padding(.vertical, 20)
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
