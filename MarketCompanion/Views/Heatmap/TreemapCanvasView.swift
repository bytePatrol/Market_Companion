// TreemapCanvasView.swift
// MarketCompanion
//
// Canvas-based renderer for the squarified treemap heatmap.

import SwiftUI

enum TreemapSizeStrategy: String, CaseIterable {
    case equal = "Equal Weight"
    case volume = "By Volume"
    case positionSize = "By Position"
}

struct TreemapCanvasView: View {
    @EnvironmentObject var appState: AppState
    let quotes: [Quote]
    let sizeStrategy: TreemapSizeStrategy
    var onSymbolTap: ((String) -> Void)?

    @State private var hoveredSymbol: String?
    @State private var treemapRects: [TreemapRect] = []
    @State private var lastSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            Canvas { context, canvasSize in
                for rect in treemapRects {
                    drawTile(context: context, rect: rect, canvasSize: canvasSize)
                }
                drawSectorLabels(context: context)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredSymbol = treemapRects.first(where: { $0.frame.contains(location) })?.symbol
                case .ended:
                    hoveredSymbol = nil
                }
            }
            .onTapGesture { location in
                if let rect = treemapRects.first(where: { $0.frame.contains(location) }) {
                    onSymbolTap?(rect.symbol)
                }
            }
            .onChange(of: size) {
                recalculate(size: size)
            }
            .onChange(of: quotes.count) {
                recalculate(size: size)
            }
            .onChange(of: sizeStrategy) {
                recalculate(size: size)
            }
            .onAppear {
                recalculate(size: size)
            }
        }
    }

    private func recalculate(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        lastSize = size

        let items = quotes.map { quote -> TreemapItem in
            let sizeValue: Double
            switch sizeStrategy {
            case .equal:
                sizeValue = 1.0
            case .volume:
                sizeValue = Double(quote.volume)
            case .positionSize:
                if let holding = appState.holdings.first(where: { $0.symbol == quote.symbol }),
                   let shares = holding.shares {
                    sizeValue = shares * quote.last
                } else {
                    sizeValue = quote.last * 100
                }
            }
            return TreemapItem(
                symbol: quote.symbol,
                sizeValue: max(sizeValue, 0.001),
                changePct: quote.changePct,
                sector: MarketSector.classify(quote.symbol).rawValue
            )
        }

        let targetRect = CGRect(origin: .zero, size: size)
        treemapRects = TreemapLayout.layout(items: items, in: targetRect)
    }

    private func drawTile(context: GraphicsContext, rect: TreemapRect, canvasSize: CGSize) {
        let isHovered = hoveredSymbol == rect.symbol
        let inset: CGFloat = 1.5
        let frame = rect.frame.insetBy(dx: inset, dy: inset)
        guard frame.width > 2, frame.height > 2 else { return }

        let bgColor = Color.heatmapColor(for: rect.changePct)
        let brightness: CGFloat = isHovered ? 0.15 : 0

        let roundedPath = Path(roundedRect: frame, cornerRadius: 4)
        context.fill(roundedPath, with: .color(bgColor.opacity(isHovered ? 1.0 : 0.9)))

        if brightness > 0 {
            context.fill(roundedPath, with: .color(.white.opacity(brightness)))
        }

        // Symbol text
        if frame.width > 28 && frame.height > 18 {
            let fontSize: CGFloat = frame.width > 80 ? 12 : (frame.width > 50 ? 10 : 8)
            let symbolText = Text(rect.symbol)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            context.draw(
                context.resolve(symbolText),
                at: CGPoint(x: frame.midX, y: frame.midY - (frame.height > 36 ? 6 : 0))
            )
        }

        // Change % below symbol
        if frame.width > 40 && frame.height > 36 {
            let changeFontSize: CGFloat = frame.width > 80 ? 10 : 8
            let changeText = Text(FormatHelper.percent(rect.changePct))
                .font(.system(size: changeFontSize, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
            context.draw(
                context.resolve(changeText),
                at: CGPoint(x: frame.midX, y: frame.midY + 8)
            )
        }
    }

    private func drawSectorLabels(context: GraphicsContext) {
        // Group rects by sector and find top-left of each cluster
        let grouped = Dictionary(grouping: treemapRects, by: \.sector)
        for (sector, rects) in grouped {
            guard let first = rects.min(by: { $0.frame.minY < $1.frame.minY || ($0.frame.minY == $1.frame.minY && $0.frame.minX < $1.frame.minX) }) else { continue }

            // Only show if the cluster is large enough
            let clusterArea = rects.reduce(0.0) { $0 + Double($1.frame.width * $1.frame.height) }
            guard clusterArea > 3000 else { continue }

            let label = Text(sector)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
            context.draw(
                context.resolve(label),
                at: CGPoint(x: first.frame.minX + 6, y: first.frame.minY + 10),
                anchor: .leading
            )
        }
    }
}
