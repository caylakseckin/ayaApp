import Foundation

@MainActor
final class LifeStageSelectionViewModel: ObservableObject {
    @Published private(set) var selectedStage: LifeStage

    init(selectedStage: LifeStage = .cycle) {
        self.selectedStage = selectedStage
    }

    func select(_ stage: LifeStage) {
        selectedStage = stage
    }
}
