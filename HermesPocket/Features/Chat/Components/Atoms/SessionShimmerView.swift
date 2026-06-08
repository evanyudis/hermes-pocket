import SwiftUI

// ── Shimmer modifier ──

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.5

    let duration: Double

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(phase - 0.25, 0)),
                        .init(color: .white.opacity(0.25), location: phase),
                        .init(color: .clear, location: min(phase + 0.25, 1)),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blendMode(.plusLighter)
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration).repeatForever(autoreverses: false)
                ) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer(duration: Double = 1.6) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
}

// ── Shimmer placeholder rows for sessions ──

struct SessionShimmerRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icon placeholder
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 8) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .frame(height: 14)

                // Subtitle placeholder
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .frame(width: 100, height: 10)
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .shimmer()
    }
}

struct SessionShimmerList: View {
    var body: some View {
        VStack(spacing: 0) {
            SessionShimmerRow()
            Divider().background(.white.opacity(0.04))
            SessionShimmerRow()
            Divider().background(.white.opacity(0.04))
            SessionShimmerRow()
        }
    }
}
