# CellMate

CellMate is an iPhone app that helps e-bike and e-scooter owners charge safely, keep records for each battery and chargers, run simple inspections and get on-device safety guidance. It is a UTS 40872 group project (Group 6).

Built with SwiftUI, Core Data, ActivityKit (Live Activity), WidgetKit, UserNotifications and Foundation Models.

CellMate cannot switch off a charger, measure a battery's condition or tell you that a battery is safe. Risk levels describe logged checks and app rules, not a safety guarantee.

## What the app does

| Tab or area | What you can do |
| --- | --- |
| Home | See the charge running now, what needs attention and your batteries. Start or open a charge. Choose light, dark or system appearance. Open Settings. |
| Garage | Add batteries and matched chargers, open a battery's details, start a charge for it, run an inspection or retire it. |
| Charge flow | Tick three checks, choose a place and an unplug time, see a risk level with reasons, follow the countdown and finish the charge. |
| History | Review charges and inspections, newest first, with risk levels and details. |
| Ask | Describe a symptom or use Quick check. On supported devices, on-device AI reads the description and fixed rules give the advice. |
| Widget and Live Activity | See the running charge, the last charge and the next inspection due on the Home Screen and the Lock Screen. |
| Settings | Set your bedtime, check permissions, export records as CSV and delete all data. |

## Requirements

- Built and tested with Xcode 27.1. The minimum iOS version is **26.0**, so a device or simulator running iOS 26 can run the app.
- Apple Intelligence is checked at runtime. If it is not available, Ask uses Quick check, which works offline. Other features that depend on device settings, such as Live Activities and notifications, fall back gracefully.

## Run it

1. Open `CellMate/CellMate.xcodeproj`.
2. Select the CellMate target, then Signing and Capabilities. Choose your own Team and change the bundle identifier to something unique, such as `com.yourname.CellMate`. Do not commit those two changes.
3. Choose an iPhone simulator and press Run.

### App Group (needed for the widget to show real data)

The app and the widget share a small summary through an App Group. If you change the App Group name, change it in all three places:

- `CellMate/CellMate/CellMate.entitlements`
- `CellMate/CellMateWidgets/CellMateWidgets.entitlements`
- `CellMate/CellMate/Data/WidgetSnapshotStore.swift` (`appGroupID`)

On a simulator the app runs even if you leave it unchanged. On a real iPhone you need your own Team and an App Group registered for it.

## Run the tests

Press Cmd+U in Xcode. There are 137 unit tests and 4 UI tests (XCTest). For the UI tests, use serial testing (`-parallel-testing-enabled NO`), because parallel runs can time out on accessibility startup.

## How it is built

The app uses MVVM with a use case layer and repository protocols:

```
SwiftUI views  ->  view models  ->  use cases and rules  ->  repository protocols  ->  Core Data (SQLite)
                                          |
                                          +->  platform services behind protocols
                                               (notifications, Live Activity, permissions, on-device AI, photo files)
```

- `AppContainer` builds the repositories and services once and shares them with every screen.
- Core Data holds seven entities: Battery, Charger, ChargeSession, RiskFlag, Inspection, InspectionItem and PhotoEvidence. Photos are files, and the database keeps only the filename.
- The widget cannot open the app's database, so `WidgetSync` saves a small `WidgetSnapshot` in the App Group and the widget reads it.
- The risk rules are a pure, versioned function (`RiskRuleEngine`, version v1.0). Every charge stores the rules version that scored it.
- In memory repositories (`Data/Mocks`) are kept for unit tests and previews.

## Project structure

```
CellMate/
  CellMate.xcodeproj
  CellMate/                 app source
    CellMateApp.swift
    App/                    root view, tab bar and AppContainer
    DesignSystem/           colours, spacing, buttons, chips, cards
    Domain/                 models, rules, use cases, protocols
    Data/                   Core Data, repositories, widget snapshot, mocks
    Platform/               notifications, Live Activity, permissions, assistant, widget sync
    Features/
      Onboarding  Home  Settings        M A Diganta
      Permissions                       Julius Franklin
      Charge  History                   Jiaqi Pan
      Garage  Inspect                   Yufan Zou
      Ask                               Hanting Wang
    Assets.xcassets
  CellMateWidgets/          widget and Live Activity (Julius Franklin)
  CellMateTests/            unit tests (XCTest)
  CellMateUITests/          UI tests (XCTest)
docs/
  ASK_CELLMATE.md           Ask implementation, safety policy and demo steps
  CellMate_Data_Diagram.png data model diagram
```

## Team

| Member | Main areas |
| --- | --- |
| M A Diganta | App shell, design system, Core Data, Home, Settings and integration |
| Julius Franklin | Permissions, Live Activity, widgets and the widget data link |
| Jiaqi Pan | Start charge flow, risk rules and History |
| Yufan Zou | Garage, inspections and unit tests |
| Hanting Wang | Ask CellMate, on-device AI and Quick check |

## Third-party packages

None. The project uses only Apple frameworks.

## Data and privacy

All records stay on the iPhone. There is no account, no analytics and no networking code. Settings can export your records as a CSV file or delete everything, including inspection photos.

## Links

- Walkthrough video: (add link)
- Report: (add link)
- Ask CellMate notes: [docs/ASK_CELLMATE.md](docs/ASK_CELLMATE.md)

AI assistance is declared in the project report.
