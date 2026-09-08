// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PianovaCore",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "ScoreModel", targets: ["ScoreModel"]),
    .library(name: "ExerciseEngine", targets: ["ExerciseEngine"]),
    .library(name: "MIDIInput", targets: ["MIDIInput"]),
    .library(name: "NoteQuiz", targets: ["NoteQuiz"]),
    .library(name: "Course", targets: ["Course"]),
    .library(name: "Sound", targets: ["Sound"]),
    .library(name: "Progress", targets: ["Progress"]),
    .library(name: "PianovaUI", targets: ["PianovaUI"]),
  ],
  targets: [
    .target(name: "ScoreModel"),
    .target(name: "ExerciseEngine", dependencies: ["ScoreModel"]),
    .target(name: "MIDIInput", dependencies: ["ScoreModel"]),
    .target(name: "NoteQuiz", dependencies: ["ScoreModel"]),
    .target(name: "Course", dependencies: ["ScoreModel"]),
    .target(name: "Sound", dependencies: ["ScoreModel"]),
    .target(name: "Progress", dependencies: ["ScoreModel"]),
    .target(
      name: "PianovaUI",
      dependencies: [
        "Course", "ExerciseEngine", "MIDIInput", "NoteQuiz", "Progress", "ScoreModel", "Sound",
      ],
      resources: [.process("Resources")]),
    .executableTarget(
      name: "PianovaMac",
      dependencies: ["PianovaUI", "ExerciseEngine", "MIDIInput", "ScoreModel"]),
    .executableTarget(
      name: "PianovaCLI",
      dependencies: ["ExerciseEngine", "MIDIInput", "ScoreModel"]),
    .testTarget(name: "ScoreModelTests", dependencies: ["ScoreModel"]),
    .testTarget(name: "ExerciseEngineTests", dependencies: ["ExerciseEngine", "ScoreModel"]),
    .testTarget(name: "MIDIInputTests", dependencies: ["MIDIInput", "ScoreModel"]),
    .testTarget(name: "NoteQuizTests", dependencies: ["NoteQuiz", "ScoreModel"]),
    .testTarget(name: "CourseTests", dependencies: ["Course", "ScoreModel"]),
    .testTarget(name: "SoundTests", dependencies: ["Sound", "ScoreModel"]),
    .testTarget(name: "ProgressTests", dependencies: ["Progress", "ScoreModel"]),
  ]
)
