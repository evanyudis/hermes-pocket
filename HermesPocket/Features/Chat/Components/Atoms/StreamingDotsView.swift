import SwiftUI

struct StreamingDotsView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate * 2.5) % 3
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(index <= phase ? 0.95 : 0.3)
                        .scaleEffect(index == phase ? 1 : 0.82)
                }
            }
            .frame(height: 20, alignment: .leading)
        }
    }
}
