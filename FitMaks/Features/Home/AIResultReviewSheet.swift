import SwiftUI

struct AIResultReviewSheet: View {
    let review: AIResultReview
    var onCancel: () -> Void
    var onRecalculate: () -> Void
    var onConfirm: ([AIReviewFoodItem]) -> Void

    @State private var items: [AIReviewFoodItem]

    init(
        review: AIResultReview,
        onCancel: @escaping () -> Void,
        onRecalculate: @escaping () -> Void,
        onConfirm: @escaping ([AIReviewFoodItem]) -> Void
    ) {
        self.review = review
        self.onCancel = onCancel
        self.onRecalculate = onRecalculate
        self.onConfirm = onConfirm
        _items = State(initialValue: review.items)
    }

    private var selectedItems: [AIReviewFoodItem] {
        items.filter { $0.isSelected }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach($items) { $item in
                            reviewRow(item: $item)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                }

                footer
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("AI CHECKPOINT")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.neonGreen)
                        .tracking(1.4)

                    Text(review.title)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.appText)
                }

                Spacer()

                Button("Cancel", action: onCancel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appMuted)
            }

            Text(review.subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private func reviewRow(item: Binding<AIReviewFoodItem>) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    item.wrappedValue.isSelected.toggle()
                }
            } label: {
                Image(systemName: item.wrappedValue.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .black))
                    .foregroundColor(item.wrappedValue.isSelected ? .neonGreen : .appMuted)
            }

            Image(uiImage: item.wrappedValue.image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 10) {
                TextField("Food name", text: item.name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.appText)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    metricField(title: "kcal", value: item.calories, color: .neonGreen)
                    metricField(title: "protein", value: item.protein, color: .neonCyan)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(item.wrappedValue.isSelected ? Color.appElevated : Color.appSurface.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(item.wrappedValue.isSelected ? Color.neonGreen.opacity(0.24) : Color.appBorder, lineWidth: 1)
        )
    }

    private func metricField(title: String, value: Binding<Double>, color: Color) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(color)
                .frame(width: 58)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.appMuted)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.appSurface))
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: onRecalculate) {
                Label("Recalculate fresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.neonCyan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Capsule().fill(Color.neonCyan.opacity(0.12)))
            }

            Button {
                onConfirm(selectedItems)
            } label: {
                Text(selectedItems.isEmpty ? "Select at least one item" : review.actionTitle)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.appAccentText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(selectedItems.isEmpty ? Color.gray.opacity(0.35) : Color.neonGreen))
                    .shadow(color: Color.neonGreen.opacity(selectedItems.isEmpty ? 0 : 0.35), radius: 18, x: 0, y: 8)
            }
            .disabled(selectedItems.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .background(Color.appElevated.opacity(0.86).ignoresSafeArea(edges: .bottom))
    }
}
