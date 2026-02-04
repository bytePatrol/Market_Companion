// CandlestickChartView.swift
// MarketCompanion
//
// Interactive candlestick chart with Canvas rendering,
// overlay indicators, volume bars, and subchart panes.

import SwiftUI

struct CandlestickChartView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChartViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ChartToolbar(viewModel: viewModel)

            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading chart data...")
                    .font(AppFont.body())
                Spacer()
            } else if viewModel.candles.isEmpty {
                Spacer()
                chartEmptyState
                Spacer()
            } else {
                chartContent
            }
        }
        .onAppear {
            viewModel.configure(appState: appState)
            viewModel.symbol = appState.selectedChartSymbol ?? appState.holdings.first?.symbol ?? ""
            Task { await viewModel.loadData() }
        }
        .onChange(of: appState.selectedChartSymbol) {
            if let newSymbol = appState.selectedChartSymbol, !newSymbol.isEmpty {
                viewModel.symbol = newSymbol
                Task { await viewModel.loadData() }
            }
        }
        .onChange(of: viewModel.interval) {
            Task { await viewModel.loadData() }
        }
    }

    private var chartEmptyState: some View {
        EmptyStateView(
            icon: "chart.xyaxis.line",
            title: "No Chart Data",
            message: "Select a symbol from Heatmap or Watchlist, or enter one above.",
            actionTitle: "Load AAPL"
        ) {
            viewModel.symbol = "AAPL"
            Task { await viewModel.loadData() }
        }
    }

    private var chartContent: some View {
        VStack(spacing: 0) {
            // Crosshair OHLCV tooltip
            crosshairBar
                .frame(height: 20)

            // Main candlestick + overlay area
            CandlestickCanvas(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            // Volume bars
            if viewModel.configuration.showVolume {
                VolumeCanvas(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .clipped()
            }

            // Subchart panes
            ForEach(viewModel.configuration.subchartIndicators) { indicator in
                Divider()
                SubchartCanvas(viewModel: viewModel, indicator: indicator)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .clipped()
            }

            // Time axis
            TimeAxisView(viewModel: viewModel)
                .frame(height: 24)
        }
    }

    private var crosshairBar: some View {
        HStack(spacing: Spacing.md) {
            if let candle = viewModel.currentCandle {
                Group {
                    Text("O: \(FormatHelper.price(candle.open))")
                    Text("H: \(FormatHelper.price(candle.high))")
                    Text("L: \(FormatHelper.price(candle.low))")
                    Text("C: \(FormatHelper.price(candle.close))")
                        .foregroundStyle(Color.forChange(candle.close - candle.open))
                    Text("V: \(FormatHelper.volume(candle.volume))")
                }
                .font(AppFont.monoSmall())
                .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .background(Color.surfaceSecondary.opacity(0.5))
    }
}

// MARK: - Scroll Wheel Support (macOS)

private struct ScrollWheelView: NSViewRepresentable {
    let onScroll: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        ScrollWheelNSView(onScroll: onScroll)
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }

    class ScrollWheelNSView: NSView {
        var onScroll: (CGFloat, CGFloat) -> Void

        init(onScroll: @escaping (CGFloat, CGFloat) -> Void) {
            self.onScroll = onScroll
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func scrollWheel(with event: NSEvent) {
            onScroll(event.scrollingDeltaX, event.scrollingDeltaY)
        }
    }
}

// MARK: - Price Grid Helpers

private func niceGridStep(for range: Double, targetLines: Int = 5) -> Double {
    guard range > 0 else { return 1 }
    let roughStep = range / Double(targetLines)
    let magnitude = pow(10, floor(log10(roughStep)))
    let normalized = roughStep / magnitude

    if normalized <= 1.5 { return magnitude }
    if normalized <= 3.5 { return 2 * magnitude }
    if normalized <= 7.5 { return 5 * magnitude }
    return 10 * magnitude
}

private func gridLines(min: Double, max: Double, step: Double) -> [Double] {
    guard step > 0 else { return [] }
    var lines: [Double] = []
    var value = ceil(min / step) * step
    while value < max {
        lines.append(value)
        value += step
    }
    return lines
}

// MARK: - Candlestick Canvas

struct CandlestickCanvas: View {
    @ObservedObject var viewModel: ChartViewModel
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            Canvas { context, canvasSize in
                drawGridLines(context: context, size: canvasSize)
                drawCandles(context: context, size: canvasSize)
                drawOverlays(context: context, size: canvasSize)
                drawIchimokuCloud(context: context, size: canvasSize)
                drawVolumeProfile(context: context, size: canvasSize)
                drawComparisons(context: context, size: canvasSize)
                drawDrawings(context: context, size: canvasSize)
                drawTradePlan(context: context, size: canvasSize)
                drawPriceAxis(context: context, size: canvasSize)
                drawCrosshair(context: context, size: canvasSize)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if viewModel.drawingMode != .none {
                            viewModel.handleDrawingGesture(
                                start: value.startLocation,
                                current: value.location,
                                ended: false,
                                chartSize: size
                            )
                        } else {
                            let cw = viewModel.candleWidth(for: size.width)
                            let delta = value.translation.width - dragOffset
                            let shift = Int(delta / cw)
                            if shift != 0 {
                                viewModel.pan(candleShift: shift)
                                dragOffset = value.translation.width
                            }
                        }
                    }
                    .onEnded { value in
                        if viewModel.drawingMode != .none {
                            viewModel.handleDrawingGesture(
                                start: value.startLocation,
                                current: value.location,
                                ended: true,
                                chartSize: size
                            )
                        }
                        dragOffset = 0
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    viewModel.handleHover(at: location, chartSize: size)
                case .ended:
                    viewModel.clearCrosshair()
                }
            }
            .overlay {
                ScrollWheelView { deltaX, deltaY in
                    if abs(deltaY) > abs(deltaX) {
                        // Vertical scroll = zoom
                        let step = deltaY > 0 ? 3 : -3
                        viewModel.zoom(step: step)
                    } else if abs(deltaX) > 0.5 {
                        // Horizontal scroll = pan
                        let cw = viewModel.candleWidth(for: size.width)
                        let shift = Int(deltaX / max(1, cw / 3))
                        viewModel.pan(candleShift: shift)
                    }
                }
            }
        }
    }

    // MARK: - Grid Lines

    private func drawGridLines(context: GraphicsContext, size: CGSize) {
        guard let pr = viewModel.visiblePriceRange() else { return }

        let step = niceGridStep(for: pr.range)
        let lines = gridLines(min: pr.min, max: pr.max, step: step)
        let chartW = viewModel.chartAreaWidth(for: size.width)

        for price in lines {
            let y = priceToY(price, size: size, pr: pr)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: chartW, y: y))
            context.stroke(
                path,
                with: .color(.textTertiary.opacity(0.15)),
                style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
            )
        }
    }

    // MARK: - Price Axis

    private func drawPriceAxis(context: GraphicsContext, size: CGSize) {
        guard let pr = viewModel.visiblePriceRange() else { return }

        let chartW = viewModel.chartAreaWidth(for: size.width)
        let axisX = chartW + 4

        // Separator line
        var sep = Path()
        sep.move(to: CGPoint(x: chartW, y: 0))
        sep.addLine(to: CGPoint(x: chartW, y: size.height))
        context.stroke(sep, with: .color(.textTertiary.opacity(0.3)), lineWidth: 0.5)

        let step = niceGridStep(for: pr.range)
        let lines = gridLines(min: pr.min, max: pr.max, step: step)

        let useTwoDecimals = step >= 1.0
        let format = useTwoDecimals ? "%.2f" : "%.3f"

        for price in lines {
            let y = priceToY(price, size: size, pr: pr)
            let label = String(format: format, price)
            let text = Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color.textSecondary)

            context.draw(
                context.resolve(text),
                at: CGPoint(x: axisX, y: y),
                anchor: .leading
            )
        }

        // Current price label with highlight
        if let lastCandle = viewModel.candles.last {
            let y = priceToY(lastCandle.close, size: size, pr: pr)
            let clampedY = max(8, min(size.height - 8, y))
            let isGreen = lastCandle.close >= lastCandle.open
            let bgColor: Color = isGreen ? .gainGreen : .lossRed

            let labelRect = CGRect(x: chartW, y: clampedY - 8, width: ChartViewModel.priceAxisWidth, height: 16)
            context.fill(
                Path(roundedRect: labelRect, cornerRadius: 2),
                with: .color(bgColor)
            )

            let priceText = Text(String(format: "%.2f", lastCandle.close))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            context.draw(
                context.resolve(priceText),
                at: CGPoint(x: chartW + 4, y: clampedY),
                anchor: .leading
            )
        }
    }

    // MARK: - Candles

    private func drawCandles(context: GraphicsContext, size: CGSize) {
        let candles = viewModel.candles
        let range = viewModel.visibleRange
        guard range.lowerBound >= 0, range.upperBound <= candles.count, range.count > 0 else { return }
        guard let pr = viewModel.visiblePriceRange() else { return }

        let cw = viewModel.candleWidth(for: size.width)
        let bodyWidth = max(1, cw - max(2, cw * 0.3))

        for (i, candle) in candles[range].enumerated() {
            let x = CGFloat(i) * cw + cw / 2
            let isGreen = candle.close >= candle.open
            let color: Color = isGreen ? .gainGreen : .lossRed

            // Wick
            let wickTop = priceToY(candle.high, size: size, pr: pr)
            let wickBottom = priceToY(candle.low, size: size, pr: pr)
            var wickPath = Path()
            wickPath.move(to: CGPoint(x: x, y: wickTop))
            wickPath.addLine(to: CGPoint(x: x, y: wickBottom))
            context.stroke(wickPath, with: .color(color), lineWidth: 1)

            // Body
            let bodyTop = priceToY(max(candle.open, candle.close), size: size, pr: pr)
            let bodyBottom = priceToY(min(candle.open, candle.close), size: size, pr: pr)
            let bodyHeight = max(1, bodyBottom - bodyTop)
            let bodyRect = CGRect(x: x - bodyWidth / 2, y: bodyTop, width: bodyWidth, height: bodyHeight)
            context.fill(Path(bodyRect), with: .color(color))
        }
    }

    // MARK: - Overlays

    private func drawOverlays(context: GraphicsContext, size: CGSize) {
        let range = viewModel.visibleRange
        guard range.count > 0 else { return }
        guard let pr = viewModel.visiblePriceRange() else { return }

        let cw = viewModel.candleWidth(for: size.width)
        let totalCandles = viewModel.candles.count

        func drawLine(values: [Double], offset: Int, color: Color, dashed: Bool = false) {
            var path = Path()
            var started = false

            for i in range {
                let dataIndex = i - offset
                guard dataIndex >= 0, dataIndex < values.count else { continue }

                let x = CGFloat(i - range.lowerBound) * cw + cw / 2
                let y = priceToY(values[dataIndex], size: size, pr: pr)

                if !started {
                    path.move(to: CGPoint(x: x, y: y))
                    started = true
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            if dashed {
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            } else {
                context.stroke(path, with: .color(color), lineWidth: 1.5)
            }
        }

        let data = viewModel.indicatorData

        for smaLine in data.smaLines {
            let offset = totalCandles - smaLine.values.count
            drawLine(values: smaLine.values, offset: offset, color: smaLine.color)
        }

        for emaLine in data.emaLines {
            let offset = totalCandles - emaLine.values.count
            drawLine(values: emaLine.values, offset: offset, color: emaLine.color)
        }

        if let bb = data.bollingerBands {
            let offset = totalCandles - bb.upper.count
            drawLine(values: bb.upper, offset: offset, color: bb.color.opacity(0.6), dashed: true)
            drawLine(values: bb.middle, offset: offset, color: bb.color)
            drawLine(values: bb.lower, offset: offset, color: bb.color.opacity(0.6), dashed: true)
        }

        if let vwap = data.vwap {
            drawLine(values: vwap.values, offset: 0, color: vwap.color)
        }
    }

    // MARK: - Drawings

    private func drawDrawings(context: GraphicsContext, size: CGSize) {
        guard let pr = viewModel.visiblePriceRange() else { return }
        let range = viewModel.visibleRange
        guard range.count > 0 else { return }

        let cw = viewModel.candleWidth(for: size.width)
        let chartW = viewModel.chartAreaWidth(for: size.width)

        let allDrawings = viewModel.drawings + (viewModel.activeDrawing.map { [$0] } ?? [])

        for drawing in allDrawings {
            let drawColor: Color = .cyan

            switch drawing.type {
            case .horizontalLine:
                let y = priceToY(drawing.startPrice, size: size, pr: pr)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: chartW, y: y))
                context.stroke(path, with: .color(drawColor), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))

                let label = String(format: "%.2f", drawing.startPrice)
                let text = Text(label).font(.system(size: 9, design: .monospaced)).foregroundColor(drawColor)
                context.draw(context.resolve(text), at: CGPoint(x: chartW - 50, y: y - 10), anchor: .leading)

            case .trendLine:
                guard let endPrice = drawing.endPrice else { continue }
                let startY = priceToY(drawing.startPrice, size: size, pr: pr)
                let endY = priceToY(endPrice, size: size, pr: pr)
                let startX = timeToX(drawing.startTime, range: range, cw: cw)
                let endX = timeToX(drawing.endTime ?? drawing.startTime, range: range, cw: cw)

                var path = Path()
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
                context.stroke(path, with: .color(drawColor), lineWidth: 1.5)

            case .fibonacciRetracement:
                guard let endPrice = drawing.endPrice else { continue }
                let levels: [Double] = [0, 0.236, 0.382, 0.5, 0.618, 1.0]
                let priceDiff = endPrice - drawing.startPrice

                for level in levels {
                    let price = drawing.startPrice + priceDiff * level
                    let y = priceToY(price, size: size, pr: pr)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: chartW, y: y))

                    let opacity = level == 0 || level == 1.0 ? 0.7 : 0.4
                    context.stroke(path, with: .color(drawColor.opacity(opacity)), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))

                    let label = String(format: "%.1f%% (%.2f)", level * 100, price)
                    let text = Text(label).font(.system(size: 8, design: .monospaced)).foregroundColor(drawColor.opacity(0.7))
                    context.draw(context.resolve(text), at: CGPoint(x: 4, y: y - 8), anchor: .leading)
                }

            case .textAnnotation:
                let y = priceToY(drawing.startPrice, size: size, pr: pr)
                let x = timeToX(drawing.startTime, range: range, cw: cw)
                let label = drawing.label ?? "Note"
                let text = Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(drawColor)
                context.draw(context.resolve(text), at: CGPoint(x: x, y: y), anchor: .leading)
            }
        }
    }

    private func timeToX(_ time: Date, range: Range<Int>, cw: CGFloat) -> CGFloat {
        let candles = viewModel.candles
        // Find closest candle index for the given time
        var closestIdx = range.lowerBound
        var closestDist = Double.infinity
        for i in range {
            guard i < candles.count else { break }
            let dist = abs(candles[i].timestamp.timeIntervalSince(time))
            if dist < closestDist {
                closestDist = dist
                closestIdx = i
            }
        }
        return CGFloat(closestIdx - range.lowerBound) * cw + cw / 2
    }

    // MARK: - Comparisons

    private func drawComparisons(context: GraphicsContext, size: CGSize) {
        let range = viewModel.visibleRange
        guard range.count > 0, !viewModel.comparisonSymbols.isEmpty else { return }
        guard let pr = viewModel.visiblePriceRange() else { return }

        let cw = viewModel.candleWidth(for: size.width)
        let colors: [Color] = [.cyan, .orange, .pink, .mint, .indigo]
        let primaryCandles = viewModel.candles

        for (idx, compSymbol) in viewModel.comparisonSymbols.enumerated() {
            guard let compCandles = viewModel.comparisonCandles[compSymbol], !compCandles.isEmpty else { continue }
            let color = colors[idx % colors.count]

            var path = Path()
            var started = false

            // Find first visible comparison close for normalization
            var firstCompClose: Double?

            for i in range {
                guard i < primaryCandles.count else { break }
                let primaryDate = primaryCandles[i].timestamp

                // Find closest comparison candle by date
                guard let compClose = findClosestClose(date: primaryDate, in: compCandles) else { continue }

                if firstCompClose == nil { firstCompClose = compClose }

                let x = CGFloat(i - range.lowerBound) * cw + cw / 2
                let y: CGFloat

                if viewModel.normalizeMode {
                    // Show as % change from first visible bar
                    let pctChange = firstCompClose! > 0 ? (compClose - firstCompClose!) / firstCompClose! * 100 : 0
                    // Map % change to Y position: use ±20% as default range
                    let normPr = (min: -20.0, max: 20.0, range: 40.0)
                    y = CGFloat(4.0) + CGFloat(size.height - 8.0) * CGFloat(1.0 - (pctChange - normPr.min) / normPr.range)
                } else {
                    y = priceToY(compClose, size: size, pr: pr)
                }

                if !started {
                    path.move(to: CGPoint(x: x, y: y))
                    started = true
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(color), lineWidth: 1.5)

            // Legend at top-left
            let legendY = CGFloat(12 + idx * 16)
            let dot = Path(ellipseIn: CGRect(x: 8, y: legendY - 4, width: 8, height: 8))
            context.fill(dot, with: .color(color))

            let legendText = Text(compSymbol).font(.system(size: 9, weight: .semibold)).foregroundColor(color)
            context.draw(context.resolve(legendText), at: CGPoint(x: 20, y: legendY), anchor: .leading)
        }
    }

    private func findClosestClose(date: Date, in candles: [Candle]) -> Double? {
        // Binary-search-like approach for finding closest date
        var closest: (dist: TimeInterval, close: Double)?
        for candle in candles {
            let dist = abs(candle.timestamp.timeIntervalSince(date))
            if dist < 86400 * 2 { // Within 2 days
                if closest == nil || dist < closest!.dist {
                    closest = (dist, candle.close)
                }
            }
        }
        return closest?.close
    }

    // MARK: - Crosshair

    private func drawCrosshair(context: GraphicsContext, size: CGSize) {
        guard let index = viewModel.crosshairIndex else { return }
        let range = viewModel.visibleRange
        guard index >= range.lowerBound, index < range.upperBound else { return }
        guard let pr = viewModel.visiblePriceRange() else { return }

        let cw = viewModel.candleWidth(for: size.width)
        let chartW = viewModel.chartAreaWidth(for: size.width)
        let x = CGFloat(index - range.lowerBound) * cw + cw / 2

        // Vertical line
        var vLine = Path()
        vLine.move(to: CGPoint(x: x, y: 0))
        vLine.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(vLine, with: .color(.textTertiary.opacity(0.5)), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

        // Horizontal line at price
        if let price = viewModel.crosshairPrice {
            let y = priceToY(price, size: size, pr: pr)
            var hLine = Path()
            hLine.move(to: CGPoint(x: 0, y: y))
            hLine.addLine(to: CGPoint(x: chartW, y: y))
            context.stroke(hLine, with: .color(.textTertiary.opacity(0.5)), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

            // Price label on axis
            let labelRect = CGRect(x: chartW, y: y - 8, width: ChartViewModel.priceAxisWidth, height: 16)
            context.fill(
                Path(roundedRect: labelRect, cornerRadius: 2),
                with: .color(.textTertiary.opacity(0.8))
            )
            let priceText = Text(String(format: "%.2f", price))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            context.draw(context.resolve(priceText), at: CGPoint(x: chartW + 4, y: y), anchor: .leading)
        }
    }

    // MARK: - Ichimoku Cloud

    private func drawIchimokuCloud(context: GraphicsContext, size: CGSize) {
        guard let ichimoku = viewModel.indicatorData.ichimoku else { return }
        let range = viewModel.visibleRange
        guard range.count > 0 else { return }
        guard let pr = viewModel.visiblePriceRange() else { return }

        let cw = viewModel.candleWidth(for: size.width)
        let totalCandles = viewModel.candles.count

        // Draw Senkou Span cloud (filled region between A and B)
        let senkouAOffset = totalCandles - ichimoku.senkouA.count
        let senkouBOffset = totalCandles - ichimoku.senkouB.count

        // Collect points for cloud fill
        var topPoints: [(x: CGFloat, y: CGFloat)] = []
        var bottomPoints: [(x: CGFloat, y: CGFloat)] = []

        for i in range {
            let aiDx = i - senkouAOffset
            let biDx = i - senkouBOffset
            guard aiDx >= 0, aiDx < ichimoku.senkouA.count,
                  biDx >= 0, biDx < ichimoku.senkouB.count else { continue }

            let x = CGFloat(i - range.lowerBound) * cw + cw / 2
            let aY = priceToY(ichimoku.senkouA[aiDx], size: size, pr: pr)
            let bY = priceToY(ichimoku.senkouB[biDx], size: size, pr: pr)

            topPoints.append((x: x, y: min(aY, bY)))
            bottomPoints.append((x: x, y: max(aY, bY)))
        }

        // Fill cloud
        if topPoints.count > 1 {
            var cloudPath = Path()
            cloudPath.move(to: CGPoint(x: topPoints[0].x, y: topPoints[0].y))
            for p in topPoints.dropFirst() {
                cloudPath.addLine(to: CGPoint(x: p.x, y: p.y))
            }
            for p in bottomPoints.reversed() {
                cloudPath.addLine(to: CGPoint(x: p.x, y: p.y))
            }
            cloudPath.closeSubpath()

            // Green when A > B (bullish), red when B > A
            context.fill(cloudPath, with: .color(.teal.opacity(0.08)))
        }

        // Draw lines
        func drawIchimokuLine(values: [Double], offset: Int, color: Color, dashed: Bool = false) {
            var path = Path()
            var started = false
            for i in range {
                let di = i - offset
                guard di >= 0, di < values.count, values[di] > 0 else { continue }
                let x = CGFloat(i - range.lowerBound) * cw + cw / 2
                let y = priceToY(values[di], size: size, pr: pr)
                if !started { path.move(to: CGPoint(x: x, y: y)); started = true }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            if dashed {
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            } else {
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
        }

        let tenkanOffset = totalCandles - ichimoku.tenkan.count
        let kijunOffset = totalCandles - ichimoku.kijun.count
        let chikouOffset = totalCandles - ichimoku.chikou.count

        drawIchimokuLine(values: ichimoku.tenkan, offset: tenkanOffset, color: .cyan)
        drawIchimokuLine(values: ichimoku.kijun, offset: kijunOffset, color: .red)
        drawIchimokuLine(values: ichimoku.chikou, offset: chikouOffset, color: .gray, dashed: true)
        drawIchimokuLine(values: ichimoku.senkouA, offset: senkouAOffset, color: .green.opacity(0.6))
        drawIchimokuLine(values: ichimoku.senkouB, offset: senkouBOffset, color: .red.opacity(0.6))
    }

    // MARK: - Volume Profile

    private func drawVolumeProfile(context: GraphicsContext, size: CGSize) {
        guard let vpData = viewModel.volumeProfileData else { return }
        guard let pr = viewModel.visiblePriceRange() else { return }

        let chartW = viewModel.chartAreaWidth(for: size.width)
        let maxBarWidth = chartW * 0.25  // Max 25% of chart width

        for bin in vpData.bins {
            guard vpData.maxBinVolume > 0 else { continue }

            let y = priceToY(bin.priceLevel, size: size, pr: pr)
            let binHeight = size.height / CGFloat(vpData.bins.count) * 0.85
            let totalWidth = maxBarWidth * CGFloat(bin.totalVolume / vpData.maxBinVolume)

            let buyWidth = bin.totalVolume > 0 ? totalWidth * CGFloat(bin.buyVolume / bin.totalVolume) : 0
            let sellWidth = totalWidth - buyWidth

            // Draw from right side, extending left
            let buyRect = CGRect(x: chartW - totalWidth, y: y - binHeight / 2, width: buyWidth, height: binHeight)
            let sellRect = CGRect(x: chartW - sellWidth, y: y - binHeight / 2, width: sellWidth, height: binHeight)

            context.fill(Path(buyRect), with: .color(.gainGreen.opacity(0.2)))
            context.fill(Path(sellRect), with: .color(.lossRed.opacity(0.2)))
        }

        // POC line (yellow dashed)
        let pocY = priceToY(vpData.pointOfControl, size: size, pr: pr)
        var pocPath = Path()
        pocPath.move(to: CGPoint(x: 0, y: pocY))
        pocPath.addLine(to: CGPoint(x: chartW, y: pocY))
        context.stroke(pocPath, with: .color(.yellow), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))

        // VAH/VAL lines (white dashed)
        for level in [vpData.valueAreaHigh, vpData.valueAreaLow] {
            let y = priceToY(level, size: size, pr: pr)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: chartW, y: y))
            context.stroke(path, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
        }
    }

    // MARK: - Trade Plan

    private func drawTradePlan(context: GraphicsContext, size: CGSize) {
        guard let plan = viewModel.tradePlan else { return }
        guard let pr = viewModel.visiblePriceRange() else { return }

        let chartW = viewModel.chartAreaWidth(for: size.width)

        func drawPlanLine(price: Double, color: Color, label: String) {
            let y = priceToY(price, size: size, pr: pr)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: chartW, y: y))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))

            let text = Text("\(label): \(String(format: "%.2f", price))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(color)
            context.draw(context.resolve(text), at: CGPoint(x: 4, y: y - 10), anchor: .leading)
        }

        drawPlanLine(price: plan.entryPrice, color: .cyan, label: "Entry")
        drawPlanLine(price: plan.stopPrice, color: .red, label: "Stop")
        drawPlanLine(price: plan.targetPrice, color: .green, label: "Target")

        // Fill zones
        let entryY = priceToY(plan.entryPrice, size: size, pr: pr)
        let stopY = priceToY(plan.stopPrice, size: size, pr: pr)
        let targetY = priceToY(plan.targetPrice, size: size, pr: pr)

        // Risk zone (entry to stop)
        let riskRect = CGRect(x: 0, y: min(entryY, stopY), width: chartW, height: abs(stopY - entryY))
        context.fill(Path(riskRect), with: .color(.lossRed.opacity(0.05)))

        // Reward zone (entry to target)
        let rewardRect = CGRect(x: 0, y: min(entryY, targetY), width: chartW, height: abs(targetY - entryY))
        context.fill(Path(rewardRect), with: .color(.gainGreen.opacity(0.05)))

        // R:R label
        let rrText = Text("R:R \(String(format: "%.1f", plan.rewardToRisk))")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
        context.draw(context.resolve(rrText), at: CGPoint(x: chartW - 65, y: min(entryY, targetY) + 12), anchor: .leading)
    }

    // MARK: - Coordinate Helpers

    private func priceToY(
        _ price: Double,
        size: CGSize,
        pr: (min: Double, max: Double, range: Double)
    ) -> CGFloat {
        let topPad: CGFloat = 4
        let bottomPad: CGFloat = 4
        let drawableHeight = size.height - topPad - bottomPad
        return topPad + drawableHeight * CGFloat(1.0 - (price - pr.min) / pr.range)
    }
}

