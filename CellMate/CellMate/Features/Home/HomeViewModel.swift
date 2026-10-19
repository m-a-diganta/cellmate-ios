import Foundation
import Observation

@Observable
final class HomeViewModel {
    private(set) var summary: HomeSummary
    private let provider: any HomeSummaryProviding

    init(provider: any HomeSummaryProviding, initial: HomeSummary = .empty) {
        self.provider = provider
        self.summary = initial
    }

    func load() async {
        summary = await provider.loadSummary()
    }
}
