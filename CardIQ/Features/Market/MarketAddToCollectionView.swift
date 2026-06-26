import SwiftUI
import SwiftData

struct MarketAddToCollectionView: View {
    let card: CardIdentity
    let market: MarketSnapshot?
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var purchasePrice: Double?
    @State private var purchaseDate = Date()
    @State private var notes = ""

    var body: some View {
        Form {
            Section {
                HStack(spacing: CIQSpacing.sm) {
                    CardArtworkView(card: card, size: .small)
                    VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                        Text(card.name)
                            .font(CIQFont.bodyBold)
                        Text("\(card.setName) · \(card.displayNumber)")
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                    }
                    Spacer()
                    if let market {
                        Text(market.rawEstimatedValue.currencyFormatted)
                            .font(CIQFont.bodyBold)
                            .foregroundStyle(CIQColors.Fallback.accentPrimary)
                    }
                }
            }

            Section("Purchase Details (Optional)") {
                HStack {
                    Text("Price Paid")
                    Spacer()
                    TextField("$0.00", value: $purchasePrice, format: .currency(code: "USD"))
                        .ciqDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                DatePicker("Date", selection: $purchaseDate, displayedComponents: .date)
            }

            Section("Notes") {
                TextField("Optional notes...", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle("Add to Collection")
        .ciqInlineTitle()
        .ciqNavigationBarStyle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { save() }
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
            }
        }
    }

    private func save() {
        let item = CollectionItem(
            cardIdentity: card,
            purchasePrice: purchasePrice,
            purchaseDate: purchasePrice != nil ? purchaseDate : nil,
            notes: notes.isEmpty ? nil : notes
        )
        if let market {
            item.marketSnapshot = market
        }
        let report = MockSeedData.gradingReport(for: card.id)
        item.gradingReport = report

        modelContext.insert(item)
        try? modelContext.save()
        onSaved()
        dismiss()
    }
}
