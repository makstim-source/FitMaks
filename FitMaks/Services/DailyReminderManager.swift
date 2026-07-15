import Foundation
import UserNotifications

final class DailyReminderManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DailyReminderManager()
    static let weeklyReportTappedNotification = Notification.Name("DailyReminderManager.weeklyReportTapped")

    private let notificationCenter = UNUserNotificationCenter.current()
    private let scheduleDays = 7
    private let breakfastHour = 11
    private let breakfastMinute = 0
    private let eveningHour = 19
    private let eveningMinute = 30

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["action"] as? String == "weekly_report" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.weeklyReportTappedNotification, object: nil)
            }
        }
        completionHandler()
    }

    func syncDailyReminders(progressToday: DayProgress, hasFoodToday: Bool, now: Date = Date()) {
        requestAuthorizationIfNeeded { [weak self] isAllowed in
            guard let self, isAllowed else { return }
            self.scheduleDailyReminders(progressToday: progressToday, hasFoodToday: hasFoodToday, now: now)
        }
    }

    private func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .notDetermined:
                self?.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { isGranted, _ in
                    completion(isGranted)
                }
            case .denied:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }

    private func scheduleDailyReminders(progressToday: DayProgress, hasFoodToday: Bool, now: Date) {
        let identifiers = reminderIdentifiers(startingAt: now)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)

        for dayOffset in 0..<scheduleDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else {
                continue
            }

            let isToday = calendar.isDate(day, inSameDayAs: now)

            if calendar.component(.weekday, from: day) == 2 {
                scheduleReminder(
                    identifier: weeklyReportIdentifier(for: day),
                    title: "Weekly report ready",
                    body: "Your previous week is summarized. See how you did!",
                    hour: 9,
                    minute: 0,
                    day: day,
                    now: now,
                    userInfo: ["action": "weekly_report"]
                )
            }

            if !isToday || !hasFoodToday {
                scheduleReminder(
                    identifier: breakfastIdentifier(for: day),
                    title: "Breakfast check",
                    body: "Did you add breakfast? Clean data now, calmer evening later.",
                    hour: breakfastHour,
                    minute: breakfastMinute,
                    day: day,
                    now: now
                )
            }

            if isToday {
                if !progressToday.proteinWin || !progressToday.stepWin {
                    scheduleReminder(
                        identifier: eveningIdentifier(for: day),
                        title: "Protect the streak",
                        body: eveningBody(for: progressToday),
                        hour: eveningHour,
                        minute: eveningMinute,
                        day: day,
                        now: now
                    )
                }
            } else {
                scheduleReminder(
                    identifier: eveningIdentifier(for: day),
                    title: "Streak check",
                    body: "Quick check: protein and steps still protect the streak.",
                    hour: eveningHour,
                    minute: eveningMinute,
                    day: day,
                    now: now
                )
            }
        }
    }

    private func scheduleReminder(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        day: Date,
        now: Date,
        userInfo: [String: String] = [:]
    ) {
        let calendar = Calendar.current
        guard let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day), fireDate > now else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if !userInfo.isEmpty { content.userInfo = userInfo }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    private func eveningBody(for progress: DayProgress) -> String {
        let proteinMissing = max(progress.proteinMinimum - progress.protein, 0)
        let stepsMissing = max(progress.stepMinimum - progress.effectiveSteps, 0)

        if proteinMissing > 0 && stepsMissing > 0 {
            return "\(Int(proteinMissing))g protein and \(Int(stepsMissing)) steps to save the day. Small rescue mission?"
        }

        if proteinMissing > 0 {
            return "\(Int(proteinMissing))g protein left to close the day. Easy win still on the table."
        }

        if stepsMissing > 0 {
            return "\(Int(stepsMissing)) steps left before the streak is safe. Tiny walk, big dignity."
        }

        return "Looks close. Open ShapeForge and lock the day in."
    }

    private func reminderIdentifiers(startingAt date: Date) -> [String] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: date)

        return (0..<scheduleDays).flatMap { offset -> [String] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: todayStart) else {
                return []
            }

            var ids = [breakfastIdentifier(for: day), eveningIdentifier(for: day)]
            if calendar.component(.weekday, from: day) == 2 {
                ids.append(weeklyReportIdentifier(for: day))
            }
            return ids
        }
    }

    private func breakfastIdentifier(for date: Date) -> String {
        "fitmaks.breakfast.\(DateFormatter.yyyyMMdd.string(from: date))"
    }

    private func eveningIdentifier(for date: Date) -> String {
        "fitmaks.evening.\(DateFormatter.yyyyMMdd.string(from: date))"
    }

    private func weeklyReportIdentifier(for date: Date) -> String {
        "fitmaks.weekly.\(DateFormatter.yyyyMMdd.string(from: date))"
    }
}
