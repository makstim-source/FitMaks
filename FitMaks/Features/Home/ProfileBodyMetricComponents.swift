import SwiftUI

struct MetricStepperCard: View {
    var title: String
    @Binding var value: Double
    var unit: String
    var range: ClosedRange<Double>
    var step: Double
    var decimals: Int
    var accentColor: Color

    private var formattedValue: String {
        decimals == 0
            ? "\(Int(value.rounded()))"
            : String(format: "%.\(decimals)f", value)
    }

    private var progress: Double {
        min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.appMuted)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(formattedValue)
                            .font(.system(size: 31, weight: .black))
                            .foregroundColor(.appText)

                        Text(unit)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.appMuted)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    stepButton(systemName: "minus") {
                        value = max(range.lowerBound, value - step)
                    }

                    stepButton(systemName: "plus") {
                        value = min(range.upperBound, value + step)
                    }
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appText.opacity(0.08))

                    Capsule()
                        .fill(accentColor)
                        .frame(width: proxy.size.width * CGFloat(progress))
                        .shadow(color: accentColor.opacity(0.45), radius: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.appAccentText)
                .frame(width: 42, height: 42)
                .background(Circle().fill(accentColor))
                .shadow(color: accentColor.opacity(0.35), radius: 8)
        }
        .buttonRepeatBehavior(.enabled)
    }
}
