// breathe-sim: runs complete sessions through the real BreatheKit engine at
// simulated speed, prints the trace, and checks invariants. Used locally and
// in CI to prove every protocol executes end-to-end before the app ships.
//
//   swift run breathe-sim all
//   swift run breathe-sim co2 --max-hold 90
//   swift run breathe-sim bolt --hold-result 28 --quiet
//   swift run breathe-sim sprints --json

import BreatheKit
import Foundation

// MARK: - Options

struct Options {
    var kinds: [SessionKind] = []
    var maxHold: TimeInterval = 90
    var bolt: TimeInterval = 25
    var rounds: Int?
    var tick: TimeInterval = 0.1
    /// Simulated user: open-ended holds are marked after this many seconds.
    var holdResult: TimeInterval = 35
    var verbose = true
    var json = false

    static let usage = """
    usage: breathe-sim <session> [options]

    sessions: co2 | o2 | cadence | sprints | imt | bolt | maxhold | count | all

    options:
      --max-hold <s>     max breath hold baseline (default 90)
      --bolt <s>         BOLT score baseline (default 25)
      --rounds <n>       rounds / reps / sets override
      --tick <s>         simulated tick interval (default 0.1)
      --hold-result <s>  seconds before the simulated user ends an open-ended hold (default 35)
      --quiet            summary only
      --json             machine readable output
    """

    static func parse(_ arguments: [String]) throws -> Options {
        var options = Options()
        var iterator = arguments.makeIterator()
        func value(for flag: String) throws -> String {
            guard let next = iterator.next() else { throw SimError.usage("\(flag) needs a value") }
            return next
        }
        while let argument = iterator.next() {
            switch argument {
            case "--max-hold": options.maxHold = try Double(value(for: argument)).unwrapped(argument)
            case "--bolt": options.bolt = try Double(value(for: argument)).unwrapped(argument)
            case "--rounds": options.rounds = try Int(value(for: argument)).unwrapped(argument)
            case "--tick": options.tick = try Double(value(for: argument)).unwrapped(argument)
            case "--hold-result": options.holdResult = try Double(value(for: argument)).unwrapped(argument)
            case "--quiet": options.verbose = false
            case "--json": options.json = true; options.verbose = false
            case "-h", "--help": throw SimError.usage(nil)
            default:
                guard let kinds = Self.kinds(named: argument) else { throw SimError.usage("unknown session '\(argument)'") }
                options.kinds.append(contentsOf: kinds)
            }
        }
        guard !options.kinds.isEmpty else { throw SimError.usage("no session given") }
        guard options.tick > 0 else { throw SimError.usage("--tick must be positive") }
        return options
    }

    static func kinds(named name: String) -> [SessionKind]? {
        switch name.lowercased() {
        case "co2", "co2table": return [.co2Table]
        case "o2", "o2table": return [.o2Table]
        case "cadence": return [.cadence]
        case "sprints", "hypoxic": return [.hypoxicSprints]
        case "imt": return [.imt]
        case "bolt": return [.boltAssessment]
        case "maxhold", "max-hold": return [.maxHoldAssessment]
        case "count", "breathcount": return [.breathCountAssessment]
        case "all": return SessionKind.allCases
        default: return nil
        }
    }
}

enum SimError: Error {
    case usage(String?)
}

extension Optional {
    func unwrapped(_ flag: String) throws -> Wrapped {
        guard let value = self else { throw SimError.usage("invalid value for \(flag)") }
        return value
    }
}

// MARK: - Plan construction

func makePlan(kind: SessionKind, options: Options) -> SessionPlan {
    let baselines = Baselines(boltSeconds: options.bolt, maxHoldSeconds: options.maxHold, breathCountSeconds: 30)
    return SessionPlan.standard(for: kind, baselines: baselines, rounds: options.rounds)
}

// MARK: - Simulation

struct Check: Codable {
    let name: String
    let passed: Bool
    let detail: String
}

struct SimulationReport: Codable {
    let kind: String
    let title: String
    let stepCount: Int
    let plannedDuration: TimeInterval
    let totalElapsed: TimeInterval
    let ticks: Int
    let events: Int
    let tones: Int
    let haptics: Int
    let speech: Int
    let measuredSeconds: TimeInterval?
    let holdDurations: [TimeInterval]
    let checks: [Check]

    var passed: Bool { checks.allSatisfy(\.passed) }
}

