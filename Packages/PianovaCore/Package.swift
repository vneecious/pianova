// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PianovaCore",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "ScoreModel", targets: ["ScoreModel"]),
    .library(name: "ExerciseEngine", targets: ["ExerciseEngine"]),
    .library(name: "Engraving", targets: ["Engraving"]),
    .library(name: "EngravingVerovio", targets: ["EngravingVerovio"]),
    .library(name: "MIDIInput", targets: ["MIDIInput"]),
    .library(name: "NoteQuiz", targets: ["NoteQuiz"]),
    .library(name: "Course", targets: ["Course"]),
    .library(name: "Sound", targets: ["Sound"]),
    .library(name: "Progress", targets: ["Progress"]),
    .library(name: "PianovaUI", targets: ["PianovaUI"]),
  ],
  dependencies: [
    // The engraver. Official Swift package; iOS 16+ and macOS 11+.
    .package(url: "https://github.com/rism-digital/verovio.git", branch: "develop")
  ],
  targets: [
    .target(name: "ScoreModel"),
    .target(name: "ExerciseEngine", dependencies: ["ScoreModel"]),
    .target(name: "MIDIInput", dependencies: ["ScoreModel"]),
    .target(name: "NoteQuiz", dependencies: ["ScoreModel"]),
    // Pure Swift: the drawable page, the SVG reader, and the engraver's
    // interface. Anything may import this.
    .target(name: "Engraving", dependencies: ["ScoreModel"]),

    // The engraver itself is C++, and Swift's interop is viral: every module
    // that can see it must be built for it. Keeping it in one target that
    // nothing else imports is what stops that reaching the app.
    .target(
      name: "EngravingVerovio",
      dependencies: [
        "Engraving",
        "ScoreModel",
        .product(name: "VerovioToolkit", package: "verovio"),
      ],
      swiftSettings: [.interoperabilityMode(.Cxx)]),
    .target(name: "Course", dependencies: ["ScoreModel"]),
    .target(
      name: "Sound",
      dependencies: ["MIDIInput", "ScoreModel"],
      // Copied as a folder so a clone without any bank still builds: the app
      // simply finds nothing and falls back to the synthesiser.
      resources: [.copy("SoundBanks")]),
    .target(name: "Progress", dependencies: ["ScoreModel"]),
    .target(
      name: "PianovaUI",
      dependencies: [
        "Course", "Engraving", "ExerciseEngine", "MIDIInput", "NoteQuiz", "Progress",
        "ScoreModel", "Sound",
      ],
      resources: [.process("Resources")]),
    .executableTarget(
      name: "PianovaMac",
      dependencies: [
        "EngravingVerovio", "ExerciseEngine", "MIDIInput", "PianovaUI", "ScoreModel",
      ],
      swiftSettings: [.interoperabilityMode(.Cxx)]),
    .executableTarget(
      name: "PianovaImport",
      dependencies: ["ScoreModel"]),
    .executableTarget(
      name: "PianovaPing",
      dependencies: ["MIDIInput", "ScoreModel"]),
    .executableTarget(
      name: "PianovaCLI",
      dependencies: ["ExerciseEngine", "MIDIInput", "ScoreModel"]),
    .testTarget(name: "EngravingTests", dependencies: ["Engraving", "ScoreModel"]),
    .testTarget(name: "ScoreModelTests", dependencies: ["ScoreModel"]),
    .testTarget(name: "ExerciseEngineTests", dependencies: ["ExerciseEngine", "ScoreModel"]),
    .testTarget(name: "MIDIInputTests", dependencies: ["MIDIInput", "ScoreModel"]),
    .testTarget(name: "NoteQuizTests", dependencies: ["NoteQuiz", "ScoreModel"]),
    .testTarget(name: "CourseTests", dependencies: ["Course", "ScoreModel"]),
    .testTarget(name: "SoundTests", dependencies: ["Sound", "ScoreModel"]),
    .testTarget(name: "ProgressTests", dependencies: ["Progress", "ScoreModel"]),
  ]
)
