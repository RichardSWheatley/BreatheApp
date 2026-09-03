import Foundation

/// Parameters for the CO2 table generator (PRD §5 pseudo-code).
///
/// Hold time stays constant at `holdFraction` of the user's max hold while
/// the recovery breathing time shrinks by `restDecrement` every round, never
/// dropping below `minimumRest`.
public struct CO2TableParameters: Codable, Sendable, Hashable {
    public var rounds: Int
    public var holdFraction: Double
    public var initialRest: TimeInterval
    public var restDecrement: TimeInterval
    public var minimumRest: TimeInterval
    public var prepareDuration: TimeInterval

    public init(
        rounds: Int = 6,
        holdFraction: Double = 0.5,
        initialRest: TimeInterval = 120,
        restDecrement: TimeInterval = 15,
        minimumRest: TimeInterval = 15,
        prepareDuration: TimeInterval = 10
    ) {
        self.rounds = rounds
        self.holdFraction = holdFraction
        self.initialRest = initialRest
        self.restDecrement = restDecrement
        self.minimumRest = minimumRest
        self.prepareDuration = prepareDuration
    }

    public static let standard = CO2TableParameters()
}

/// Parameters for the O2 table generator.
///
/// Recovery stays constant while the hold grows linearly from
/// `startFraction` to `endFraction` of the user's max hold.
public struct O2TableParameters: Codable, Sendable, Hashable {
    public var rounds: Int
    public var rest: TimeInterval
    public var startFraction: Double
    public var endFraction: Double
    public var prepareDuration: TimeInterval

    public init(
        rounds: Int = 6,
        rest: TimeInterval = 120,
        startFraction: Double = 0.4,
        endFraction: Double = 0.8,
        prepareDuration: TimeInterval = 10
    ) {
        self.rounds = rounds
        self.rest = rest
        self.startFraction = startFraction
        self.endFraction = endFraction
        self.prepareDuration = prepareDuration
    }

    public static let standard = O2TableParameters()
}

/// One row of an apnea table, in the shape of the PRD's `tableData` entries.
public struct ApneaTableRow: Codable, Sendable, Hashable, Identifiable {
    public let cycle: Int
    public let breatheTime: TimeInterval
    public let holdTime: TimeInterval

    public var id: Int { cycle }

    public init(cycle: Int, breatheTime: TimeInterval, holdTime: TimeInterval) {
        self.cycle = cycle
        self.breatheTime = breatheTime
        self.holdTime = holdTime
    }
}

public enum ApneaTables {
    /// Longest max hold the generators will scale from. Anything above this is
    /// clamped so a typo in the assessment cannot produce dangerous plans.
    public static let maxHoldCeiling: TimeInterval = 600
    /// Shortest max hold the generators will scale from.
    public static let maxHoldFloor: TimeInterval = 10
    /// Rounds are clamped to this range.
    public static let roundRange = 1...12

    static func clampedMaxHold(_ maxHold: TimeInterval) -> TimeInterval {
        min(max(maxHold, maxHoldFloor), maxHoldCeiling)
    }

    static func clampedRounds(_ rounds: Int) -> Int {
        min(max(rounds, roundRange.lowerBound), roundRange.upperBound)
    }

    /// CO2 table rows. Direct port of the PRD's `generateCO2Table`.
    public static func co2Rows(maxHold: TimeInterval, parameters: CO2TableParameters = .standard) -> [ApneaTableRow] {
        let maxHold = clampedMaxHold(maxHold)
        let rounds = clampedRounds(parameters.rounds)
        let targetHold = (maxHold * parameters.holdFraction).rounded()
        return (1...rounds).map { cycle in
            let rest = parameters.initialRest - Double(cycle - 1) * parameters.restDecrement
            return ApneaTableRow(
                cycle: cycle,
                breatheTime: max(rest, parameters.minimumRest),
                holdTime: targetHold
            )
        }
    }

    /// O2 table rows: constant recovery, hold rising linearly.
    public static func o2Rows(maxHold: TimeInterval, parameters: O2TableParameters = .standard) -> [ApneaTableRow] {
        let maxHold = clampedMaxHold(maxHold)
        let rounds = clampedRounds(parameters.rounds)
        let start = maxHold * parameters.startFraction
        let end = maxHold * parameters.endFraction
        return (1...rounds).map { cycle in
            let t = rounds == 1 ? 1.0 : Double(cycle - 1) / Double(rounds - 1)
            let hold = (start + (end - start) * t).rounded()
            return ApneaTableRow(cycle: cycle, breatheTime: parameters.rest, holdTime: hold)
        }
    }

    /// Rows for either table kind; `nil` for non-table kinds.
    public static func rows(for kind: SessionKind, maxHold: TimeInterval) -> [ApneaTableRow]? {
        switch kind {
        case .co2Table: return co2Rows(maxHold: maxHold)
        case .o2Table: return o2Rows(maxHold: maxHold)
        default: return nil
        }
    }
}

extension SessionPlan {
    /// Builds a runnable CO2 table plan from the user's max hold.
    public static func co2Table(maxHold: TimeInterval, parameters: CO2TableParameters = .standard) -> SessionPlan {
        let rows = ApneaTables.co2Rows(maxHold: maxHold, parameters: parameters)
        return tablePlan(kind: .co2Table, rows: rows, prepareDuration: parameters.prepareDuration)
    }

    /// Builds a runnable O2 table plan from the user's max hold.
    public static func o2Table(maxHold: TimeInterval, parameters: O2TableParameters = .standard) -> SessionPlan {
        let rows = ApneaTables.o2Rows(maxHold: maxHold, parameters: parameters)
        return tablePlan(kind: .o2Table, rows: rows, prepareDuration: parameters.prepareDuration)
    }

    private static func tablePlan(kind: SessionKind, rows: [ApneaTableRow], prepareDuration: TimeInterval) -> SessionPlan {
        var builder = PlanBuilder(roundCount: rows.count)
        builder.add(
            .prepare,
            duration: prepareDuration,
            instruction: "Sit or lie down somewhere safe. Breathe normally and relax.",
            voicePrompt: "Get ready"
        )
        for row in rows {
            builder.add(
                .recover,
                duration: row.breatheTime,
                round: row.cycle,
                instruction: "Breathe calmly for \(TimeFormatting.spoken(row.breatheTime)). Do not hyperventilate.",
                voicePrompt: "Breathe"
            )
            builder.add(
                .holdFull,
                duration: row.holdTime,
                round: row.cycle,
                instruction: "Take a full breath in, then hold for \(TimeFormatting.spoken(row.holdTime)).",
                voicePrompt: "Hold"
            )
        }
        return builder.plan(kind: kind)
    }
}
