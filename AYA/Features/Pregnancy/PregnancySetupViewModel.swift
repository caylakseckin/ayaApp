import Combine
import Foundation

@MainActor
final class PregnancySetupViewModel: ObservableObject {
    @Published var selectedWeek: Int?

    private let store: PregnancyStore

    init(selectedWeek: Int? = nil, store: PregnancyStore = PregnancyStore()) {
        self.selectedWeek = selectedWeek
        self.store = store
    }

    var canContinue: Bool {
        guard let selectedWeek else { return false }
        return PregnancyTracker.supportedWeekRange.contains(selectedWeek)
    }

    @discardableResult
    func save() -> Bool {
        guard let selectedWeek, canContinue else { return false }
        return store.save(referenceWeek: selectedWeek) != nil
    }
}
