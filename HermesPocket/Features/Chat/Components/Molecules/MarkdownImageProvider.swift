import SwiftUI
import MarkdownUI
import UIKit

/// Observable state that manages the full-screen image popup.
@MainActor
@Observable
final class ImagePopupState {
    var selectedImage: UIImage?
    var isPresented = false

    /// Memory cache of downloaded UIImages keyed by URL string.
    nonisolated(unsafe) static var imageCache: [String: UIImage] = [:]

    static let shared = ImagePopupState()
}

/// Custom MarkdownUI image provider that loads remote images with AsyncImage,
/// wraps them in a tappable view to open the zoomable popup, and shows
/// loading / error states instead of invisible failures.
struct HermesImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                loadingPlaceholder
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                    .onTapGesture {
                        Task { @MainActor in
                            Self.handleTap(url: url)
                        }
                    }
            case .failure:
                failedPlaceholder
            @unknown default:
                failedPlaceholder
            }
        }
    }

    /// Called when the user taps an image. Downloads the image data directly
    /// (bypassing AsyncImage's cache) and presents the popup.
    @MainActor
    private static func handleTap(url: URL?) {
        guard let url else { return }

        // Check memory cache first
        if let cached = ImagePopupState.imageCache[url.absoluteString] {
            ImagePopupState.shared.selectedImage = cached
            withAnimation(.easeOut(duration: 0.2)) {
                ImagePopupState.shared.isPresented = true
            }
            return
        }

        // Download on a background thread
        Task {
            guard let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data) else { return }
            await MainActor.run {
                ImagePopupState.imageCache[url.absoluteString] = uiImage
                ImagePopupState.shared.selectedImage = uiImage
                withAnimation(.easeOut(duration: 0.2)) {
                    ImagePopupState.shared.isPresented = true
                }
            }
        }
    }

    // ── Placeholder views ──

    private var loadingPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.white.opacity(0.4))
            Text("Loading image…")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var failedPlaceholder: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.caption)
            Text("Image unavailable")
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.35))
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Wrapper to use HermesImageProvider via the `.markdownImageProvider` modifier.
extension ImageProvider where Self == HermesImageProvider {
    static var hermes: Self { .init() }
}