struct Trace {
    var lines: [String] = []
    mutating func log(_ time: TimeInterval, _ text: String) {
        let stamp = String(format: "t=%7.1fs", time)
        lines.append("  \(stamp)  \(text)")
    }
}

func simulate(kind: SessionKind, options: Options) -> (SimulationReport, Trace) {
    let plan = makePlan(kind: kind, options: options)
    let clock = ManualClock()
    let engine = SessionEngine(plan: plan, clock: clock)
    let scheduler = CueScheduler.standard
    var trace = Trace()

    var began: [Int] = []
    var ended: [Int] = []
    var completions = 0
    var countdownsByStep: [Int: [Int]] = [:]
    var stepsWithSpeech = Set<Int>()
    var tones = 0, haptics = 0, speech = 0
    var eventCount = 0
    var ticks = 0
    var fullnessOK = true
    var monotonicOK = true
    var lastTotal: TimeInterval = -1
    var openEndedTime: TimeInterval = 0
    var currentIndex = 0

    func handle(_ events: [SessionEvent]) {
        for event in events {
            eventCount += 1
            let cues = scheduler.cues(for: event)
            tones += cues.filter(\.isTone).count
            haptics += cues.filter(\.isHaptic).count
            speech += cues.filter(\.isSpeech).count

            switch event {
            case .started:
                trace.log(engine.totalElapsed, "▶ start \(plan.title)")
            case .stepBegan(let index, let step):
                began.append(index)
                currentIndex = index
                if cues.contains(where: \.isSpeech) { stepsWithSpeech.insert(index) }
                let length = step.duration.map { "(\(TimeFormatting.clock($0)))" } ?? "(until marked)"
                let round = step.round > 0 ? " [\(step.round)/\(step.roundCount)]" : ""
                let extra = step.paces.map { " \($0) paces" } ?? (step.rep.map { " rep \($0)/\(step.repCount ?? 0)" } ?? "")
                trace.log(engine.totalElapsed, "→ \(step.phase.displayName)\(round) \(length)\(extra)  “\(step.voicePrompt)”")
            case .stepEnded(let index, let step, let elapsed, let skipped):
                ended.append(index)
                if step.isMeasured {
                    trace.log(engine.totalElapsed, "■ recorded \(TimeFormatting.spoken(elapsed))\(skipped ? " (skipped)" : "")")
                }
            case .countdown(let n, _, _):
                countdownsByStep[currentIndex, default: []].append(n)
                if options.verbose { trace.log(engine.totalElapsed, "  · \(n)") }
            case .paused, .resumed:
                break
            case .completed(let summary):
                completions += 1
                trace.log(engine.totalElapsed, "✓ complete  total \(TimeFormatting.clock(summary.totalElapsed))")
            case .aborted:
                trace.log(engine.totalElapsed, "✗ aborted")
            }
        }
    }

    handle(engine.start())
    let budget = Int((plan.plannedDuration + Double(plan.steps.filter(\.isOpenEnded).count) * (options.holdResult + 1)) / options.tick) + 100
    while engine.state == .running, ticks < budget {
        ticks += 1
        clock.advance(by: options.tick)
        handle(engine.tick())
        let snapshot = engine.snapshot
        if !(0...1).contains(snapshot.fullness) || !(0...1).contains(snapshot.sessionProgress) {
            fullnessOK = false
        }
        if snapshot.totalElapsed < lastTotal { monotonicOK = false }
        lastTotal = snapshot.totalElapsed
        if let step = engine.currentStep, step.isOpenEnded, engine.stepElapsed >= options.holdResult {
            openEndedTime += engine.stepElapsed
            handle(engine.mark())
        }
    }

    let summary = engine.summary
    let expectedIndices = Array(0..<plan.steps.count)
    let timedSteps = plan.steps.filter { ($0.duration ?? 0) >= engine.countdownThreshold }
    let countdownsValid = countdownsByStep.values.allSatisfy { $0 == [3, 2, 1] }
        && countdownsByStep.count == timedSteps.count
    let expectedElapsed = plan.plannedDuration + openEndedTime

    let checks = [
        Check(name: "completed", passed: engine.state == .completed && completions == 1,
              detail: "state=\(engine.state.rawValue) completions=\(completions)"),
        Check(name: "steps began in order", passed: began == expectedIndices, detail: "\(began.count)/\(plan.steps.count)"),
        Check(name: "steps ended in order", passed: ended == expectedIndices, detail: "\(ended.count)/\(plan.steps.count)"),
        Check(name: "3-2-1 countdown on every timed step", passed: countdownsValid,
              detail: "\(countdownsByStep.count) steps counted down, \(timedSteps.count) expected"),
        Check(name: "elapsed matches plan", passed: abs(summary.totalElapsed - expectedElapsed) <= options.tick,
              detail: "\(TimeFormatting.clock(summary.totalElapsed)) vs \(TimeFormatting.clock(expectedElapsed))"),
        Check(name: "holds recorded", passed: summary.holdDurations.count == plan.holdSteps.count,
              detail: "\(summary.holdDurations.count)/\(plan.holdSteps.count)"),
        Check(name: "assessment measured", passed: (summary.measuredSeconds != nil) == kind.isAssessment,
              detail: summary.measuredSeconds.map { TimeFormatting.spoken($0) } ?? "n/a"),
        Check(name: "spoken prompt on every step", passed: stepsWithSpeech.count == plan.steps.count,
              detail: "\(stepsWithSpeech.count)/\(plan.steps.count)"),
        Check(name: "snapshot values in range", passed: fullnessOK && monotonicOK,
              detail: fullnessOK && monotonicOK ? "ok" : "fullness=\(fullnessOK) monotonic=\(monotonicOK)"),
    ]

    let report = SimulationReport(
        kind: kind.rawValue,
        title: plan.title,
        stepCount: plan.steps.count,
        plannedDuration: plan.plannedDuration,
        totalElapsed: summary.totalElapsed,
        ticks: ticks,
        events: eventCount,
        tones: tones,
        haptics: haptics,
        speech: speech,
        measuredSeconds: summary.measuredSeconds,
        holdDurations: summary.holdDurations,
        checks: checks
    )
    return (report, trace)
}

