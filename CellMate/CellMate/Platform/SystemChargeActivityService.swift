import ActivityKit
import Foundation

/// The real Live Activity. Only one charge runs at a time, so it works on the first activity.
/// iOS keeps the activity across app relaunches, so `Activity.activities` finds it again.
struct SystemChargeActivityService: ChargeActivityControlling {
    private var current: Activity<ChargeActivityAttributes>? {
        Activity<ChargeActivityAttributes>.activities.first
    }

    func start(batteryName: String, startedAt: Date, unplugAt: Date) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw ChargeActivityError.turnedOff }
        let state = ChargeActivityAttributes.ContentState(startedAt: startedAt, unplugAt: unplugAt)
        do {
            _ = try Activity.request(
                attributes: ChargeActivityAttributes(batteryName: batteryName),
                content: ActivityContent(state: state, staleDate: unplugAt)
            )
        } catch {
            throw ChargeActivityError.couldNotStart
        }
    }

    func update(unplugAt: Date) async {
        guard let activity = current else { return }
        var state = activity.content.state
        state.unplugAt = unplugAt
        await activity.update(ActivityContent(state: state, staleDate: unplugAt))
    }

    func end() async {
        for activity in Activity<ChargeActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
