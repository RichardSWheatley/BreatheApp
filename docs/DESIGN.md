# Design notes

## Goal

Implement the breathwork PRD (`docs/PRD.md`) as an iOS app whose training
logic is deterministic, unit-tested and runnable end to end without a
device.

## Shape

Two layers with a hard boundary:

1. `BreatheKit` (Swift package, Foundation only). Generators turn baselines
   and parameters into a `SessionPlan`: an ordered list of `SessionStep`s
   with a phase, a duration (or `nil` for "until the user marks it") and the
   copy to show and speak. `SessionEngine` executes a plan against an
   injected `SessionClock`, returning `SessionEvent`s from every `tick()`.
   `CueScheduler` maps events to tones, haptics and speech. `Progression`
   holds the scaling and re-test rules.
2. The app. `SessionController` (main actor) owns an engine, ticks it every
   50 ms, forwards cues to `CuePlayer` (AVAudioEngine tones, AVSpeechSynthesizer,
   UIKit haptics) and publishes a `SessionSnapshot` the SwiftUI views render.
   SwiftData stores the profile, assessment history and session log.

The engine never schedules time itself. That one decision is what makes the
simulator, the fast UI tests and the deterministic unit tests possible.

## Decisions

- **Whole-second plan durations, floating-point execution.** Generators
  round to whole seconds so previews read cleanly; the engine tracks elapsed
  time as `TimeInterval` so pacer animation is smooth at any tick rate.
- **Open-ended steps.** Assessments end on a user mark. The engine records
  the elapsed time of the first `isMeasured` step as the result.
- **BOLT scaling.** Cadence holds = 6 s + 1 s per 3 BOLT points above 25,
  capped at 15 s. Simple, monotonic, explainable in one sentence in the UI.
- **O2 table ramp.** The PRD only says "increases linearly"; 40 % → 80 % of
  max hold across the rounds is the conventional freediving ramp and keeps the
  last hold well under the measured max.
- **Pace count.** 30 % of the full-lung max hold for an empty-lung walking
  hold, clamped to 10–45 s, at 100 paces per minute. The pedometer ends the
  hold when the count is reached; without one the hold is timed.
- **Safety is not skippable.** Onboarding requires the acknowledgement and
  the rules are repeated in Learn and Settings.
- **Silent keep-alive audio.** A looping silent buffer keeps the audio
  session active between cues so iOS keeps the app running with the screen
  off (`UIBackgroundModes: audio`).
- **XcodeGen.** `project.yml` is the source of truth for the Xcode project;
  the `.xcodeproj` is generated and ignored.
- **Two package manifests.** `Package.swift` (tools 5.10) lets the package
  build on older toolchains and Linux; `Package@swift-6.0.swift` puts the
  same targets in Swift 6 language mode for Xcode 16+.

## Open question

Should background continuity use the silent keep-alive audio loop, or a
Live Activity plus scheduled local notifications for phase changes?

Default: keep the audio loop. It is the only approach that delivers spoken
prompts with the screen off, which the PRD requires. Revisit if App Review
objects or battery cost proves noticeable.
