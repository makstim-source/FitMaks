import SwiftUI

// MARK: - Utility & Icon Generation
extension HomeViewModel {

    func generatePlaceholderIcon(systemName: String, color: Color) -> UIImage {
        let size = CGSize(width: 150, height: 150)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(white: 0.15, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 25).fill()
            if let icon = UIImage(
                systemName: systemName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 60, weight: .bold)
            )?.withTintColor(UIColor(color), renderingMode: .alwaysOriginal) {
                icon.draw(at: CGPoint(
                    x: (size.width - icon.size.width) / 2,
                    y: (size.height - icon.size.height) / 2
                ))
            }
        }
    }

    func generateEmojiIcon(emoji: String) -> UIImage {
        let size = CGSize(width: 150, height: 150)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(white: 0.15, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 25).fill()
            let safeEmoji = emoji.isEmpty ? "🍽️" : emoji
            let nsString = safeEmoji as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 75)]
            let stringSize = nsString.size(withAttributes: attributes)
            nsString.draw(
                at: CGPoint(
                    x: (size.width - stringSize.width) / 2,
                    y: (size.height - stringSize.height) / 2
                ),
                withAttributes: attributes
            )
        }
    }

    func modeLabel(_ mode: DayMode) -> String {
        switch mode {
        case .chill:
            return "Chill"
        case .cardio:
            return "Cardio"
        case .gym:
            return "Strength"
        case .cardioGym:
            return "Hybrid"
        }
    }

    func modePostLabel(_ mode: DayMode) -> String {
        switch mode {
        case .chill:
            return "Chill day"
        case .cardio:
            return "Cardio day"
        case .gym:
            return "Strength day"
        case .cardioGym:
            return "Hybrid day"
        }
    }

    func openGoalBreakdown(_ section: DailyGoalBreakdownSection) {
        selectedGoalBreakdownSection = section
        isShowingGoalBreakdown = true
    }

    func getStepsColor(steps: Double, target: Double) -> Color {
        let percent = min(max(steps / target, 0.0), 1.0)
        return Color(red: 1.0 - (0.5 * percent), green: 0.1, blue: percent)
    }

    func changeDate(by days: Int) {
        let calendar = Calendar.current
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: Date()))!
        if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate),
           newDate < dayAfterTomorrow {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedDate = newDate
        }
    }

    func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "MMM d"
            : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
