import SwiftUI

struct GlassCircleButton: View {
    let systemName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: 46, height: 46)
                .liquidGlass(Circle(), preset: .control)

            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: 46, height: 46)
    }
}
