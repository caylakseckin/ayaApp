import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class HESIANotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

enum MeditationReminderPersistenceKeys {
    static let isEnabled = "meditation.reminder.enabled"
    static let hour = "meditation.reminder.hour"
    static let minute = "meditation.reminder.minute"
}

@MainActor
enum MeditationReminderScheduler {
    static let requestIdentifier = "hesia.meditation.daily-reminder"

    static func requestPermissionAndSchedule(
        hour: Int,
        minute: Int,
        language: AppLanguage
    ) async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { return false }
            return await schedule(hour: hour, minute: minute, language: language)
        } catch {
            return false
        }
    }

    static func reschedule(
        hour: Int,
        minute: Int,
        language: AppLanguage
    ) async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return await schedule(hour: hour, minute: minute, language: language)
        case .notDetermined:
            return await requestPermissionAndSchedule(hour: hour, minute: minute, language: language)
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func disable() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
    }

    private static func schedule(
        hour: Int,
        minute: Int,
        language: AppLanguage
    ) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        let content = UNMutableNotificationContent()
        content.title = language.localizedString(forKey: "reminder.notification.title")
        content.body = language.localizedString(forKey: "reminder.notification.body")
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}

struct MeditationReminderSettings: View {
    enum Presentation {
        case welcome
        case settings
    }

    let presentation: Presentation

    @AppStorage(MeditationReminderPersistenceKeys.isEnabled) private var isEnabled = false
    @AppStorage(MeditationReminderPersistenceKeys.hour) private var reminderHour = 20
    @AppStorage(MeditationReminderPersistenceKeys.minute) private var reminderMinute = 0
    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue

    @State private var isUpdating = false
    @State private var showsPermissionAlert = false

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: reminderHour,
                    minute: reminderMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = components.hour ?? reminderHour
                reminderMinute = components.minute ?? reminderMinute
                guard isEnabled else { return }

                Task {
                    let scheduled = await MeditationReminderScheduler.reschedule(
                        hour: reminderHour,
                        minute: reminderMinute,
                        language: selectedLanguage
                    )
                    if !scheduled {
                        isEnabled = false
                        showsPermissionAlert = true
                    }
                }
            }
        )
    }

    var body: some View {
        Group {
            if presentation == .settings {
                VStack(alignment: .leading, spacing: 9) {
                    Text("reminder.section")
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textSecondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    reminderContent
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            AYAColors.cardSurface,
                            in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                                .stroke(AYAColors.divider, lineWidth: 1)
                        }
                }
            } else {
                reminderContent
            }
        }
        .alert("reminder.permission.title", isPresented: $showsPermissionAlert) {
            Button("reminder.permission.open_settings") {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL)
            }
            Button("reminder.permission.ok", role: .cancel) {}
        } message: {
            Text("reminder.permission.message")
        }
        .onChange(of: languageCode) { _, _ in
            guard isEnabled else { return }
            Task {
                _ = await MeditationReminderScheduler.reschedule(
                    hour: reminderHour,
                    minute: reminderMinute,
                    language: selectedLanguage
                )
            }
        }
        .task {
            guard isEnabled else { return }
            let scheduled = await MeditationReminderScheduler.reschedule(
                hour: reminderHour,
                minute: reminderMinute,
                language: selectedLanguage
            )
            if !scheduled {
                isEnabled = false
            }
        }
    }

    private var reminderContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HesiaIcon.notification.view(size: 18)
                    .foregroundStyle(AYAColors.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text("reminder.title")
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textPrimary)

                    Text("reminder.description")
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Toggle("reminder.title", isOn: reminderToggle)
                    .labelsHidden()
                    .tint(AYAColors.primary)
                    .disabled(isUpdating)
                    .accessibilityIdentifier("meditation.reminder.toggle")
            }

            if isEnabled {
                Rectangle()
                    .fill(AYAColors.divider)
                    .frame(height: 1)
                    .padding(.leading, 36)

                DatePicker(
                    "reminder.time",
                    selection: reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textPrimary)
                .tint(AYAColors.primary)
                .accessibilityIdentifier("meditation.reminder.time")
            }
        }
    }

    private var reminderToggle: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { newValue in
                if !newValue {
                    isEnabled = false
                    MeditationReminderScheduler.disable()
                    return
                }

                isEnabled = true
                isUpdating = true
                Task {
                    let scheduled = await MeditationReminderScheduler.requestPermissionAndSchedule(
                        hour: reminderHour,
                        minute: reminderMinute,
                        language: selectedLanguage
                    )
                    isEnabled = scheduled
                    isUpdating = false
                    if !scheduled {
                        showsPermissionAlert = true
                    }
                }
            }
        )
    }
}

#Preview("Reminder — Welcome") {
    MeditationReminderSettings(presentation: .welcome)
        .padding()
        .background(AYAColors.backgroundPrimary)
        .environment(\.locale, Locale(identifier: "tr"))
}
