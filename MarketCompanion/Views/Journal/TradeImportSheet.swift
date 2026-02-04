// TradeImportSheet.swift
// MarketCompanion
//
// Step-by-step CSV import wizard for broker trades.

import SwiftUI
import UniformTypeIdentifiers

struct TradeImportSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var step = 1
    @State private var selectedFormat: BrokerFormat = .generic
    @State private var importedTrades: [ImportedTrade] = []
    @State private var importError: String?
    @State private var importCount = 0
    @State private var selectedFileURL: URL?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            HStack {
                Text("Import Trades")
                    .font(AppFont.title())
                Spacer()
                Text("Step \(step) of 3")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
            }

            if step == 1 {
                stepOne
            } else if step == 2 {
                stepTwo
            } else {
                stepThree
            }
        }
        .padding(Spacing.xl)
        .frame(width: 600, height: 500)
    }

    // MARK: - Step 1: File & Format Selection

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Select your broker and CSV file")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)

            Picker("Broker Format", selection: $selectedFormat) {
                ForEach(BrokerFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .frame(width: 250)

            HStack(spacing: Spacing.sm) {
                Button {
                    openFilePanel()
                } label: {
                    Label("Choose CSV File", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)

                if let url = selectedFileURL {
                    Text(url.lastPathComponent)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }

            if let error = importError {
                Text(error)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.lossRed)
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Next") {
                    parseFile()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedFileURL == nil)
            }
        }
    }

    // MARK: - Step 2: Preview & Select

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Review imported trades")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)

            let duplicates = importedTrades.filter(\.isDuplicate).count
            if duplicates > 0 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.warningAmber)
                    Text("\(duplicates) potential duplicate(s) detected (highlighted)")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.warningAmber)
                }
            }

            ScrollView {
                VStack(spacing: 2) {
                    // Header
                    HStack {
                        Text("").frame(width: 24)
                        Text("Symbol").font(AppFont.caption()).frame(width: 60, alignment: .leading)
                        Text("Side").font(AppFont.caption()).frame(width: 50, alignment: .leading)
                        Text("Qty").font(AppFont.caption()).frame(width: 60, alignment: .trailing)
                        Text("Price").font(AppFont.caption()).frame(width: 80, alignment: .trailing)
                        Text("Date").font(AppFont.caption()).frame(minWidth: 120, alignment: .leading)
                    }
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, Spacing.xs)

                    Divider()

                    ForEach(importedTrades.indices, id: \.self) { i in
                        HStack {
                            Toggle("", isOn: $importedTrades[i].isSelected)
                                .toggleStyle(.checkbox)
                                .frame(width: 24)
                            Text(importedTrades[i].symbol)
                                .font(AppFont.mono())
                                .frame(width: 60, alignment: .leading)
                            Text(importedTrades[i].side.rawValue)
                                .font(AppFont.caption())
                                .frame(width: 50, alignment: .leading)
                            Text(String(format: "%.0f", importedTrades[i].qty))
                                .font(AppFont.mono())
                                .frame(width: 60, alignment: .trailing)
                            Text(FormatHelper.price(importedTrades[i].price))
                                .font(AppFont.mono())
                                .frame(width: 80, alignment: .trailing)
                            Text(FormatHelper.fullDate(importedTrades[i].date))
                                .font(AppFont.caption())
                                .frame(minWidth: 120, alignment: .leading)
                        }
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(importedTrades[i].isDuplicate ? Color.warningAmber.opacity(0.15) : Color.clear)
                    }
                }
            }
            .frame(maxHeight: 280)

            Spacer()

            HStack {
                Button("Back") { step = 1 }
                Spacer()
                Button("Import Selected") {
                    doImport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(importedTrades.filter({ $0.isSelected && !$0.isDuplicate }).isEmpty)
            }
        }
    }

    // MARK: - Step 3: Confirmation

    private var stepThree: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.gainGreen)

            Text("Import Complete")
                .font(AppFont.title())

            let skipped = importedTrades.filter(\.isDuplicate).count
            Text("\(importCount) trades imported\(skipped > 0 ? " (\(skipped) duplicates skipped)" : "")")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)

            Spacer()

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Actions

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                selectedFileURL = url
                importError = nil
            }
        }
    }

    private func parseFile() {
        guard let url = selectedFileURL else { return }

        do {
            importedTrades = try TradeImporter.parseCSV(url: url, format: selectedFormat)
            if importedTrades.isEmpty {
                importError = "No trades found in file. Check the broker format selection."
                return
            }
            TradeImporter.detectDuplicates(imported: &importedTrades, existing: appState.trades)
            step = 2
        } catch {
            importError = error.localizedDescription
        }
    }

    private func doImport() {
        do {
            importCount = try TradeImporter.importTrades(importedTrades, into: appState.tradeRepo)
            appState.loadFromDatabase()
            step = 3
        } catch {
            importError = error.localizedDescription
        }
    }
}
