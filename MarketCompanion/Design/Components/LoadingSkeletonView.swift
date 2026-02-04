// LoadingSkeletonView.swift
// MarketCompanion

import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 300
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shapes

struct SkeletonLine: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.textTertiary.opacity(0.15))
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct SkeletonCard: View {
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SkeletonLine(width: 80, height: 10)
                SkeletonLine(height: 24)
                SkeletonLine(width: 120, height: 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            SkeletonLine(width: 50, height: 16)
            Spacer()
            SkeletonLine(width: 60, height: 12)
            SkeletonLine(width: 70, height: 16)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(AppFont.caption())
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

#Preview("Skeletons") {
    VStack(spacing: Spacing.md) {
        SkeletonCard()
        SkeletonCard()
        SkeletonRow()
        SkeletonRow()
        SkeletonRow()
    }
    .padding()
    .frame(width: 350)
}
