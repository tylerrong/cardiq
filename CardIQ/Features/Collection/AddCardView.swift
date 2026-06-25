import SwiftUI
import SwiftData

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var searchResults: [CardIdentity] = []
    @State private var selectedCard: CardIdentity?
    @State private var purchasePrice: Double?
    @State private var purchaseDate = Date()
    @State private var notes = ""
    @State private var quantity = 1

    private let service = MockCardIdentificationService()

    var body: some View {
        Form {
            Section("Find Card") {
                TextField("Search by name, set, or number...", text: $searchText)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { _, query in
                        Task {
                            if query.count >= 2 {
                                searchResults = (try? await service.search(query: query)) ?? []
                            } else if query.isEmpty {
                                searchResults = await service.allCards()
                            }
                        }
                    }

                if let card = selectedCard {
                    HStack(spacing: CIQSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(CIQColors.Fallback.positive)
                        VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                            Text(card.name)
                                .font(CIQFont.bodyBold)
                            Text("\(card.setName) · \(card.displayNumber)")
                                .font(CIQFont.caption)
                                .foregroundStyle(CIQColors.Fallback.textSecondary)
                        }
                        Spacer()
                        Button("Change") {
                            selectedCard = nil
                            searchResults = []
                            searchText = ""
                        }
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                    }
                }

                if selectedCard == nil {
                    ForEach(searchResults) { card in
                        Button {
                            selectedCard = card
                        } label: {
                            HStack(spacing: CIQSpacing.sm) {
                                VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                                    Text(card.name)
                                        .font(CIQFont.bodyBold)
                                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                                    Text("\(card.setName) · \(card.displayNumber) · \(card.rarity.displayName)")
                                        .font(CIQFont.caption)
                                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
                            }
                        }
                    }
                }
            }

            if selectedCard != nil {
                Section("Purchase Details (Optional)") {
                    HStack {
                        Text("Price Paid")
                        Spacer()
                        TextField("$0.00", value: $purchasePrice, format: .currency(code: "USD"))
                            .ciqDecimalKeyboard()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    DatePicker("Date Purchased", selection: $purchaseDate, displayedComponents: .date)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...100)
                }

                Section("Notes") {
                    TextField("Add notes about this card...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle("Add Card")
        .ciqInlineTitle()
        .ciqNavigationBarStyle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { saveCard() }
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)
                    .disabled(selectedCard == nil)
            }
        }
        .task {
            searchResults = await service.allCards()
        }
    }

    private func saveCard() {
        guard let card = selectedCard else { return }

        let item = CollectionItem(
            cardIdentity: card,
            purchasePrice: purchasePrice,
            purchaseDate: purchasePrice != nil ? purchaseDate : nil,
            quantity: quantity,
            notes: notes.isEmpty ? nil : notes
        )

        let market = MockSeedData.marketSnapshot(for: card.id)
        item.marketSnapshot = market

        let report = MockSeedData.gradingReport(for: card.id)
        item.gradingReport = report

        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

struct EditCollectionItemView: View {
    let item: CollectionItem
    @Environment(\.dismiss) private var dismiss
    @State private var purchasePrice: Double?
    @State private var purchaseDate: Date
    @State private var notes: String
    @State private var quantity: Int

    init(item: CollectionItem) {
        self.item = item
        self._purchasePrice = State(initialValue: item.purchasePrice)
        self._purchaseDate = State(initialValue: item.purchaseDate ?? Date())
        self._notes = State(initialValue: item.notes ?? "")
        self._quantity = State(initialValue: item.quantity)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Purchase Details") {
                    HStack {
                        Text("Price Paid")
                        Spacer()
                        TextField("$0.00", value: $purchasePrice, format: .currency(code: "USD"))
                            .ciqDecimalKeyboard()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    DatePicker("Date Purchased", selection: $purchaseDate, displayedComponents: .date)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...100)
                }

                Section("Notes") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Edit Card")
            .ciqInlineTitle()
            .ciqNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(CIQColors.Fallback.accentPrimary)
                }
            }
        }
    }

    private func save() {
        item.purchasePrice = purchasePrice
        item.purchaseDate = purchasePrice != nil ? purchaseDate : nil
        item.notes = notes.isEmpty ? nil : notes
        item.quantity = quantity
        dismiss()
    }
}

#Preview("Add Card") {
    NavigationStack {
        AddCardView()
    }
    .modelContainer(for: CollectionItem.self, inMemory: true)
}
