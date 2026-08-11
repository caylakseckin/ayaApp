import Combine
import Foundation

@MainActor
final class MotherhoodPersonalizationViewModel: ObservableObject {
    @Published var selectedRange: MotherhoodAgeRange
    private let store: MotherhoodStore

    init(
        selectedRange: MotherhoodAgeRange = .toddler,
        store: MotherhoodStore = MotherhoodStore()
    ) {
        self.selectedRange = selectedRange
        self.store = store
    }

    func save() {
        store.save(selectedRange)
    }
}
