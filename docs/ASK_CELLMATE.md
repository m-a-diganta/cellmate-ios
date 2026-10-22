# Ask CellMate — Person 5 / Hanting Wang

Work branch: `hanting-wang`. Scope: Ask, Ask result, Quick check, `AssessBatteryProblem`, and the `BatteryAssistant` service.

## Environment

Use Xcode **27 or later**. Implementation uses Xcode **27.1 (27A9275)**, iOS **27.1 SDK**, and an iPhone 18 Pro simulator running **iOS 27.0**. The shared deployment target stays at iOS 26.0; Xcode version and minimum supported iOS version are different settings. No signing team or bundle identifier was changed.

## Flow and boundaries

1. Choose an optional battery and symptom chips, or enter up to 1,000 characters.
2. `AssessBatteryProblem` establishes a deterministic minimum severity from selected symptoms, conservative text mentions, and a retired battery flag.
3. Stop-using and emergency cases return immediately without waiting for AI.
4. When available, Apple's on-device Foundation Models service generates only a fixed symptom enum. A read-only tool can look up the selected battery snapshot. No generated advice is displayed, and no network AI or API key is used.
5. Extracted symptoms are added to the baseline. They can increase severity, never remove a concern. Empty, unknown, failed or unavailable generation requires Quick check. A person can also cancel a slow request and open Quick check.
6. Quick check works without AI. An explicit no-signs response can return Info, with a statement that this does not certify safety. A follow-up check cannot lower an existing result.
7. Result pages show three fixed next steps, sources, date and rule version. Saving delegates to an injected inspection service and only confirms success after that service returns successfully.

The layers are SwiftUI views → `AskViewModel` → `AssessBatteryProblem` → `BatteryAssistant` / repository protocols. Views do not read a database.

## Integration needed from Person 1 and Person 4

The shared branch currently contains placeholder data and inspection features. Ask intentionally does not create a competing database or pretend to save records.

- Implement `AskBatteryProviding.batteries()` as a projection from the shared battery repository to `AskBattery` (UUID, name, brand, retired).
- Implement `AskInspectionLogging.log(_:for:)` by calling Person 4's `LogInspection`. Use `BatteryAssessment.id` as an idempotency key, preserve the assessment date, symptoms, source and `rulesVersion`, and associate it with the chosen battery.
- An Ask result is a **reported concern**, not proof that all five physical inspection checks were performed. Do not mark unasked inspection items as OK. Map severity to the shared inspection schema only after agreeing this with Person 4.
- Construct `AskDependencies(assistant:batteries:inspections:)` in the shared dependency container and pass it to `AskView(dependencies:)` in `RootTabView`.
- Until this is connected, `AskDependencies.pendingIntegration()` supplies no battery records. Guidance works, but Log as inspection reports that nothing was saved. The multi-battery picker and save success/failure paths are tested using mocks.

## Rules and source material

Policy version: `ask-1.0`.

| Observed concern | App response |
| --- | --- |
| Smoke/flames or hissing/popping | Emergency |
| Swelling, excessive heat, unusual smell, leaking, damage, charger concern, or a retired record | Stop using |
| Unattended/overnight charging, uncertainty, unclassified description | Caution |
| Standalone checklist with explicitly no listed signs noticed | Info; never a safety guarantee |

These response categories are CellMate's conservative policy, not an official battery diagnosis. In particular, classifying hissing/popping as Emergency and any charger concern as Stop using is an app policy choice. Text matching is deliberately conservative and may match a negated or historical warning; it must not be presented as complete language understanding. The checklist is always available.

Sources checked 21 October 2026:

- [Fire and Rescue NSW: smoking, fire and warning signs](https://www.fire.nsw.gov.au/fire-safety/home-fire-safety/battery-and-charging-safety/what-should-i-do-if-my-battery-is-smoking-or-on-fire).
- [FRNSW Battery and Charging Safety fact sheet](https://www.fire.nsw.gov.au/fire-safety/home-fire-safety/battery-and-charging-safety/files/chargesafe.pdf).
- [Apple: Foundation Models](https://developer.apple.com/documentation/foundationmodels).
- [Apple: guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation).
- [Apple: tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling).
- [Team project brief](https://docs.google.com/document/d/1DBCfAYi3_msdfPAxrqIbSp_IXxAsLxv4k2V_Mv0kJCg).

Emergency advice prioritises leaving, calling 000 and avoiding smoke. This feature does not offer battery repair or handling instructions. Its fixed copy retains the brief's “CellMate can’t tell you a battery is safe” and “Guidance can be wrong. Follow the maker’s advice.”

## Design and demo

The three screens use the repository's `AppColor`, card, spacing and button styles with semantic fonts, scrolling layouts, accessibility labels and a native navigation stack. Figma access was denied by the connector on 21 October 2026, so exact fidelity to frames 13–15 has **not** been verified. Recheck after access to the team's design file is granted.

Demo without AI:

1. Open Ask → choose Swollen or bulging → Get guidance → Stop using and three steps.
2. Open Quick check → select Smoke or flames → Show guidance → Emergency.
3. Start a fresh Quick check → select None of these signs noticed → Info with the safety limitation.
4. Repeat in Dark Mode and with accessibility text sizes.
5. Log as inspection currently explains that no record was saved; after integration, demonstrate selecting a battery and an actual saved inspection.

`AskCellMateTests.swift` tests severity floors, AI failure/unavailability/cancellation, explicit checklist answers, retired batteries, scoped battery lookup, and repository save behaviour. `AskCellMateUITests.swift` covers the emergency flow, dark mode and large accessibility text. Real model generation still needs an Apple Intelligence-enabled device with its model downloaded; mock tests and simulator UI checks do not certify real-device inference.

## Validation scope

On 21 October 2026, all **36 unit tests** passed on iOS 27.0, including **20 new Ask tests**. All **3 Ask UI tests** also passed; after the layout adjustment, the three UI tests were rerun successfully. Dark snapshots use the DEBUG-only `--ask-ui-dark` launch argument to set the Ask colour scheme explicitly; the simulator's system appearance switch did not produce a dark app screenshot. Release builds follow the device's appearance. Use serial simulator testing (`-parallel-testing-enabled NO`); an initial parallel run hit an accessibility-service startup timeout.

The existing `CellMateUITests.testWelcomeThenFourTabs` also failed during the exploratory full-suite run. It was not changed or included in the final Ask-focused run; its onboarding flow needs a separate check by the shell owner. A passing Ask suite must not be reported as a passing complete app UI suite.

## Authorship disclosure

This implementation and its tests were prepared with Codex assistance for Hanting Wang. Review and understand the feature before presenting it, and include the assistance in the assessment's AI-use declaration.
