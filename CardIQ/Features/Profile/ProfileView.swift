import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showPaywall = false
    @State private var showDeleteConfirmation = false
    @State private var exportFile: CIQExportFile?

    var body: some View {
        NavigationStack {
            List {
                accountSection
                subscriptionSection
                gradingDefaultsSection
                preferencesSection
                supportSection
                dangerSection
                aboutSection
                // Clearance so the floating tab bar / Ask CardIQ button never
                // covers the last rows.
                Section {
                    Color.clear.frame(height: 72)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CIQColors.Fallback.backgroundPrimary)
            .navigationTitle("Profile")
            .ciqNavigationBarStyle()
            .task { await appState.refreshSubscription() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) { Task { await appState.deleteAccount() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all collection data. This cannot be undone.")
            }
        }
    }

    private var accountSection: some View {
        Section {
            HStack(spacing: CIQSpacing.md) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(CIQColors.Fallback.accentPrimary)

                VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                    Text(appState.currentUser.name)
                        .font(CIQFont.headline)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                    if !appState.currentUser.email.isEmpty {
                        Text(appState.currentUser.email)
                            .font(CIQFont.caption)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Text(appState.currentUser.subscriptionTier.displayName)
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }
            }
        }
        .listRowBackground(CIQColors.Fallback.backgroundCard)
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            HStack {
                Text("Plan")
                Spacer()
                Text(appState.currentUser.subscriptionTier.displayName)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
            HStack {
                Text("Scans Remaining")
                Spacer()
                Text("\(appState.currentUser.freeScansRemaining)")
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
            Button("Upgrade to Pro") { showPaywall = true }
                .foregroundStyle(CIQColors.Fallback.accentPrimary)
        }
        .listRowBackground(CIQColors.Fallback.backgroundCard)
    }

    private var gradingDefaultsSection: some View {
        @Bindable var state = appState
        return Section("Grading Defaults") {
            Picker("Grading Company", selection: $state.preferredGradingCompany) {
                Text("PSA").tag("PSA")
                Text("CGC").tag("CGC")
                Text("BGS").tag("BGS")
            }
            HStack {
                Text("Grading Fee")
                Spacer()
                TextField("", value: $state.defaultGradingFee, format: .currency(code: "USD"))
                    .ciqDecimalKeyboard()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            HStack {
                Text("Shipping Cost")
                Spacer()
                TextField("", value: $state.defaultShippingCost, format: .currency(code: "USD"))
                    .ciqDecimalKeyboard()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            HStack {
                Text("Selling Fee %")
                Spacer()
                TextField("", value: $state.defaultSellingFee, format: .number)
                    .ciqDecimalKeyboard()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("%")
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
        }
        .listRowBackground(CIQColors.Fallback.backgroundCard)
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            NavigationLink("Notification Preferences") {
                NotificationSettingsView()
            }
            NavigationLink("Privacy Settings") {
                PrivacySettingsView()
            }
            Button("Export Collection (CSV)") {
                exportCollection()
            }
            .foregroundStyle(CIQColors.Fallback.accentPrimary)
        }
        .listRowBackground(CIQColors.Fallback.backgroundCard)
        .fileExporter(
            isPresented: .init(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
            document: exportFile,
            contentType: .commaSeparatedText,
            defaultFilename: "CardIQ_Collection.csv"
        ) { _ in }
    }

    private var supportSection: some View {
        Section("Support") {
            NavigationLink("Help & Feedback") {
                HelpFeedbackView()
            }
        }
        .listRowBackground(CIQColors.Fallback.backgroundCard)
    }

    private var dangerSection: some View {
        Section {
            if appState.requiresAuthentication {
                Button("Sign Out") { Task { await appState.signOut() } }
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
            Button("Delete Account") { showDeleteConfirmation = true }
                .foregroundStyle(CIQColors.Fallback.negative)
            #if DEBUG
            Button("Reset Onboarding") {
                appState.resetOnboarding()
            }
            .foregroundStyle(CIQColors.Fallback.warning)
            #endif
        }
        .listRowBackground(CIQColors.Fallback.backgroundCard)
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0 (1)")
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
        }
        .listRowBackground(CIQColors.Fallback.backgroundCard)
    }

    private func exportCollection() {
        let descriptor = FetchDescriptor<CollectionItem>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        guard let items = try? modelContext.fetch(descriptor), !items.isEmpty else { return }

        var csv = "Name,Set,Number,Rarity,Purchase Price,Current Value,P&L,Official Grade,Grading Company,Date Added\n"
        for item in items {
            let card = item.cardIdentity
            let name = card?.name ?? "Unknown"
            let set = card?.setName ?? ""
            let num = card?.displayNumber ?? ""
            let rarity = card?.rarity.displayName ?? ""
            let purchase = item.purchasePrice.map { String(format: "%.2f", $0) } ?? ""
            let value = String(format: "%.2f", item.currentValue)
            let pl = String(format: "%.2f", item.gainLoss)
            let grade = item.officialGrade.map { String(format: "%.0f", $0) } ?? ""
            let company = item.officialGradingCompany ?? ""
            let date = item.dateAdded.formatted(.dateTime.year().month().day())
            csv += "\"\(name)\",\"\(set)\",\"\(num)\",\"\(rarity)\",\(purchase),\(value),\(pl),\(grade),\"\(company)\",\(date)\n"
        }

        exportFile = CIQExportFile(csv: csv)
    }
}

struct CIQExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let csv: String

    init(csv: String) { self.csv = csv }
    init(configuration: ReadConfiguration) throws {
        csv = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(csv.utf8))
    }
}

struct NotificationSettingsView: View {
    @AppStorage("notifyPriceAlerts") private var priceAlerts = true
    @AppStorage("notifyGradingUpdates") private var gradingUpdates = true
    @AppStorage("notifyMarketNews") private var marketNews = false

    var body: some View {
        List {
            Section("Price Alerts") {
                Toggle("Watchlist price changes", isOn: $priceAlerts)
                    .tint(CIQColors.Fallback.accentPrimary)
            }
            .listRowBackground(CIQColors.Fallback.backgroundCard)
            Section("Card Updates") {
                Toggle("Grading recommendations", isOn: $gradingUpdates)
                    .tint(CIQColors.Fallback.accentPrimary)
                Toggle("Market news & trends", isOn: $marketNews)
                    .tint(CIQColors.Fallback.accentPrimary)
            }
            .listRowBackground(CIQColors.Fallback.backgroundCard)
        }
        .scrollContentBackground(.hidden)
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle("Notifications")
        .ciqInlineTitle()
        .ciqNavigationBarStyle()
    }
}

struct PrivacySettingsView: View {
    @AppStorage("privacyAnalyticsEnabled") private var analyticsEnabled = false
    @AppStorage("privacyImageRetention") private var imageRetention = true

    var body: some View {
        List {
            Section("Analytics") {
                Toggle("Share anonymous usage data", isOn: $analyticsEnabled)
                    .tint(CIQColors.Fallback.accentPrimary)
                Text("Help improve CardIQ by sharing anonymous usage statistics. No personal data or card images are shared.")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
            .listRowBackground(CIQColors.Fallback.backgroundCard)
            Section("Data") {
                Toggle("Keep scanned images locally", isOn: $imageRetention)
                    .tint(CIQColors.Fallback.accentPrimary)
                Text("Scanned card images are stored only on this device and are never uploaded without your consent.")
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
            }
            .listRowBackground(CIQColors.Fallback.backgroundCard)
        }
        .scrollContentBackground(.hidden)
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle("Privacy")
        .ciqInlineTitle()
        .ciqNavigationBarStyle()
    }
}

struct HelpFeedbackView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CIQSpacing.lg) {
                CIQCard {
                    VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                        Label("How Grading Estimates Work", systemImage: "sparkles")
                            .font(CIQFont.headline)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                        Text("CardIQ uses AI to analyze card images for centering, corners, edges, and surface quality. Estimates are based on visual analysis and are not official grades. Always verify with a professional grading service before making buying or selling decisions.")
                            .font(CIQFont.subheadline)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                    }
                }

                CIQCard {
                    VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                        Label("Tips for Best Results", systemImage: "lightbulb")
                            .font(CIQFont.headline)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                        VStack(alignment: .leading, spacing: CIQSpacing.xs) {
                            tipRow("Use bright, even lighting")
                            tipRow("Remove the card from its sleeve")
                            tipRow("Place on a dark, non-reflective surface")
                            tipRow("Hold the phone steady and fill the frame")
                            tipRow("Avoid shadows and glare")
                        }
                    }
                }

                CIQCard {
                    VStack(alignment: .leading, spacing: CIQSpacing.sm) {
                        Label("Contact Us", systemImage: "envelope")
                            .font(CIQFont.headline)
                            .foregroundStyle(CIQColors.Fallback.textPrimary)
                        Text("Have feedback or need help? Reach out at support@cardiq.app")
                            .font(CIQFont.subheadline)
                            .foregroundStyle(CIQColors.Fallback.textSecondary)
                    }
                }
            }
            .padding(CIQSpacing.md)
        }
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle("Help & Feedback")
        .ciqInlineTitle()
        .ciqNavigationBarStyle()
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CIQSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.accentPrimary)
            Text(text)
                .font(CIQFont.subheadline)
                .foregroundStyle(CIQColors.Fallback.textSecondary)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
        .modelContainer(for: CollectionItem.self, inMemory: true)
}
