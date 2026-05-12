import Foundation

enum AIUsageLimiter {
    private static let scanCountKey = "fitmaks_free_scan_count"
    private static let scanDateKey = "fitmaks_free_scan_date"
    static let dailyFreeLimit = 5

    static var scansUsedToday: Int {
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: scanCountKey)
    }

    static var scansRemaining: Int {
        max(dailyFreeLimit - scansUsedToday, 0)
    }

    static var canScan: Bool {
        SubscriptionManager.shared.isPro || scansRemaining > 0
    }

    static func recordScan() {
        guard !SubscriptionManager.shared.isPro else { return }
        resetIfNewDay()
        let count = UserDefaults.standard.integer(forKey: scanCountKey)
        UserDefaults.standard.set(count + 1, forKey: scanCountKey)
    }

    private static func resetIfNewDay() {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        let stored = UserDefaults.standard.string(forKey: scanDateKey) ?? ""
        if stored != today {
            UserDefaults.standard.set(today, forKey: scanDateKey)
            UserDefaults.standard.set(0, forKey: scanCountKey)
        }
    }
}
