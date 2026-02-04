// ChartExporter.swift
// MarketCompanion
//
// Exports the current chart view as PNG to clipboard or file.

import AppKit
import SwiftUI

@MainActor
enum ChartExporter {

    private static let exportSize = CGSize(width: 1200, height: 800)

    // MARK: - Copy to Clipboard

    static func copyToClipboard(viewModel: ChartViewModel) {
        guard let image = renderChartImage(viewModel: viewModel) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    // MARK: - Save as PNG

    static func exportToPNG(viewModel: ChartViewModel) {
        guard let image = renderChartImage(viewModel: viewModel) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(viewModel.symbol)_chart.png"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            guard let tiffData = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

            do {
                try pngData.write(to: url)
            } catch {
                print("[ChartExporter] Failed to save PNG: \(error)")
            }
        }
    }

    // MARK: - Render

    private static func renderChartImage(viewModel: ChartViewModel) -> NSImage? {
        let candles = viewModel.exportableCandles()
        guard !candles.isEmpty else { return nil }

        let size = exportSize
        let image = NSImage(size: size)
        image.lockFocus()

        guard let cgContext = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        // Background
        cgContext.setFillColor(NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).cgColor)
        cgContext.fill(CGRect(origin: .zero, size: size))

        // Header bar
        let headerRect = CGRect(x: 0, y: size.height - 30, width: size.width, height: 30)
        cgContext.setFillColor(NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0).cgColor)
        cgContext.fill(headerRect)

        let headerString = "\(viewModel.symbol) - \(viewModel.interval.rawValue)" as NSString
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        headerString.draw(at: CGPoint(x: 8, y: size.height - 22), withAttributes: headerAttrs)

        // Watermark
        let watermark = "Market Companion" as NSString
        let watermarkAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.3)
        ]
        let wmSize = watermark.size(withAttributes: watermarkAttrs)
        watermark.draw(at: CGPoint(x: size.width - wmSize.width - 8, y: size.height - 22), withAttributes: watermarkAttrs)

        // Draw candles
        let chartArea = CGRect(x: 0, y: 0, width: size.width - 60, height: size.height - 30)
        let visibleCandles = candles
        guard let lo = visibleCandles.map(\.low).min(),
              let hi = visibleCandles.map(\.high).max() else {
            image.unlockFocus()
            return image
        }

        let padding = max((hi - lo) * 0.05, 0.01)
        let priceMin = lo - padding
        let priceMax = hi + padding
        let priceRange = priceMax - priceMin

        let cw = chartArea.width / CGFloat(visibleCandles.count)
        let bodyWidth = max(1, cw - max(2, cw * 0.3))

        for (i, candle) in visibleCandles.enumerated() {
            let x = CGFloat(i) * cw + cw / 2
            let isGreen = candle.close >= candle.open
            let color = isGreen ? NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0) : NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)

            cgContext.setStrokeColor(color.cgColor)
            cgContext.setFillColor(color.cgColor)

            // Wick
            let wickTop = chartArea.height * CGFloat(1.0 - (candle.high - priceMin) / priceRange)
            let wickBottom = chartArea.height * CGFloat(1.0 - (candle.low - priceMin) / priceRange)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: x, y: wickTop))
            cgContext.addLine(to: CGPoint(x: x, y: wickBottom))
            cgContext.strokePath()

            // Body
            let bodyTop = chartArea.height * CGFloat(1.0 - (max(candle.open, candle.close) - priceMin) / priceRange)
            let bodyBottom = chartArea.height * CGFloat(1.0 - (min(candle.open, candle.close) - priceMin) / priceRange)
            let bodyH = max(1, bodyBottom - bodyTop)
            let bodyRect = CGRect(x: x - bodyWidth / 2, y: bodyTop, width: bodyWidth, height: bodyH)
            cgContext.fill(bodyRect)
        }

        image.unlockFocus()
        return image
    }
}
