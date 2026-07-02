import SwiftUI
import SwiftData

struct ScanHistoryView: View {
    @Query(sort: \ScanRecord.scanDate, order: .reverse) private var scans: [ScanRecord]
    @State private var selectedScan: ScanRecord?

    var body: some View {
        Group {
            if scans.isEmpty {
                CIQEmptyState(
                    icon: "viewfinder",
                    title: "No Scan History",
                    message: "Cards you scan will appear here so you can revisit grade reports anytime."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(scans, id: \.scanId) { scan in
                        Button { selectedScan = scan } label: {
                            ScanHistoryRow(scan: scan)
                        }
                        .listRowBackground(CIQColors.Fallback.backgroundCard)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(CIQColors.Fallback.backgroundPrimary)
        .navigationTitle("Scan History")
        .ciqInlineTitle()
        .ciqNavigationBarStyle()
        .sheet(item: $selectedScan) { scan in
            if let card = scan.cardIdentity {
                NavigationStack {
                    if let report = scan.gradingReport, let market = scan.marketSnapshot {
                        GradeReportView(card: card, report: report, market: market, onDismiss: { selectedScan = nil })
                    } else {
                        // Front-only scan — no grading report; show the raw result.
                        RawValueResultView(card: card, market: scan.marketSnapshot, onDismiss: { selectedScan = nil })
                    }
                }
            }
        }
    }
}

struct ScanHistoryRow: View {
    let scan: ScanRecord

    var body: some View {
        HStack(spacing: CIQSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: CIQRadius.xs)
                    .fill(CIQColors.Fallback.backgroundTertiary)
                    .frame(width: 44, height: 60)
                if let grade = scan.gradingReport?.estimatedGrade {
                    Text(String(format: "%.1f", grade))
                        .font(CIQFont.footnoteBold)
                        .foregroundStyle(gradeColor(grade))
                } else {
                    Text("Raw")
                        .font(CIQFont.captionBold)
                        .foregroundStyle(CIQColors.Fallback.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: CIQSpacing.xxxs) {
                Text(scan.cardIdentity?.name ?? "Unknown Card")
                    .font(CIQFont.bodyBold)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                HStack(spacing: CIQSpacing.xs) {
                    Text(scan.cardIdentity?.setName ?? "")
                        .font(CIQFont.caption)
                        .foregroundStyle(CIQColors.Fallback.textSecondary)
                    if scan.savedToCollection {
                        CIQBadge(text: "Saved", color: CIQColors.Fallback.positive)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: CIQSpacing.xxxs) {
                Text(scan.scanDate, format: .dateTime.month(.abbreviated).day())
                    .font(CIQFont.caption)
                    .foregroundStyle(CIQColors.Fallback.textTertiary)
                if let market = scan.marketSnapshot {
                    Text(market.rawEstimatedValue.currencyFormatted)
                        .font(CIQFont.footnoteBold)
                        .foregroundStyle(CIQColors.Fallback.textPrimary)
                }
            }

            Image(systemName: "chevron.right")
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
        }
    }

    private func gradeColor(_ grade: Double) -> Color {
        switch grade {
        case 9.5...10: CIQColors.Fallback.accentPrimary
        case 8.5..<9.5: CIQColors.Fallback.positive
        case 7..<8.5: CIQColors.Fallback.warning
        default: CIQColors.Fallback.negative
        }
    }
}

#Preview {
    NavigationStack {
        ScanHistoryView()
    }
    .modelContainer(for: ScanRecord.self, inMemory: true)
}
