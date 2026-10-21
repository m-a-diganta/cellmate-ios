import Foundation

/// App-owned triage policy. AI only extracts symptoms; it cannot write advice or clear a concern.
/// Sources and policy choices are documented in docs/ASK_CELLMATE.md.
nonisolated enum BatteryProblemRules {
    static let version = "ask-1.0"
    static let sourceURL = URL(string: "https://www.fire.nsw.gov.au/fire-safety/home-fire-safety/battery-and-charging-safety/what-should-i-do-if-my-battery-is-smoking-or-on-fire")!

    static func level(for symptoms: Set<BatterySymptom>, retired: Bool = false) -> BatteryAdviceLevel {
        if !symptoms.isDisjoint(with: [.smokeOrFlames, .hissingOrPopping]) { return .emergency }
        if retired || !symptoms.isDisjoint(with: [.swelling, .excessiveHeat, .unusualSmell, .leaking, .physicalDamage, .chargerConcern]) {
            return .stopUsing
        }
        return symptoms.isEmpty ? .info : .caution
    }

    /// Conservative mentions are a floor, not a diagnosis or a complete language parser.
    /// A model cannot negate these matches. Unrecognised descriptions require Quick check.
    static func mentionedSymptoms(in text: String) -> Set<BatterySymptom> {
        let value = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let words: [(BatterySymptom, [String])] = [
            (.smokeOrFlames, ["smoke", "smoking", "flame", "fume", "vapour", "vapor", "on fire", "冒烟", "起火", "着火"]),
            (.hissingOrPopping, ["hiss", "popping", "crackling", "嘶嘶", "噼啪"]),
            (.swelling, ["swollen", "swelling", "bulging", "puffed", "鼓包", "膨胀"]),
            (.excessiveHeat, ["hot", "overheat", "烫", "过热"]),
            (.unusualSmell, ["smell", "odour", "odor", "异味"]),
            (.leaking, ["leak", "漏液"]),
            (.physicalDamage, ["crack", "dent", "puncture", "crush", "damage", "破损"]),
            (.chargerConcern, ["wrong charger", "unmatched", "different charger", "充电器"]),
            (.unsafeCharging, ["overnight", "unattended", "while asleep", "整夜", "无人看管"])
        ]
        return Set(words.compactMap { symptom, terms in
            terms.contains { term in
                if term.first?.isASCII == true {
                    // Match word stems, not substrings such as "hot" inside "photo".
                    let pattern = "\\b" + NSRegularExpression.escapedPattern(for: term) + "[a-z]*\\b"
                    return value.range(of: pattern, options: .regularExpression) != nil
                }
                return value.contains(term)
            } ? symptom : nil
        })
    }

    static func steps(for level: BatteryAdviceLevel) -> [String] {
        switch level {
        case .emergency:
            ["Move away and get everyone out. Do not touch or move the battery.",
             "Call Triple Zero (000) from a safe place.",
             "Keep clear of smoke and fumes. Stay outside and wait for firefighters."]
        case .stopUsing:
            ["Stop using and charging the battery. Do not handle a hot, swollen or leaking battery.",
             "Keep people away. If smoke, flames or hissing develops, leave and call 000.",
             "Contact the manufacturer or a qualified repairer before using it again."]
        case .caution:
            ["Pause charging while you check the concern. Keep exits clear.",
             "Use the manufacturer's compatible charger and follow its instructions. Stay awake and nearby.",
             "If you are unsure about the battery's condition, stop using it and ask the manufacturer or a qualified repairer."]
        case .info:
            ["No listed warning signs were reported. This does not confirm the battery is safe.",
             "Follow the manufacturer's charging instructions and remain nearby and awake.",
             "Check regularly for changes. Stop using the battery if a warning sign appears."]
        }
    }
}
