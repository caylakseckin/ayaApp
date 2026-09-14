import Combine
import Foundation

@MainActor
final class PregnancySetupViewModel: ObservableObject {
    @Published var selectedWeek: Int?
    @Published var selectedWeekStartDay: PregnancyWeekStartDay?

    private let store: PregnancyStore

    init(
        selectedWeek: Int? = nil,
        selectedWeekStartDay: PregnancyWeekStartDay? = nil,
        store: PregnancyStore = PregnancyStore()
    ) {
        self.selectedWeek = selectedWeek
        self.selectedWeekStartDay = selectedWeekStartDay
        self.store = store
    }

    var canContinue: Bool {
        guard let selectedWeek, selectedWeekStartDay != nil else { return false }
        return PregnancyTracker.supportedWeekRange.contains(selectedWeek)
    }

    @discardableResult
    func save() -> Bool {
        guard let selectedWeek, let selectedWeekStartDay, canContinue else { return false }
        return store.save(
            referenceWeek: selectedWeek,
            weekStartDay: selectedWeekStartDay
        ) != nil
    }
}
