import ExerciseEngine
import Progress
import ScoreModel
import Sound
import SwiftUI

/// The endless drill.
///
/// Prompt, keyboard and tally. It never finishes.
struct DrillView: View {
  @ObservedObject var controller: DrillController
  @ObservedObject var hub: MIDIHub
  @EnvironmentObject private var profile: ProfileController
  @EnvironmentObject private var tones: TonePlayer

  /// Called when the player leaves.
  ///
  /// The drill has no end of its own, so it must offer a way out that does not
  /// depend on spotting the tab picker above it.
  let onExit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      settingsBar
      Divider()
      tally

      prompt
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)

      feedback

      if !hub.isConnected {
        keyboard
      }

      Spacer()
    }
    .padding(.horizontal, 32)
    .padding(.vertical, 20)
    .onAppear {
      controller.attach(tones)
      hub.setListener(owner: controller) { [controller] in controller.handle($0) }
    }
    .onDisappear {
      hub.clearListener(owner: controller)
      profile.recordDrillStreak(controller.stats.bestStreak)
    }
  }

  private var settingsBar: some View {
    HStack(spacing: 18) {
      Picker("", selection: $controller.settings.difficulty) {
        Text("Fácil").tag(DrillDifficulty.easy)
        Text("Médio").tag(DrillDifficulty.medium)
        Text("Difícil").tag(DrillDifficulty.hard)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 220)

      Picker("", selection: $controller.settings.style) {
        Text("Pauta").tag(DrillPromptStyle.staff)
        Text("Nome").tag(DrillPromptStyle.name)
        Text("Ouvido").tag(DrillPromptStyle.ear)
        Text("Misto").tag(DrillPromptStyle.mixed)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 270)

      Toggle("Sol", isOn: $controller.settings.usesTreble)
        .toggleStyle(.checkbox)
      Toggle("Fá", isOn: $controller.settings.usesBass)
        .toggleStyle(.checkbox)

      Spacer()

      Button("Pular") { controller.skip() }
        .buttonStyle(.borderless)

      Button {
        onExit()
      } label: {
        Label("Sair", systemImage: "xmark")
          .labelStyle(.titleAndIcon)
      }
      .buttonStyle(.borderless)
      .keyboardShortcut(.cancelAction)
    }
    .font(.system(size: 12))
  }

  private var tally: some View {
    HStack(spacing: 22) {
      stat("Sequência", "\(controller.stats.streak)")
      stat("Melhor", "\(controller.stats.bestStreak)")
      stat("Acertos", "\(controller.stats.correct)/\(controller.stats.answered)")
      if controller.stats.answered > 0 {
        stat("Precisão", "\(Int(controller.stats.accuracy * 100))%")
      }
      Spacer()
    }
  }

  private func stat(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(label)
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.system(size: 17, weight: .semibold, design: .rounded))
        .monospacedDigit()
    }
  }

  @ViewBuilder
  private var prompt: some View {
    switch controller.prompt.style {
    case .ear:
      earCard
    case .name, .mixed:
      nameCard
    case .staff:
      StaffView(
        clef: controller.prompt.clef,
        noteGroups: controller.session.exercise.items.map { Array($0.pitches) },
        states: controller.itemStates,
        staffSpace: 20
      )
      .padding(.horizontal, 8)
    }
  }

  /// Nothing written: the prompt is the sound, and the answer is the key.
  ///
  /// This is the one link neither the staff nor the note name can teach —
  /// hearing a pitch and finding it under the hand.
  private var earCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Ouça e toque no piano:")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)

      Button {
        controller.soundPrompt()
      } label: {
        Label("Ouvir de novo", systemImage: "speaker.wave.2.fill")
          .font(.system(size: 16, weight: .medium))
          .frame(maxWidth: .infinity, minHeight: 110)
          .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
          .contentShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)

      HStack(spacing: 14) {
        ForEach(Array(controller.prompt.pitches.enumerated()), id: \.offset) { index, _ in
          Circle()
            .fill(state(at: index).color)
            .frame(width: 12, height: 12)
        }
      }
    }
  }

  /// Written names, sized to read at a glance while the eyes are on the keys.
  private var nameCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Toque no piano:")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)

      HStack(spacing: 14) {
        ForEach(Array(controller.prompt.pitches.enumerated()), id: \.offset) { index, pitch in
          Text(pitch.solfegeWithOctave)
            .font(.system(size: 34, weight: .semibold, design: .rounded))
            .foregroundStyle(state(at: index).color)
        }
      }
    }
  }

  private func state(at index: Int) -> ItemState {
    let states = controller.itemStates
    return index < states.count ? states[index] : .pending
  }

  private var feedback: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(controller.lastWrong == nil ? ItemState.current.color : ItemState.failed.color)
        .frame(width: 10, height: 10)

      Text(message)
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundStyle(controller.lastWrong == nil ? .secondary : ItemState.failed.color)

      Spacer()
    }
    .frame(height: 22)
  }

  private var message: String {
    if let wrong = controller.lastWrong {
      return "\(wrong.solfegeWithOctave) não — tente de novo"
    }
    return controller.prompt.style == .name
      ? "Ache a tecla" : "Ache as notas no teclado"
  }

  private var keyboard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(hub.connectionError ?? "Sem instrumento — toque aqui")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)

      PianoKeyboardView(onPress: { controller.playPitch($0) })
    }
  }
}
