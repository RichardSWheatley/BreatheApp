# Breathe

An iOS app that trains VO2 max and absolute breath-holding capacity through
guided breathing protocols. Built for two audiences: athletes chasing a
higher VO2 max and later respiratory fatigue, and vocalists chasing CO2
tolerance and longer single-breath phrases.

Swift 6 · SwiftUI · SwiftData · iOS 18+ · Xcode 16+

## Quick start (macOS)

```sh
brew install xcodegen          # once
git clone <this repository> BreatheApp && cd BreatheApp
make open                      # generates BreatheApp.xcodeproj and opens Xcode
```

Pick an iPhone simulator, press ⌘R to run, ⌘U to run the app's unit and UI
tests on the simulator. `make test` runs everything from the command line.

The `.xcodeproj` is generated from `project.yml` and is not committed.

## What the app does

- **Onboarding** teaches the three mechanisms the training relies on
  (respiratory metaboreflex, CO2 tolerance, intermittent hypoxic training),
  requires a safety acknowledgement, then runs the three baseline tests:
  BOLT score, max breath hold, single breath count. Each result is banded
  (Developing / Normal / Strong / Elite).
- **Today** recommends the next session, shows baselines, nudges a BOLT
  re-test every 14 days and shows a daily tip.
- **Train** holds the four protocols from the PRD, each with an adjustable
  round count and a preview of the generated plan:
  - CO2 Tolerance Builder: 4 s inhale · hold · 4 s exhale · hold. Holds start
    at 6 s and grow one second for every 3 BOLT points above 25, capped at 15 s.
  - Hypoxic Sprints: exhale, pinch nose, walk N paces, one minute of
    recovery, 5–10 reps. N is derived from the max hold (30 % of it, clamped
    to 10–45 s, at 100 paces/min). The pedometer ends a hold early when the
    pace target is reached; otherwise the hold is timed.
  - CO2 Table: hold fixed at 50 % of max; recovery 2:00 falling 15 s per
    round with a 15 s floor (the PRD's `generateCO2Table`).
  - O2 Table: recovery fixed at 2:00; hold rises linearly from 40 % to 80 %
    of max.
  - Inspiratory Muscle Training: 3 sets × 15 forceful resisted inhales with
    a minute between sets; sets and reps are tracked on screen.
- **Session player**: an expanding / contracting circle bound to lung
  fullness, phase label, countdown, round and rep chips, pause / skip /
  stop / end. Tones, spoken prompts and haptics guide every phase so the
  screen never needs to be looked at; a background audio session keeps
  guidance running with the screen off. Respects Reduce Motion and VoiceOver.
- **Progress**: streak, sessions this week, total hold time, BOLT trend
  chart and session history.
- **Learn**: the science, the safety rules, and a guide for every protocol.

## Architecture

```
Packages/BreatheKit/        Platform-independent Swift package (no UI)
  Sources/BreatheKit/
    Model/                  BreathPhase, SessionStep, SessionPlan, Baselines, scoring
    Generators/             CO2/O2 tables, cadence, hypoxic sprints, IMT, assessments
    Engine/                 SessionEngine (clock-injected state machine), clocks, Pacer
    Cues/                   CueScheduler: engine events → tones / haptics / speech
    Progression/            BOLT scaling, re-test cadence, rotation, stats
    Content/                Education and safety copy
  Sources/breathe-sim/      CLI that runs any session at simulated speed
  Tests/BreatheKitTests/    XCTest suite
App/
  Sources/                  SwiftUI app: AppModel, SessionController, CuePlayer,
                            HapticPlayer, PedometerService, SwiftData models, views
  Tests/                    Swift Testing unit tests for the app layer
  UITests/                  XCUITest flows run on the simulator
project.yml                 XcodeGen spec
.github/workflows/ci.yml    CI: Linux package job + macOS simulator job
```

Every rule from the PRD lives in `BreatheKit`, which has no UI dependency
and builds on macOS and Linux. The engine never owns a timer: something
calls `tick()` and gets back events, so a session can run at real time in
the app, at 1000× in the simulator, or one step at a time in a test.

## Testing

| Command | What runs |
| --- | --- |
| `make kit` | 71 XCTest cases: table math against the PRD example, every generator, engine transitions, countdowns, pause/resume, open-ended holds, cue mapping, progression, stats |
| `make sim` | `breathe-sim all`: all eight session kinds through the real engine with invariant checks (steps in order, 3-2-1 countdowns, elapsed = planned, holds recorded, a spoken prompt on every step) |
| `make app-test` | Swift Testing unit tests (session controller, persistence, launch flags) and XCUITest flows (full onboarding with all three assessments, a complete CO2 table at 120× speed, player controls) on an iPhone simulator |

Inspect a plan and its trace:

```sh
swift run --package-path Packages/BreatheKit breathe-sim co2 --max-hold 90
swift run --package-path Packages/BreatheKit breathe-sim sprints --max-hold 120 --rounds 8 --quiet
swift run --package-path Packages/BreatheKit breathe-sim all --json
```

CI runs the package tests and simulator on Linux and the full simulator
suite on macOS for every push.

### Launch arguments

Used by the UI tests and handy for demos: `-uiTesting` (in-memory store,
fresh state, audio muted), `-skipOnboarding`, `-seedBaselines` (BOLT 28 s,
max hold 90 s, count 30 s), `-timeScale 60` (sessions run 60× faster),
`-inMemoryStore`, `-resetState`.

## Status

- `BreatheKit`, its tests and the simulator have been compiled and run on
  Linux (Swift 5.10) and are exercised on Swift 6.1 in CI.
- The app target, its tests and the UI tests are written against the iOS 18
  SDK and must be built in Xcode; the macOS CI job runs them on every push.

## Safety

Breath-hold training can cause fainting. The app refuses to skip the safety
acknowledgement and repeats the rules in Learn and Settings: never in or
near water, never while driving, tables seated or lying down, stop at
dizziness or tingling, medical clearance for pregnancy and heart, lung,
blood pressure or seizure conditions. The app is a training aid, not
medical advice.
