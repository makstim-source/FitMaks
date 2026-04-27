import Foundation

enum ICloudSettingsSync {
    private static let kvStore = NSUbiquitousKeyValueStore.default

    private static let syncKeys = [
        "userGender", "userAge", "userWeight", "userHeight",
        "userGoal", "userActivity", "useCustomGoals",
        "customCalories", "customProtein",
        "hasCompletedOnboarding",
        "lastKnownBaseCaloriesGoal", "lastKnownBaseProteinGoal",
        "appleUserName", "appleUserEmail"
    ]

    static func pushToICloud() {
        for key in syncKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                kvStore.set(value, forKey: key)
            }
        }
        kvStore.synchronize()
    }

    static func pullFromICloud() {
        kvStore.synchronize()

        for key in syncKeys {
            guard let cloudValue = kvStore.object(forKey: key) else { continue }
            let localValue = UserDefaults.standard.object(forKey: key)

            if localValue == nil || isDefault(key: key, value: localValue) {
                UserDefaults.standard.set(cloudValue, forKey: key)
            }
        }
    }

    static func startObserving() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore,
            queue: .main
        ) { _ in
            pullFromICloud()
        }
        kvStore.synchronize()
    }

    private static func isDefault(key: String, value: Any?) -> Bool {
        switch key {
        case "userAge":
            return (value as? Int) == 30
        case "userWeight":
            return (value as? Double) == 80.0
        case "userHeight":
            return (value as? Double) == 180.0
        case "userGender":
            return (value as? String) == "Male"
        case "userGoal":
            return (value as? String) == "Lose Weight"
        case "userActivity":
            return (value as? String) == "Moderate"
        case "hasCompletedOnboarding":
            return (value as? Bool) == false
        case "useCustomGoals":
            return (value as? Bool) == false
        case "customCalories", "customProtein":
            return (value as? Double) == 0.0
        default:
            return false
        }
    }
}
