import Foundation
import UserNotifications

enum NotificationManager {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    static func notifyNewGrades(_ grades: [GradeItem]) async {
        guard !grades.isEmpty, await isAuthorized() else { return }

        let content = UNMutableNotificationContent()
        if grades.count == 1, let g = grades.first {
            content.title = "Nowa ocena: \(g.raw)"
            content.body = "\(g.subjectName)\(g.categoryName.isEmpty ? "" : " — \(g.categoryName)")"
        } else {
            content.title = "Nowe oceny (\(grades.count))"
            content.body = grades.prefix(5).map { "\($0.raw) \($0.subjectName)" }.joined(separator: ", ")
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "grades-\(UUID().uuidString)", content: content, trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func notifyTimetableChanges(_ lines: [String]) async {
        guard !lines.isEmpty, await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        content.title = lines.count == 1 ? "Zmiana w planie lekcji"
                                         : "Zmiany w planie lekcji (\(lines.count))"
        content.body = lines.prefix(4).joined(separator: "\n")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "timetable-\(UUID().uuidString)", content: content, trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func notifyNewMessages(_ messages: [MessageItem]) async {
        guard !messages.isEmpty, await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        if messages.count == 1, let m = messages.first {
            content.title = "Nowa wiadomość"
            content.body = "\(m.correspondent): \(m.subject.isEmpty ? "(bez tematu)" : m.subject)"
        } else {
            content.title = "Nowe wiadomości (\(messages.count))"
            content.body = messages.prefix(5).map(\.correspondent).joined(separator: ", ")
        }
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "messages-\(UUID().uuidString)", content: content, trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func sendTestNotification() async {
        guard await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Mój Librus"
        content.body = "Powiadomienia działają. Tak wyglądałaby informacja o nowej ocenie."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "test-\(UUID().uuidString)", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
