import Foundation

/// A piece of educational copy shown in onboarding, the Learn tab and tooltips.
public struct EducationTopic: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    /// One-line summary for cards.
    public let summary: String
    /// Paragraphs of body copy.
    public let paragraphs: [String]
    public let symbolName: String

    public init(id: String, title: String, summary: String, paragraphs: [String], symbolName: String) {
        self.id = id
        self.title = title
        self.summary = summary
        self.paragraphs = paragraphs
        self.symbolName = symbolName
    }
}

/// Educational content derived from PRD §2 (scientific foundation) plus the
/// safety guidance any breath-hold training tool must carry.
public enum Education {
    // MARK: Core mechanisms (PRD §2)

    public static let metaboreflex = EducationTopic(
        id: "metaboreflex",
        title: "Delaying the Respiratory Metaboreflex",
        summary: "Strong breathing muscles keep blood in your limbs for longer.",
        paragraphs: [
            "When the diaphragm and the other breathing muscles tire, the brain triggers the respiratory metaboreflex: it shunts blood away from your arms and legs and back toward the lungs to protect ventilation.",
            "Strengthening those muscles delays the point at which the reflex fires. The practical effect for athletes is that peripheral power output holds up longer before fatigue sets in.",
            "Inspiratory Muscle Training targets this directly. Forceful inhales against resistance load the diaphragm the way squats load the legs.",
        ],
        symbolName: "figure.run"
    )

    public static let co2Tolerance = EducationTopic(
        id: "co2",
        title: "Building CO2 Tolerance",
        summary: "The urge to breathe comes from carbon dioxide, not a lack of oxygen.",
        paragraphs: [
            "The urge to breathe is driven by carbon dioxide building up in the blood, not by oxygen running out. Chemoreceptors in the brain watch CO2 closely and trigger air hunger well before oxygen becomes a problem.",
            "Training with controlled holds desensitises those receptors. The panic response arrives later and feels milder, which helps vocalists hold notes longer and athletes stay composed during hard efforts.",
            "The BOLT score measures this tolerance. Cadence breathing and CO2 tables are the tools for improving it.",
        ],
        symbolName: "wind"
    )

    public static let hypoxicTraining = EducationTopic(
        id: "iht",
        title: "Intermittent Hypoxic Training",
        summary: "Brief, safe dips in blood oxygen ask the body for more red blood cells.",
        paragraphs: [
            "Pushing through air hunger safely lowers blood oxygen saturation for a short time. This acute hypoxia is a strong training signal.",
            "The spleen responds by contracting and releasing stored red blood cells, and the kidneys are nudged to produce erythropoietin (EPO), which drives the creation of new red blood cells over the following weeks.",
            "More red blood cells mean more oxygen-carrying capacity: the physical basis of a higher VO2 max. Hypoxic sprints and O2 tables deliver this stimulus.",
        ],
        symbolName: "drop.fill"
    )

    public static let mechanisms: [EducationTopic] = [metaboreflex, co2Tolerance, hypoxicTraining]

    // MARK: Safety

    public static let safetyRules: [String] = [
        "Never practise breath holds in or near water. Blackouts happen without warning.",
        "Never practise while driving, cycling or operating machinery.",
        "Do apnea tables sitting or lying down. Fainting from a chair or the floor is safe; fainting while standing is not.",
        "Stop immediately if you feel dizzy, see spots, get tingling in your hands or feel your vision narrow.",
        "Do not hyperventilate before a hold. It removes the CO2 warning signal that protects you.",
        "Walk hypoxic sprints on flat, familiar ground away from traffic.",
        "Get medical clearance first if you are pregnant or have a heart, blood pressure, lung or seizure condition, or a history of fainting.",
    ]

    public static let safety = EducationTopic(
        id: "safety",
        title: "Train Safely",
        summary: "Breath-hold training is powerful. Treat it with respect.",
        paragraphs: [
            "Every protocol in this app deliberately creates air hunger and, in some cases, brief hypoxia. Done in a safe place, seated or on flat ground, that stimulus is what drives adaptation.",
            "Done in the wrong place it can be dangerous. The rules below are not optional. This app is a training aid, not medical advice.",
        ],
        symbolName: "exclamationmark.shield.fill"
    )

    // MARK: Protocol guides (PRD §3 and §4)

