import SwiftUI

// Design: 06 Start charge, 07 Charging, 08 Charge result
/// Shows the right screen for where the charge is: the form, the countdown or the result.
struct ChargeFlowView: View {
    @ObservedObject var viewModel: ChargeViewModel
    var onFinished: () -> Void = {}

    var body: some View {
        Group {
            switch viewModel.phase {
            case .form:
                StartChargeView(viewModel: viewModel)
            case .charging:
                ChargingView(viewModel: viewModel)
            case .complete:
                ChargeCompleteView(viewModel: viewModel, onDone: onFinished)
            }
        }
        .task { await viewModel.load() }
    }
}
