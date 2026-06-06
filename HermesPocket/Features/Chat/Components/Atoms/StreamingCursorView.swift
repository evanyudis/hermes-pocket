import SwiftUI

struct StreamingCursorView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let visible = Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            RoundedRectangle(cornerRadius: 1)
                .fill(.secondary)
                .frame(width: 2, height: 16)
                .opacity(visible ? 1 : 0.15)
                .padding(.bottom, 1)
        }
    }
}
