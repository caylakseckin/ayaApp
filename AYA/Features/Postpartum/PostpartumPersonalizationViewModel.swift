import Combine
import Foundation

enum PostpartumPersonalizationMode: Sendable {
    case initial
    case edit
}

@MainActor
final class PostpartumPersonalizationViewModel: ObservableObject {
    let mode: PostpartumPersonalizationMode
    @Published var birthDate: Date

    private let store: PostpartumStore
    private let calendar: Calendar
    private let now: () -> Date

    init(
        mode: PostpartumPersonalizationMode = .initial,
        store: PostpartumStore = PostpartumStore(),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.mode = mode
        self.store = store
        self.calendar = calendar
        self.now = now
        birthDate = mode == .edit
            ? (store.profile?.birthDate ?? calendar.startOfDay(for: now()))
            : calendar.startOfDay(for: now())
    }

    var latestAllowedDate: Date {
        calendar.startOfDay(for: now())
    }

    var isValid: Bool {
        calendar.startOfDay(for: birthDate) <= latestAllowedDate
    }

    func selectBirthDate(_ date: Date) {
        let normalized = calendar.startOfDay(for: date)
        guard normalized <= latestAllowedDate else { return }
        birthDate = normalized
    }

    @discardableResult
    func save() -> Bool {
        isValid && store.save(birthDate: birthDate) != nil
    }
}
