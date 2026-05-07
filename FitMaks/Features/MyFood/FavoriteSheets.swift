import SwiftUI

struct FavoriteAmountSheet: View {
    let favorite: FavoriteFood
    let selectedDate: Date
    let onAdd: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customAmount: Double

    init(favorite: FavoriteFood, selectedDate: Date, onAdd: @escaping (Double) -> Void) {
        self.favorite = favorite
        self.selectedDate = selectedDate
        self.onAdd = onAdd

        switch favorite.portionBasis {
        case .per100g:
            _customAmount = State(initialValue: 100)
        default:
            _customAmount = State(initialValue: 1)
        }
    }

    private var previewMultiplier: Double {
        switch favorite.portionBasis {
        case .per100g:
            return customAmount / 100
        case .perServing, .perPack, .perPiece:
            return customAmount
        }
    }

    private var manualStep: Double {
        favorite.portionBasis == .perPiece ? 1 : (favorite.portionBasis == .per100g ? 10 : 0.5)
    }

    private var manualRange: ClosedRange<Double> {
        switch favorite.portionBasis {
        case .per100g:
            return 10...1000
        case .perPiece:
            return 1...12
        case .perServing, .perPack:
            return 0.5...6
        }
    }

    private var amountTitle: String {
        switch favorite.portionBasis {
        case .per100g:
            return "How many grams did you have?"
        case .perServing:
            return "How many servings did you have?"
        case .perPack:
            return "How much of the pack did you have?"
        case .perPiece:
            return "How many pieces did you have?"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(favorite.name)
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text(amountTitle)
                        .font(.subheadline)
                        .foregroundColor(.appMuted)
                    Text(favorite.basisDisplayText)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.neonCyan)
                }

                HStack(spacing: 10) {
                    ForEach(favorite.quickAddPresets) { preset in
                        let isDefault = preset.amount == customAmount
                        Button {
                            onAdd(preset.amount)
                        } label: {
                            Text(preset.label)
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(isDefault ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isDefault ? Color.neonCyan : Color.white.opacity(0.06))
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDefault ? Color.neonCyan.opacity(0.5) : Color.neonCyan.opacity(0.18), lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CUSTOM")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundColor(.appMuted)
                            .tracking(0.5)
                        Spacer()
                        Text(FavoritePortionRules.amountLabel(for: favorite, amount: customAmount))
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.neonGreen)
                    }

                    Slider(value: $customAmount, in: manualRange, step: manualStep)
                        .tint(.neonCyan)

                    HStack(spacing: 10) {
                        Label("\(Int((favorite.calories * previewMultiplier).rounded()))", systemImage: "flame.fill")
                            .foregroundColor(.neonGreen)
                        Label("\(Int((favorite.protein * previewMultiplier).rounded()))g", systemImage: "drop.fill")
                            .foregroundColor(.neonCyan)
                        Label("\(Int((favorite.carbs * previewMultiplier).rounded()))g", systemImage: "leaf.fill")
                            .foregroundColor(.fitOrange)
                        Label("\(Int((favorite.fat * previewMultiplier).rounded()))g", systemImage: "circle.inset.filled")
                            .foregroundColor(.yellow)
                    }
                    .font(.system(size: 10, weight: .heavy))
                    .lineLimit(1)
                    .fixedSize()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.055))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.neonCyan.opacity(0.14), lineWidth: 1))
                )

                Spacer()

                Button {
                    onAdd(customAmount)
                } label: {
                    Text("Add to \(DateFormatter.shortDate.string(from: selectedDate))")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(Color.neonGreen))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.neonCyan)
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }
}

struct FavoritePortionSettingsSheet: View {
    @Bindable var favorite: FavoriteFood
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBasis: FavoritePortionBasis

    init(favorite: FavoriteFood) {
        self.favorite = favorite
        _selectedBasis = State(initialValue: favorite.portionBasis)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(favorite.name)
                    .font(.title3)
                    .fontWeight(.black)
                    .foregroundColor(.white)

                Text("Choose how FitMaks should count this product in Fridge.")
                    .font(.subheadline)
                    .foregroundColor(.appMuted)

                VStack(spacing: 10) {
                    ForEach(FavoritePortionBasis.allCases, id: \.rawValue) { basis in
                        Button {
                            selectedBasis = basis
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(basis.title)
                                        .font(.system(size: 15, weight: .black))
                                        .foregroundColor(.white)
                                    Text(basisDescription(for: basis))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.appMuted)
                                }
                                Spacer()
                                Image(systemName: selectedBasis == basis ? "checkmark.circle.fill" : "circle")
                                    .font(.title3.bold())
                                    .foregroundColor(selectedBasis == basis ? .neonGreen : .white.opacity(0.4))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedBasis == basis ? Color.neonGreen.opacity(0.22) : Color.white.opacity(0.08), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button {
                    favorite.updatePortionBasis(selectedBasis)
                    dismiss()
                } label: {
                    Text("Save Basis")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(Color.neonGreen))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.neonCyan)
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private func basisDescription(for basis: FavoritePortionBasis) -> String {
        switch basis {
        case .per100g:
            return "Best for mince, bread, rice, oats, pasta, raw staples."
        case .perServing:
            return "Best for cooked dishes or foods you eat by portion."
        case .perPack:
            return "Best for yogurt cups, bars, drinks, and packaged products."
        case .perPiece:
            return "Best for eggs, bananas, slices, or single units."
        }
    }
}
