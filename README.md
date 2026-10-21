# CellMate

CellMate: an iPhone app that helps e-bike and e-scooter owners charge safely, log batteries and inspections, and get on-device safety guidance. SwiftUI, Core Data, Live Activity, WidgetKit, Foundation Models. UTS 40872 group project.

## Run it
1. Use Xcode 27 or later (Person 5's feature is built with Xcode 27.1 / iOS 27.1 SDK). The project's iOS deployment target remains 26.0. Apple Intelligence availability is checked at runtime; Quick check works without it.
2. Open `CellMate/CellMate.xcodeproj`.
3. Select the CellMate target, then Signing and Capabilities. Choose your own Team and change the bundle identifier to something unique, such as `com.yourname.CellMate`. Do not commit those two changes.
4. Choose an iPhone simulator and press Run.
5. Press Cmd+U to run the unit tests and UI tests (XCTest).

## Project structure
```
CellMate/
  CellMate.xcodeproj
  CellMate/                 app source
    CellMateApp.swift
    App/                    root view and tab bar
    DesignSystem/           colours, spacing, buttons, chips, cards
    Domain/                 models, rules, use cases, protocols
    Data/                   Core Data, repositories, mocks
    Platform/               notifications, Live Activity, permissions, assistant
    Features/
      Onboarding  Home  Settings        Diganta
      Permissions                       Person 2
      Charge  History                   Person 3
      Garage  Inspect                   Person 4
      Ask                               Person 5
    Assets.xcassets
  CellMateTests/            unit tests (XCTest)
  CellMateUITests/          UI tests (XCTest)
docs/
  STYLE_AND_STRUCTURE.md    colours, rules, folder owners
```

## Ask CellMate — Hanting Wang (Person 5)

The Ask tab includes symptom chips, on-device symptom classification, fixed-rule results, and an offline Quick check. See [Ask implementation and integration notes](docs/ASK_CELLMATE.md) for the Person 1/4 repository handoff, safety policy, and demo steps.