    public static func guide(for kind: SessionKind) -> EducationTopic {
        switch kind {
        case .cadence:
            return EducationTopic(
                id: "guide.cadence",
                title: "CO2 Tolerance Builder",
                summary: "Paced 4-6-4-6 breathing with holds that grow as your BOLT score improves.",
                paragraphs: [
                    "Follow the circle. Inhale as it expands, hold while it stays full, exhale as it contracts, hold while it stays empty.",
                    "The base ratio is 4 seconds in, 6 seconds hold, 4 seconds out, 6 seconds hold. Every extra 3 points of BOLT above 25 adds a second to both holds, up to 15 seconds.",
                    "Air hunger during the empty hold is the point. Stay relaxed, keep your shoulders down, and let the urge pass rather than fighting it.",
                ],
                symbolName: kind.symbolName
            )
        case .hypoxicSprints:
            return EducationTopic(
                id: "guide.sprints",
                title: "Hypoxic Sprints",
                summary: "Exhale, pinch your nose, walk a set number of paces, recover for a minute.",
                paragraphs: [
                    "This is an audio-guided walking workout. Put your headphones in, find flat safe ground and walk at an easy pace.",
                    "On each prompt, exhale fully, pinch your nose and keep walking for the number of paces the app gives you. The count is calculated from your max breath hold. Release, breathe normally for one minute, and repeat 5 to 10 times.",
                    "Walking with empty lungs drops blood oxygen quickly and safely. That is the stimulus for spleen contraction and EPO release.",
                ],
                symbolName: kind.symbolName
            )
        case .co2Table:
            return EducationTopic(
                id: "guide.co2",
                title: "CO2 Table",
                summary: "Holds stay at half your max while the rest between them shrinks.",
                paragraphs: [
                    "Each round is a period of calm breathing followed by a hold at 50% of your max breath hold.",
                    "The breathing period starts at 2 minutes and drops by 15 seconds every round, never below 15 seconds. CO2 accumulates from round to round, which is exactly what trains tolerance.",
                    "Breathe calmly during recovery. Do not hyperventilate.",
                ],
                symbolName: kind.symbolName
            )
        case .o2Table:
            return EducationTopic(
                id: "guide.o2",
                title: "O2 Table",
                summary: "Rest stays fixed at 2 minutes while each hold gets longer.",
                paragraphs: [
                    "Each round is 2 minutes of calm breathing followed by a hold. The first hold is 40% of your max; the last is 80%.",
                    "Fixed recovery keeps CO2 in check so each hold pushes your low-oxygen tolerance rather than your CO2 tolerance.",
                    "Stop the session if a hold feels wrong. The table will be here tomorrow.",
                ],
                symbolName: kind.symbolName
            )
        case .imt:
            return EducationTopic(
                id: "guide.imt",
                title: "Inspiratory Muscle Training",
                summary: "Three sets of fifteen forceful inhales against resistance.",
                paragraphs: [
                    "Create resistance with pursed lips or by breathing through a straw, then inhale hard and fast, driving with the diaphragm. Relax and exhale normally between reps.",
                    "The app counts sets and reps and gives you a minute of rest between sets.",
                    "Stronger breathing muscles delay the respiratory metaboreflex and improve subglottic pressure control for singers.",
                ],
                symbolName: kind.symbolName
            )
        case .boltAssessment:
            return EducationTopic(
                id: "guide.bolt",
                title: "BOLT Score",
                summary: "How long after a normal exhale until you first feel the urge to breathe.",
                paragraphs: [
                    "Rest quietly for a moment. Take a normal inhale and a normal exhale, then pinch your nose and start the timer.",
                    "Stop at the first physical urge to breathe or swallow, not at your limit. This measures CO2 sensitivity, not willpower.",
                    "Around 25 seconds is normal. 40 seconds and above is elite. Re-test every two weeks; your cadence holds scale with this number.",
                ],
                symbolName: kind.symbolName
            )
        case .maxHoldAssessment:
            return EducationTopic(
                id: "guide.maxhold",
                title: "Max Breath Hold",
                summary: "Your longest static hold on full lungs, seated and safe.",
                paragraphs: [
                    "Take three deep breaths. On the final inhale, fill your lungs to 100% and hold.",
                    "Stop the timer when you are forced to exhale. Sit or lie down; never do this in water.",
                    "Apnea tables and hypoxic sprints are scaled from this number.",
                ],
                symbolName: kind.symbolName
            )
        case .breathCountAssessment:
            return EducationTopic(
                id: "guide.count",
                title: "Single Breath Count",
                summary: "Count aloud at a steady pace on one exhale until your lungs are empty.",
                paragraphs: [
                    "Inhale fully, start the timer and count out loud: 1, 2, 3... at a steady, comfortable pace.",
                    "Stop when your lungs are completely empty. Note the number you reached as well as the time.",
                    "This tracks the breath control vocalists need for long phrases.",
                ],
                symbolName: kind.symbolName
            )
        }
    }

    // MARK: Daily tips

    public static let tips: [String] = [
        "Nasal breathing at rest keeps CO2 tolerance high between sessions.",
        "Air hunger is a CO2 signal, not an oxygen alarm. Let it rise and pass.",
        "Relax your shoulders and jaw before every hold. Tension burns oxygen.",
        "A BOLT re-test every two weeks keeps your holds scaled to you.",
        "Never train breath holds in water. Not even shallow water.",
        "The last three seconds of a hold are where the adaptation happens.",
        "Walk hypoxic sprints on the same safe route every time.",
        "Sit or lie down for tables. Fainting from a chair is harmless; from standing it is not.",
        "Hyperventilating before a hold removes your safety signal. Breathe calmly.",
        "Diaphragm strength delays the metaboreflex: power stays in your legs.",
        "Singers: the single breath count grows fastest with daily cadence work.",
        "Consistency beats intensity. Ten calm minutes a day compounds.",
        "Sleep and hydration change your BOLT score. Test at the same time of day.",
        "Progress shows in how the hold feels, not only in the seconds.",
    ]

    /// Deterministic tip of the day.
    public static func tip(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        let index = (day + year) % tips.count
        return tips[index]
    }
}
