// MarkdownView.swift
// MarketCompanion
//
// Renders markdown text as styled SwiftUI views.
// Supports: headers, bold, italic, blockquotes, tables, lists, horizontal rules.

import SwiftUI

struct MarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Array(parseBlocks(markdown).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: - Block Types

    private enum Block {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case blockquote(text: String)
        case listItem(text: String)
        case tableBlock(headers: [String], rows: [[String]])
        case horizontalRule
        case empty
    }

    // MARK: - Block Views

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .paragraph(let text):
            inlineText(text)
                .font(AppFont.body())
                .foregroundStyle(Color.textPrimary)
        case .blockquote(let text):
            blockquoteView(text)
        case .listItem(let text):
            listItemView(text)
        case .tableBlock(let headers, let rows):
            tableView(headers: headers, rows: rows)
        case .horizontalRule:
            SubtleDivider()
                .padding(.vertical, Spacing.xxs)
        case .empty:
            EmptyView()
        }
    }

    // MARK: - Heading

    private func headingView(level: Int, text: String) -> some View {
        let font: Font
        let padding: CGFloat
        switch level {
        case 1:
            font = AppFont.largeTitle()
            padding = Spacing.sm
        case 2:
            font = AppFont.title()
            padding = Spacing.xs
        case 3:
            font = AppFont.headline()
            padding = Spacing.xxs
        default:
            font = AppFont.subheadline()
            padding = 0
        }

        return inlineText(text)
            .font(font)
            .foregroundStyle(Color.textPrimary)
            .padding(.top, padding)
            .padding(.bottom, 2)
    }

    // MARK: - Blockquote

    private func blockquoteView(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor.opacity(0.6))
                .frame(width: 3)

            inlineText(text)
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
                .italic()
        }
        .padding(.vertical, Spacing.xxs)
    }

    // MARK: - List Item

    private func listItemView(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text("\u{2022}")
                .font(AppFont.body())
                .foregroundStyle(Color.textTertiary)
            inlineText(text)
                .font(AppFont.body())
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.leading, Spacing.sm)
    }

    // MARK: - Table

    private func tableView(headers: [String], rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { idx, header in
                    inlineText(header)
                        .font(AppFont.caption())
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: idx == 0 ? .leading : .trailing)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                }
            }
            .background(Color.surfaceElevated)

            SubtleDivider()

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                        inlineText(cell)
                            .font(AppFont.monoSmall())
                            .foregroundStyle(cellColor(cell))
                            .frame(maxWidth: .infinity, alignment: colIdx == 0 ? .leading : .trailing)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 3)
                    }
                }
                .background(rowIdx % 2 == 0 ? Color.clear : Color.surfaceElevated.opacity(0.4))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .strokeBorder(Color.borderSubtle.opacity(0.4), lineWidth: 0.5)
        }
        .padding(.vertical, Spacing.xxs)
    }

    private func cellColor(_ text: String) -> Color {
        // Color positive/negative values
        if text.contains("+") && (text.contains("%") || text.contains("$")) {
            return .gainGreen
        }
        if text.hasPrefix("-") && (text.contains("%") || text.contains("$")) {
            return .lossRed
        }
        if text.contains("Risk-On") { return .gainGreen }
        if text.contains("Risk-Off") { return .lossRed }
        return .textPrimary
    }

    // MARK: - Inline Text (bold, italic, code)

    private func inlineText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text

        while !remaining.isEmpty {
            // Bold: **text**
            if let boldRange = remaining.range(of: "\\*\\*(.+?)\\*\\*", options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<boldRange.lowerBound])
                let match = String(remaining[boldRange])
                let inner = String(match.dropFirst(2).dropLast(2))

                if !before.isEmpty {
                    result = result + Text(before)
                }
                result = result + Text(inner).bold()
                remaining = String(remaining[boldRange.upperBound...])
                continue
            }

            // Italic: _text_
            if let italicRange = remaining.range(of: "_(.+?)_", options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<italicRange.lowerBound])
                let match = String(remaining[italicRange])
                let inner = String(match.dropFirst(1).dropLast(1))

                if !before.isEmpty {
                    result = result + Text(before)
                }
                result = result + Text(inner).italic().foregroundColor(.textSecondary)
                remaining = String(remaining[italicRange.upperBound...])
                continue
            }

            // No more formatting found
            result = result + Text(remaining)
            break
        }

        return result
    }

    // MARK: - Parser

    private func parseBlocks(_ markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [Block] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // Heading
            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: min(level, 4), text: text))
                i += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                let text = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                blocks.append(.blockquote(text: text))
                i += 1
                continue
            }

            // List item
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2))
                blocks.append(.listItem(text: text))
                i += 1
                continue
            }

            // Table: detect by looking for | characters and separator line
            if trimmed.hasPrefix("|") && i + 1 < lines.count {
                let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if nextLine.contains("---") && nextLine.contains("|") {
                    // Parse table
                    let headers = parseTableRow(trimmed)
                    var rows: [[String]] = []
                    var j = i + 2 // Skip header and separator
                    while j < lines.count {
                        let rowLine = lines[j].trimmingCharacters(in: .whitespaces)
                        if rowLine.hasPrefix("|") {
                            rows.append(parseTableRow(rowLine))
                            j += 1
                        } else {
                            break
                        }
                    }
                    blocks.append(.tableBlock(headers: headers, rows: rows))
                    i = j
                    continue
                }
            }

            // Regular paragraph
            blocks.append(.paragraph(text: trimmed))
            i += 1
        }

        return blocks
    }

    private func parseTableRow(_ line: String) -> [String] {
        line.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

#Preview("Markdown") {
    ScrollView {
        MarkdownView(markdown: """
        # Morning Briefing
        ### Monday, January 6, 2025 at 6:30 AM

        > What actually matters today

        ## Market Regime

        | Metric | Value |
        |--------|-------|
        | Regime | **Risk-On** |
        | VIX Proxy | 14.2 (Low) |
        | Breadth | 340 advancing / 160 declining |

        > **Context:** Broad participation across sectors. When breadth is this strong, individual stock moves tend to be more sustainable.

        ## Holdings in Play

        **NVDA** $875.42 (+3.21%)
        - Volume 2.1x above average
        - Behaving differently than its usual pattern (range 1.8x typical)

        **AAPL** $192.50 (+1.23%)
        - Moving up 1.23% pre-market/early

        ## Unusual Activity

        - **TSLA** volume spike: 2.8x average (98.5M)
        - **AMD** surging 4.2%

        ## Watch Today

        - **CRM**: Leading Technology sector (+3.52%)
        - **COST**: Unusual volume + bullish momentum

        ---

        _Generated by Market Companion_
        """)
        .padding()
    }
    .frame(width: 600, height: 800)
}
