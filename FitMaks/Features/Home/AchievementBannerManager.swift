import SwiftUI

extension HomeViewModel {
    func refreshAchievementBannerQueue() {
        let seenRaw = UserDefaults.standard.string(forKey: "seenAchievementUnlockIDs") ?? ""
        let seenIDs = Set(seenRaw.split(separator: "|").map(String.init))
        let unlocked = cachedAchievementCollection.all.filter(\.isUnlocked)
        let unseen = unlocked.filter { !seenIDs.contains($0.id) }
        guard !unseen.isEmpty else { return }

        pendingAchievementBanners = unseen.sorted { lhs, rhs in
            if lhs.family != rhs.family { return lhs.family == .core }
            if lhs.rarity.rawValue != rhs.rarity.rawValue { return lhs.rarity.rawValue > rhs.rarity.rawValue }
            return lhs.title < rhs.title
        }

        if achievementBanner == nil { showNextAchievementBanner() }
    }

    func showNextAchievementBanner() {
        guard !pendingAchievementBanners.isEmpty else { return }
        let next = pendingAchievementBanners.removeFirst()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            achievementBanner = next
        }
    }

    func dismissAchievementBanner() {
        guard let current = achievementBanner else { return }
        let seenRaw = UserDefaults.standard.string(forKey: "seenAchievementUnlockIDs") ?? ""
        var seenIDs = Set(seenRaw.split(separator: "|").map(String.init))
        seenIDs.insert(current.id)
        UserDefaults.standard.set(seenIDs.sorted().joined(separator: "|"), forKey: "seenAchievementUnlockIDs")

        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            achievementBanner = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.showNextAchievementBanner()
        }
    }

    func postAchievementBanner() {
        guard let current = achievementBanner else { return }
        let payload = achievementSharePayload(from: current)
        dismissAchievementBanner()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.livePayload = payload
        }
    }

    func achievementSharePayload(from achievement: StatsAchievement) -> FitMaksSharePayload {
        .achievement(
            FitMaksShareAchievementSnapshot(
                title: achievement.title,
                familyLabel: achievement.family == .core ? "Core trophy" : "Side quest",
                subtitle: achievement.subtitle,
                detail: achievement.detail,
                goalText: achievement.goalText,
                progressText: achievement.progressText,
                icon: achievement.icon,
                color: achievement.color,
                isUnlocked: achievement.isUnlocked,
                progress: achievement.progress,
                hasStarted: achievement.current > 0
            )
        )
    }
}
