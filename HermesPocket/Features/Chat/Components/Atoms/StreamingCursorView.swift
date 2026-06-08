import SwiftUI

/// Static cursor indicator — no blinking animation.
/// The old TimelineView-based blink caused 60fps view invalidation
/// that competed with MarkdownUI re-renders during streaming.
struct StreamingCursorView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(.secondary)
            .frame(width: 2, height: 16)
            .padding(.bottom, 1)
    }
}
