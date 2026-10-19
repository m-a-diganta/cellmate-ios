# CellMate

CellMate: an iPhone app that helps e-bike and e-scooter owners charge safely, log batteries and inspections, and get on-device safety guidance. SwiftUI, Core Data, Live Activity, WidgetKit, Foundation Models. UTS 40872 group project.

## Run it
1. Install the latest Xcode (the on-device AI needs it).
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
      Onboarding  Home  Settings        Person 1
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

Read `docs/STYLE_AND_STRUCTURE.md` before you write any screen.