// MARK: - Output

func printPlan(_ kind: SessionKind, options: Options) {
    let plan = makePlan(kind: kind, options: options)
    print("== \(plan.title) ==  (max hold \(Int(options.maxHold)) s, BOLT \(Int(options.bolt)) s)")
    print("Plan: \(plan.steps.count) steps, \(plan.roundCount) rounds, planned \(TimeFormatting.clock(plan.plannedDuration))"
          + (plan.isOpenEnded ? " + open-ended hold" : ""))
    if let rows = ApneaTables.rows(for: kind, maxHold: options.maxHold) {
        print("  cycle  breathe  hold")
        for row in rows {
            print("  \(String(format: "%5d", row.cycle))  \(String(format: "%7@", TimeFormatting.clock(row.breatheTime) as NSString))  \(TimeFormatting.clock(row.holdTime))")
        }
    }
}

func printReport(_ report: SimulationReport, trace: Trace, options: Options) {
    if options.verbose {
        print("Trace:")
        for line in trace.lines { print(line) }
    }
    print("Result: \(report.title): \(report.stepCount) steps, \(TimeFormatting.clock(report.totalElapsed)) elapsed, "
          + "\(report.ticks) ticks, \(report.events) events, cues: \(report.tones) tones / \(report.haptics) haptics / \(report.speech) spoken")
    for check in report.checks {
        print("  \(check.passed ? "✓" : "✗") \(check.name) (\(check.detail))")
    }
    print(report.passed ? "SIM PASS: \(report.kind)" : "SIM FAIL: \(report.kind)")
    print("")
}

// MARK: - Main

do {
    let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
    var reports: [SimulationReport] = []
    for kind in options.kinds {
        if !options.json { printPlan(kind, options: options) }
        let (report, trace) = simulate(kind: kind, options: options)
        reports.append(report)
        if !options.json { printReport(report, trace: trace, options: options) }
    }
    if options.json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(reports)
        print(String(decoding: data, as: UTF8.self))
    }
    let failed = reports.filter { !$0.passed }
    if !options.json {
        print(failed.isEmpty ? "ALL SIMULATIONS PASSED (\(reports.count))" : "SIMULATIONS FAILED: \(failed.map(\.kind).joined(separator: ", "))")
    }
    exit(failed.isEmpty ? 0 : 1)
} catch SimError.usage(let message) {
    if let message { FileHandle.standardError.write(Data("error: \(message)\n\n".utf8)) }
    print(Options.usage)
    exit(message == nil ? 0 : 2)
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
