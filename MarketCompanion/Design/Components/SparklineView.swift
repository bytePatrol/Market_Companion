// SparklineView.swift
// MarketCompanion

import SwiftUI

struct SparklineView: View {
    let data: [Double]
    var lineColor: Color = .accentColor
    var lineWidth: CGFloat = 1.5
    var showGradient: Bool = true
    var animated: Bool = false

    @State private var animationProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            if data.count >= 2 {
                let minVal = data.min() ?? 0
                let maxVal = data.max() ?? 1
                let range = maxVal - minVal
                let safeRange = range > 0 ? range : 1

                ZStack {
                    // Gradient fill
                    if showGradient {
                        Path { path in
                            self.drawLine(in: &path, size: geometry.size, minVal: minVal, safeRange: safeRange)
                            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [lineColor.opacity(0.2), lineColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    // Line
                    Path { path in
                        self.drawLine(in: &path, size: geometry.size, minVal: minVal, safeRange: safeRange)
                    }
                    .trim(from: 0, to: animated ? animationProgress : 1)
                    .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 0.8)) {
                    animationProgress = 1
                }
            }
        }
    }

    private func drawLine(in path: inout Path, size: CGSize, minVal: Double, safeRange: Double) {
        let paddingY: CGFloat = 2
        let availableHeight = size.height - paddingY * 2

        for (index, value) in data.enumerated() {
            let x = size.width * CGFloat(index) / CGFloat(data.count - 1)
            let normalizedY = (value - minVal) / safeRange
            let y = paddingY + availableHeight * (1 - CGFloat(normalizedY))

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
}

// MARK: - Mini Sparkline (for heatmap tiles)

struct MiniSparkline: View {
    let data: [Double]
    var color: Color = .white

    var body: some View {
        SparklineView(
            data: data,
            lineColor: color,
            lineWidth: 1.0,
            showGradient: false
        )
    }
}

#Preview("Sparklines") {
    VStack(spacing: Spacing.lg) {
        SparklineView(
            data: [100, 102, 101, 105, 103, 108, 107, 110],
            lineColor: .gainGreen,
            animated: true
        )
        .frame(width: 200, height: 60)

        SparklineView(
            data: [110, 108, 109, 105, 103, 100, 102, 98],
            lineColor: .lossRed,
            animated: true
        )
        .frame(width: 200, height: 60)

        MiniSparkline(
            data: [10, 12, 11, 13, 12, 14],
            color: .white.opacity(0.8)
        )
        .frame(width: 40, height: 16)
        .padding()
        .background(Color.gainGreen)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .padding()
}
