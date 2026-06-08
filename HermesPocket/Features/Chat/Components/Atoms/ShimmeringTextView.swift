import SwiftUI

struct ShimmeringTextView: View {
    let text: String

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let x = t.remainder(dividingBy: 2.8) / 2.8  // slow sweep ~2.8s

                Text(text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)
                    .tracking(-0.1)
                    .lineLimit(2)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.6), location: max(0, x - 0.3)),
                                .init(color: .black, location: x),
                                .init(color: .black.opacity(0.6), location: min(1, x + 0.3)),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
    }
}