// MARK: - Volume Canvas

struct VolumeCanvas: View {
    @ObservedObject var viewModel: ChartViewModel

    var body: some View {
        Canvas { context, size in
            let candles = viewModel.candles
            let range = viewModel.visibleRange
            guard range.count > 0 else { return }

            let visibleCandles = Array(candles[range])
            guard !visibleCandles.isEmpty else { return }

            let maxVolume = Double(visibleCandles.map(\.volume).max() ?? 1)
            guard maxVolume > 0 else { return }

            let cw = viewModel.candleWidth(for: size.width)
            let barWidth = max(1, cw - max(2, cw * 0.3))

            for (i, candle) in visibleCandles.enumerated() {
                let x = CGFloat(i) * cw + cw / 2
                let heightFraction = CGFloat(Double(candle.volume) / maxVolume)
                let barHeight = size.height * heightFraction

                let isGreen = candle.close >= candle.open
                let color: Color = isGreen ? .gainGreen.opacity(0.35) : .lossRed.opacity(0.35)

                let rect = CGRect(
                    x: x - barWidth / 2,
                    y: size.height - barHeight,
                    width: barWidth,
                    height: barHeight
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
}

// MARK: - Subchart Canvas

struct SubchartCanvas: View {
    @ObservedObject var viewModel: ChartViewModel
    let indicator: SubchartIndicator

    var body: some View {
        Canvas { context, size in
            switch indicator.type {
            case .rsi:
                drawRSI(context: context, size: size)
            case .macd:
                drawMACD(context: context, size: size)
            case .atr:
                drawATR(context: context, size: size)
            case .stochastic:
                drawStochastic(context: context, size: size)
            case .obv:
                drawOBV(context: context, size: size)
            case .adx:
                drawADX(context: context, size: size)
            }
        }
        .overlay(alignment: .topLeading) {
            Text(indicator.type.rawValue)
                .font(AppFont.caption())
                .foregroundStyle(Color.textTertiary)
                .padding(2)
        }
    }

    private func drawRSI(context: GraphicsContext, size: CGSize) {
        guard let rsi = viewModel.indicatorData.rsi, !rsi.values.isEmpty else { return }
        let range = viewModel.visibleRange
        let totalCandles = viewModel.candles.count
        let offset = totalCandles - rsi.values.count
        let cw = viewModel.candleWidth(for: size.width)

        // Reference lines at 30 and 70
        let y30 = size.height * CGFloat(1.0 - 30.0 / 100.0)
        let y70 = size.height * CGFloat(1.0 - 70.0 / 100.0)
        let chartW = viewModel.chartAreaWidth(for: size.width)

        for (y, label) in [(y30, "30"), (y70, "70")] {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: chartW, y: y))
            context.stroke(line, with: .color(.textTertiary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))

            let text = Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color.textTertiary.opacity(0.5))
            context.draw(context.resolve(text), at: CGPoint(x: chartW + 4, y: y), anchor: .leading)
        }

        var path = Path()
        var started = false

        for i in range {
            let dataIndex = i - offset
            guard dataIndex >= 0, dataIndex < rsi.values.count else { continue }

            let x = CGFloat(i - range.lowerBound) * cw + cw / 2
            let y = size.height * CGFloat(1.0 - rsi.values[dataIndex] / 100.0)

            if !started {
                path.move(to: CGPoint(x: x, y: y))
                started = true
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(path, with: .color(.purple), lineWidth: 1.5)
    }

    private func drawMACD(context: GraphicsContext, size: CGSize) {
        guard let macd = viewModel.indicatorData.macd, !macd.histogram.isEmpty else { return }
        let range = viewModel.visibleRange
        let totalCandles = viewModel.candles.count
        let cw = viewModel.candleWidth(for: size.width)

        let histOffset = totalCandles - macd.histogram.count
        let visibleHist = (range.lowerBound..<range.upperBound).compactMap { i -> Double? in
            let di = i - histOffset
            guard di >= 0, di < macd.histogram.count else { return nil }
            return macd.histogram[di]
        }
        guard !visibleHist.isEmpty else { return }

        let maxAbs = visibleHist.map(abs).max() ?? 1
        guard maxAbs > 0 else { return }

        let midY = size.height / 2
        let barWidth = max(1, cw - max(2, cw * 0.3))

        // Zero line
        let chartW = viewModel.chartAreaWidth(for: size.width)
        var zeroLine = Path()
        zeroLine.move(to: CGPoint(x: 0, y: midY))
        zeroLine.addLine(to: CGPoint(x: chartW, y: midY))
        context.stroke(zeroLine, with: .color(.textTertiary.opacity(0.2)), lineWidth: 0.5)

        for i in range {
            let di = i - histOffset
            guard di >= 0, di < macd.histogram.count else { continue }

            let value = macd.histogram[di]
            let x = CGFloat(i - range.lowerBound) * cw + cw / 2
            let barHeight = size.height / 2 * CGFloat(abs(value) / maxAbs)

            let color: Color = value >= 0 ? .gainGreen.opacity(0.6) : .lossRed.opacity(0.6)
            let rect: CGRect
            if value >= 0 {
                rect = CGRect(x: x - barWidth / 2, y: midY - barHeight, width: barWidth, height: barHeight)
            } else {
                rect = CGRect(x: x - barWidth / 2, y: midY, width: barWidth, height: barHeight)
            }
            context.fill(Path(rect), with: .color(color))
        }

        func drawSubLine(values: [Double], totalOffset: Int, color: Color) {
            var path = Path()
            var started = false
            for i in range {
                let di = i - totalOffset
                guard di >= 0, di < values.count else { continue }
                let x = CGFloat(i - range.lowerBound) * cw + cw / 2
                let normalized = CGFloat(values[di] / maxAbs)
                let y = midY - normalized * (size.height / 2)
                if !started { path.move(to: CGPoint(x: x, y: y)); started = true }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(color), lineWidth: 1)
        }

        let macdOffset = totalCandles - macd.macdLine.count
        let signalOffset = totalCandles - macd.signalLine.count
        drawSubLine(values: macd.macdLine, totalOffset: macdOffset, color: .infoBlue)
        drawSubLine(values: macd.signalLine, totalOffset: signalOffset, color: .orange)
    }

    private func drawATR(context: GraphicsContext, size: CGSize) {
        guard let atr = viewModel.indicatorData.atr, !atr.isEmpty else { return }
        let range = viewModel.visibleRange
        let totalCandles = viewModel.candles.count
        let offset = totalCandles - atr.count
        let cw = viewModel.candleWidth(for: size.width)

        let visibleATR = (range.lowerBound..<range.upperBound).compactMap { i -> Double? in
            let di = i - offset
            guard di >= 0, di < atr.count else { return nil }
            return atr[di]
        }
        guard !visibleATR.isEmpty else { return }

        let minATR = visibleATR.min() ?? 0
        let maxATR = visibleATR.max() ?? 1
        let atrRange = maxATR - minATR
        guard atrRange > 0 else { return }

        var path = Path()
        var started = false

        for i in range {
            let di = i - offset
            guard di >= 0, di < atr.count else { continue }
            let x = CGFloat(i - range.lowerBound) * cw + cw / 2
            let y = size.height * CGFloat(1.0 - (atr[di] - minATR) / atrRange)
            if !started { path.move(to: CGPoint(x: x, y: y)); started = true }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        context.stroke(path, with: .color(.warningAmber), lineWidth: 1.5)
    }

    // MARK: - Stochastic

    private func drawStochastic(context: GraphicsContext, size: CGSize) {
        guard let stoch = viewModel.indicatorData.stochastic, !stoch.k.isEmpty else { return }
        let range = viewModel.visibleRange
        let totalCandles = viewModel.candles.count
        let cw = viewModel.candleWidth(for: size.width)
        let chartW = viewModel.chartAreaWidth(for: size.width)

        let kOffset = totalCandles - stoch.k.count
        let dOffset = totalCandles - stoch.d.count

        // Reference lines at 20 and 80
        for (refY, label) in [(size.height * 0.8, "20"), (size.height * 0.2, "80")] {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: refY))
            line.addLine(to: CGPoint(x: chartW, y: refY))
            context.stroke(line, with: .color(.textTertiary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))

            let text = Text(label).font(.system(size: 8, design: .monospaced)).foregroundColor(Color.textTertiary.opacity(0.5))
            context.draw(context.resolve(text), at: CGPoint(x: chartW + 4, y: refY), anchor: .leading)
        }

        // %K line (blue)
        func drawStochLine(values: [Double], offset: Int, color: Color) {
            var path = Path()
            var started = false
            for i in range {
                let di = i - offset
                guard di >= 0, di < values.count else { continue }
                let x = CGFloat(i - range.lowerBound) * cw + cw / 2
                let y = size.height * CGFloat(1.0 - values[di] / 100.0)
                if !started { path.move(to: CGPoint(x: x, y: y)); started = true }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }

        drawStochLine(values: stoch.k, offset: kOffset, color: .blue)
        drawStochLine(values: stoch.d, offset: dOffset, color: .orange)
    }

    // MARK: - OBV

    private func drawOBV(context: GraphicsContext, size: CGSize) {
        guard let obv = viewModel.indicatorData.obv, !obv.isEmpty else { return }
        let range = viewModel.visibleRange
        let totalCandles = viewModel.candles.count
        let offset = totalCandles - obv.count
        let cw = viewModel.candleWidth(for: size.width)
        let chartW = viewModel.chartAreaWidth(for: size.width)

        let visibleOBV = (range.lowerBound..<range.upperBound).compactMap { i -> Double? in
            let di = i - offset
            guard di >= 0, di < obv.count else { return nil }
            return obv[di]
        }
        guard !visibleOBV.isEmpty else { return }

        let minOBV = visibleOBV.min() ?? 0
        let maxOBV = visibleOBV.max() ?? 1
        let obvRange = maxOBV - minOBV
        guard obvRange > 0 else { return }

        // Zero reference line
        let zeroNorm = (0 - minOBV) / obvRange
        if zeroNorm >= 0 && zeroNorm <= 1 {
            let zeroY = size.height * CGFloat(1.0 - zeroNorm)
            var zLine = Path()
            zLine.move(to: CGPoint(x: 0, y: zeroY))
            zLine.addLine(to: CGPoint(x: chartW, y: zeroY))
            context.stroke(zLine, with: .color(.textTertiary.opacity(0.2)), lineWidth: 0.5)
        }

        var path = Path()
        var started = false

        for i in range {
            let di = i - offset
            guard di >= 0, di < obv.count else { continue }
            let x = CGFloat(i - range.lowerBound) * cw + cw / 2
            let y = size.height * CGFloat(1.0 - (obv[di] - minOBV) / obvRange)
            if !started { path.move(to: CGPoint(x: x, y: y)); started = true }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        context.stroke(path, with: .color(.teal), lineWidth: 1.5)
    }

    // MARK: - ADX

    private func drawADX(context: GraphicsContext, size: CGSize) {
        guard let adxData = viewModel.indicatorData.adx, !adxData.adx.isEmpty else { return }
        let range = viewModel.visibleRange
        let totalCandles = viewModel.candles.count
        let cw = viewModel.candleWidth(for: size.width)
        let chartW = viewModel.chartAreaWidth(for: size.width)

        let plusDIOffset = totalCandles - adxData.plusDI.count
        let minusDIOffset = totalCandles - adxData.minusDI.count
        let adxOffset = totalCandles - adxData.adx.count

        // Reference line at 25
        let y25 = size.height * CGFloat(1.0 - 25.0 / 100.0)
        var refLine = Path()
        refLine.move(to: CGPoint(x: 0, y: y25))
        refLine.addLine(to: CGPoint(x: chartW, y: y25))
        context.stroke(refLine, with: .color(.textTertiary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))

        let refText = Text("25").font(.system(size: 8, design: .monospaced)).foregroundColor(Color.textTertiary.opacity(0.5))
        context.draw(context.resolve(refText), at: CGPoint(x: chartW + 4, y: y25), anchor: .leading)

        func drawDILine(values: [Double], offset: Int, color: Color) {
            var path = Path()
            var started = false
            for i in range {
                let di = i - offset
                guard di >= 0, di < values.count else { continue }
                let x = CGFloat(i - range.lowerBound) * cw + cw / 2
                let y = size.height * CGFloat(1.0 - min(values[di], 100) / 100.0)
                if !started { path.move(to: CGPoint(x: x, y: y)); started = true }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(color), lineWidth: 1)
        }

        drawDILine(values: adxData.plusDI, offset: plusDIOffset, color: .green)
        drawDILine(values: adxData.minusDI, offset: minusDIOffset, color: .red)
        drawDILine(values: adxData.adx, offset: adxOffset, color: .white)
    }
}

// MARK: - Time Axis

struct TimeAxisView: View {
    @ObservedObject var viewModel: ChartViewModel

    var body: some View {
        Canvas { context, size in
            let range = viewModel.visibleRange
            guard range.count > 0 else { return }

            let cw = viewModel.candleWidth(for: size.width)
            // Show a label every ~80px at minimum
            let labelInterval = max(1, Int(80 / cw))

            let formatter = DateFormatter()
            formatter.dateFormat = viewModel.interval == .daily || viewModel.interval == .weekly ? "MMM d" : "HH:mm"

            for i in stride(from: range.lowerBound, to: range.upperBound, by: labelInterval) {
                guard i < viewModel.candles.count else { continue }
                let x = CGFloat(i - range.lowerBound) * cw + cw / 2
                let dateStr = formatter.string(from: viewModel.candles[i].timestamp)

                let text = Text(dateStr)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.textTertiary)

                context.draw(context.resolve(text), at: CGPoint(x: x, y: size.height / 2))
            }
        }
        .background(Color.surfaceSecondary.opacity(0.3))
    }
}
