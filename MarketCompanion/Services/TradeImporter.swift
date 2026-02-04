// TradeImporter.swift
// MarketCompanion
//
// CSV import for trades from common brokers.

import Foundation

// MARK: - Broker Format

enum BrokerFormat: String, CaseIterable, Identifiable {
    case interactiveBrokers = "Interactive Brokers"
    case tdAmeritrade = "TD Ameritrade"
    case robinhood = "Robinhood"
    case schwab = "Schwab"
    case generic = "Generic CSV"

    var id: String { rawValue }

    var symbolColumn: String {
        switch self {
        case .interactiveBrokers: return "Symbol"
        case .tdAmeritrade: return "Symbol"
        case .robinhood: return "Instrument"
        case .schwab: return "Symbol"
        case .generic: return "Symbol"
        }
    }

    var sideColumn: String {
        switch self {
        case .interactiveBrokers: return "Buy/Sell"
        case .tdAmeritrade: return "Side"
        case .robinhood: return "Side"
        case .schwab: return "Action"
        case .generic: return "Side"
        }
    }

    var qtyColumn: String {
        switch self {
        case .interactiveBrokers: return "Quantity"
        case .tdAmeritrade: return "Qty"
        case .robinhood: return "Quantity"
        case .schwab: return "Quantity"
        case .generic: return "Qty"
        }
    }

    var priceColumn: String {
        switch self {
        case .interactiveBrokers: return "Price"
        case .tdAmeritrade: return "Price"
        case .robinhood: return "Average Price"
        case .schwab: return "Price"
        case .generic: return "Price"
        }
    }

    var dateColumn: String {
        switch self {
        case .interactiveBrokers: return "Date/Time"
        case .tdAmeritrade: return "Date"
        case .robinhood: return "Date"
        case .schwab: return "Date"
        case .generic: return "Date"
        }
    }

    var dateFormats: [String] {
        switch self {
        case .interactiveBrokers: return ["yyyy-MM-dd, HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyyMMdd"]
        case .tdAmeritrade: return ["MM/dd/yyyy HH:mm:ss", "MM/dd/yyyy"]
        case .robinhood: return ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd"]
        case .schwab: return ["MM/dd/yyyy", "MM/dd/yyyy HH:mm:ss"]
        case .generic: return ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "MM/dd/yyyy", "MM/dd/yyyy HH:mm:ss"]
        }
    }

    var delimiter: Character { "," }
    var headerRowSkip: Int { 0 }
}

// MARK: - Imported Trade

struct ImportedTrade: Identifiable {
    let id = UUID()
    var symbol: String
    var side: TradeSide
    var qty: Double
    var price: Double
    var date: Date
    var isDuplicate: Bool = false
    var isSelected: Bool = true
}

// MARK: - Trade Importer

enum TradeImporter {

    static func parseCSV(url: URL, format: BrokerFormat) throws -> [ImportedTrade] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count > format.headerRowSkip + 1 else { return [] }

        // Parse header
        let headerLine = lines[format.headerRowSkip]
        let headers = parseCSVLine(headerLine, delimiter: format.delimiter)
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }

        func columnIndex(_ name: String) -> Int? {
            headers.firstIndex(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame })
        }

        guard let symIdx = columnIndex(format.symbolColumn),
              let sideIdx = columnIndex(format.sideColumn),
              let qtyIdx = columnIndex(format.qtyColumn),
              let priceIdx = columnIndex(format.priceColumn),
              let dateIdx = columnIndex(format.dateColumn) else {
            throw ImportError.missingColumns
        }

        var trades: [ImportedTrade] = []
        let dateFormatters = format.dateFormats.map { fmt -> DateFormatter in
            let df = DateFormatter()
            df.dateFormat = fmt
            df.locale = Locale(identifier: "en_US_POSIX")
            return df
        }

        for lineIndex in (format.headerRowSkip + 1)..<lines.count {
            let fields = parseCSVLine(lines[lineIndex], delimiter: format.delimiter)
                .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }

            guard fields.count > max(symIdx, sideIdx, qtyIdx, priceIdx, dateIdx) else { continue }

            let symbol = fields[symIdx].uppercased()
            guard !symbol.isEmpty else { continue }

            let sideStr = fields[sideIdx].lowercased()
            let side: TradeSide = sideStr.contains("sell") || sideStr.contains("short") ? .short : .long

            guard let qty = Double(fields[qtyIdx].replacingOccurrences(of: ",", with: "")),
                  let price = Double(fields[priceIdx].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) else {
                continue
            }

            var date: Date?
            for formatter in dateFormatters {
                if let d = formatter.date(from: fields[dateIdx]) {
                    date = d
                    break
                }
            }
            guard let tradeDate = date else { continue }

            trades.append(ImportedTrade(
                symbol: symbol,
                side: side,
                qty: abs(qty),
                price: price,
                date: tradeDate
            ))
        }

        return trades
    }

    static func detectDuplicates(imported: inout [ImportedTrade], existing: [Trade]) {
        for i in 0..<imported.count {
            let imp = imported[i]
            imported[i].isDuplicate = existing.contains { trade in
                trade.symbol == imp.symbol &&
                abs(trade.entryTime.timeIntervalSince(imp.date)) < 60 &&
                trade.qty == imp.qty
            }
        }
    }

    static func importTrades(_ trades: [ImportedTrade], into repo: TradeRepository) throws -> Int {
        var count = 0
        for trade in trades where trade.isSelected && !trade.isDuplicate {
            var newTrade = Trade(
                symbol: trade.symbol,
                side: trade.side,
                qty: trade.qty,
                entryPrice: trade.price,
                entryTime: trade.date,
                tags: "broker-import"
            )
            try repo.save(&newTrade)
            count += 1
        }
        return count
    }

    // MARK: - CSV Line Parser (handles quoted fields)

    private static func parseCSVLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == delimiter && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    enum ImportError: LocalizedError {
        case missingColumns

        var errorDescription: String? {
            switch self {
            case .missingColumns: return "CSV file is missing required columns for the selected broker format."
            }
        }
    }
}
