// ReportsView.swift
// MarketCompanion

import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedReport: Report?
    @State private var filterType: ReportType?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top) {
                    PageHeader(title: "Reports", subtitle: "Morning & close briefings")
                    Spacer()
                    HStack(spacing: Spacing.xs) {
                        Picker("Mode", selection: $appState.reportMode) {
                            ForEach(ReportMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 160)
                        .help("Concise shows top 3 items per section. Detailed includes rotation analysis and key levels.")

                        Button {
                            Task { await appState.generateMorningReport() }
                        } label: {
                            Label("Morning", systemImage: "sunrise.fill")
                                .font(AppFont.subheadline())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(appState.isGeneratingReport)
                        .help("Generate a morning briefing for today")

                        Button {
                            Task { await appState.generateCloseReport() }
                        } label: {
                            Label("Close", systemImage: "sunset.fill")
                                .font(AppFont.subheadline())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(appState.isGeneratingReport)
                        .help("Generate an end-of-day close summary")
                    }
                }

                // Generation progress
                if appState.isGeneratingReport {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating report...")
                            .font(AppFont.subheadline())
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                            .fill(Color.accentColor.opacity(0.08))
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: appState.isGeneratingReport)
                }

                // Filter
                HStack(spacing: Spacing.sm) {
                    filterButton("All", active: filterType == nil) { filterType = nil }
                    filterButton("Morning", active: filterType == .morning) { filterType = .morning }
                    filterButton("Close", active: filterType == .close) { filterType = .close }
                }

                if filteredReports.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Reports Yet",
                        message: "Reports generate automatically at 6:30 AM and 1:00 PM PT, or manually with the buttons above.",
                        actionTitle: nil
                    )
                    .frame(height: 300)
                } else if let selected = selectedReport {
                    reportDetail(selected)
                } else {
                    reportList
                }
            }
            .padding(Spacing.lg)
        }
    }

    private var filteredReports: [Report] {
        if let filterType {
            return appState.reports.filter { $0.type == filterType }
        }
        return appState.reports
    }

    private func filterButton(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.subheadline())
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background {
                    RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                        .fill(active ? Color.accentColor : Color.clear)
                }
                .foregroundStyle(active ? .white : Color.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var reportList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(filteredReports) { report in
                Button {
                    selectedReport = report
                } label: {
                    CardView(padding: Spacing.sm) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: report.type == .morning ? "sunrise.fill" : "sunset.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(report.type == .morning ? Color.warningAmber : Color.infoBlue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(report.type == .morning ? "Morning Briefing" : "Close Summary")
                                    .font(AppFont.subheadline())
                                    .foregroundStyle(Color.textPrimary)
                                Text(FormatHelper.fullDate(report.createdAt))
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textTertiary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reportDetail(_ report: Report) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Back button
            Button {
                selectedReport = nil
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "chevron.left")
                    Text("All Reports")
                }
                .font(AppFont.subheadline())
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            // Report header
            HStack {
                TagPill(
                    text: report.type == .morning ? "Morning" : "Close",
                    color: report.type == .morning ? .warningAmber : .infoBlue,
                    style: .filled
                )
                Text(FormatHelper.fullDate(report.createdAt))
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                Button {
                    appState.audioBriefing.toggle(report.renderedMarkdown)
                } label: {
                    Label(
                        appState.audioBriefing.isSpeaking ? "Stop" : "Read Aloud",
                        systemImage: appState.audioBriefing.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                    )
                    .font(AppFont.subheadline())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Read this report aloud using macOS text-to-speech")

                Button {
                    copyReport(report)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(AppFont.subheadline())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copy the report as markdown text to the clipboard")

                Button {
                    exportPDF(report)
                } label: {
                    Label("PDF", systemImage: "arrow.down.doc")
                        .font(AppFont.subheadline())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Export this report as a formatted PDF file")
            }

            SubtleDivider()

            // Report content
            if report.renderedMarkdown.isEmpty {
                CardView {
                    Text("Report content will appear here.")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                CardView {
                    MarkdownView(markdown: report.renderedMarkdown)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func copyReport(_ report: Report) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report.renderedMarkdown, forType: .string)
    }

    private func exportPDF(_ report: Report) {
        // PDF export will be implemented in step 11
        let content = report.renderedMarkdown
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(report.type.rawValue)_report_\(FormatHelper.shortDate(report.createdAt)).pdf"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Basic text-to-PDF
                let pdfData = createPDF(from: content)
                try? pdfData.write(to: url)
            }
        }
    }

    private func createPDF(from text: String) -> Data {
        let pdfMetaData: [CFString: Any] = [
            kCGPDFContextTitle: "Market Companion Report" as CFString,
            kCGPDFContextAuthor: "Market Companion" as CFString
        ]

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let textWidth = pageWidth - margin * 2
        let textHeight = pageHeight - margin * 2

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfMetaData as CFDictionary) else {
            return Data()
        }

        let attributedString = buildAttributedString(from: text)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let totalLength = attributedString.length
        var charIndex = 0

        // Render pages until all text is drawn
        while charIndex < totalLength {
            context.beginPDFPage(nil)

            let textRect = CGRect(x: margin, y: margin, width: textWidth, height: textHeight)
            let path = CGPath(rect: textRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(charIndex, 0), path, nil)

            context.saveGState()
            context.translateBy(x: 0, y: pageHeight)
            context.scaleBy(x: 1, y: -1)
            CTFrameDraw(frame, context)
            context.restoreGState()

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            charIndex += visibleRange.length

            // Safety: if no characters were drawn, break to avoid infinite loop
            if visibleRange.length == 0 { break }

            context.endPDFPage()
        }

        context.closePDF()
        return pdfData as Data
    }

    private func buildAttributedString(from markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: 11)
        let headingFont = NSFont.boldSystemFont(ofSize: 16)
        let subheadingFont = NSFont.boldSystemFont(ofSize: 13)
        let bodyColor = NSColor.textColor
        let dimColor = NSColor.secondaryLabelColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        paragraphStyle.paragraphSpacing = 6

        let lines = markdown.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: headingFont,
                    .foregroundColor: bodyColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: text + "\n\n", attributes: attrs))
            } else if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: subheadingFont,
                    .foregroundColor: bodyColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: "\n" + text + "\n", attributes: attrs))
            } else if trimmed.hasPrefix("### ") {
                let text = String(trimmed.dropFirst(4))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: bodyColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: text + "\n", attributes: attrs))
            } else if trimmed.hasPrefix("> ") {
                let text = String(trimmed.dropFirst(2))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont(descriptor: bodyFont.fontDescriptor.withSymbolicTraits(.italic), size: 11) ?? bodyFont,
                    .foregroundColor: dimColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: text + "\n", attributes: attrs))
            } else if trimmed.hasPrefix("|") && !trimmed.contains("---") {
                // Table row — render as plain text
                let cells = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let rowText = cells.joined(separator: "  |  ")
                let monoFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: monoFont,
                    .foregroundColor: bodyColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: rowText + "\n", attributes: attrs))
            } else if trimmed.hasPrefix("---") {
                result.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont]))
            } else if trimmed.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont]))
            } else {
                // Strip bold/italic markdown for plain text
                let clean = trimmed
                    .replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
                    .replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: bodyColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: clean + "\n", attributes: attrs))
            }
        }

        return result
    }
}
