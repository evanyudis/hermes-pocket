import SwiftUI

enum LiquidGlassPreset {
    case control
    case composer
    case panel
    case banner

    private var buttonFrostTint: Double { 0.018 }

    @available(iOS 26.0, *)
    var nativeGlass: Glass {
        switch self {
        case .control:
            return .clear.tint(.black.opacity(buttonFrostTint)).interactive()
        case .composer:
            return .regular.tint(.black.opacity(0.028))
        case .panel:
            return .clear.tint(.black.opacity(0.014))
        case .banner:
            return .clear.tint(.black.opacity(0.012))
        }
    }

    var fallbackTintOpacity: Double {
        switch self {
        case .control: 0.008
        case .composer: 0.012
        case .panel: 0.005
        case .banner: 0.004
        }
    }

    var fallbackHighlightOpacity: Double {
        switch self {
        case .control: 0.026
        case .composer: 0.034
        case .panel: 0.02
        case .banner: 0.018
        }
    }

    var shadowColor: Color {
        .black.opacity(0.035)
    }

    var shadowRadius: CGFloat {
        switch self {
        case .control: 8
        case .composer: 16
        case .panel: 14
        case .banner: 10
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .control: 2
        case .composer: -2
        case .panel: -2
        case .banner: 1
        }
    }
}

extension View {
    @ViewBuilder
    func liquidGlass<S: InsettableShape>(_ shape: S, preset: LiquidGlassPreset = .panel) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(preset.nativeGlass, in: shape)
                .shadow(color: preset.shadowColor, radius: preset.shadowRadius, y: preset.shadowY)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .environment(\.colorScheme, .dark)
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(preset.fallbackHighlightOpacity),
                                    Color.cyan.opacity(preset.fallbackTintOpacity),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .allowsHitTesting(false)
                }
                .shadow(color: preset.shadowColor, radius: preset.shadowRadius, y: preset.shadowY)
                .opacity(0.95)
        }
    }
}
