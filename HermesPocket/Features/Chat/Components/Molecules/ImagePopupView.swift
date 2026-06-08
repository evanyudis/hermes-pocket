import SwiftUI
import UIKit
import PhotosUI

/// Full-screen zoomable image popup with liquid glass download button.
struct ImagePopupView: View {
    let image: UIImage
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showDownloadedToast = false

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 5.0

    var body: some View {
        ZStack {
            // ── Dismiss on background tap ──
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { isPresented = false } }

            // ── Zoomable image ──
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, minScale), maxScale)
                        }
                        .onEnded { _ in lastScale = 1.0 }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in lastOffset = offset }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                        }
                )
                .padding(24)

            // ── Close button (top trailing) ──
            VStack {
                HStack {
                    Spacer()
                    closeButton
                }
                Spacer()
            }
            .padding(20)

            // ── Download button (bottom trailing) ──
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    downloadButton
                }
            }
            .padding(24)

            // ── Toast ──
            if showDownloadedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Saved to Photos")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 80)
                }
            }
        }
        .statusBar(hidden: true)
    }

    // ── Close button ──

    private var closeButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) { isPresented = false }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)
                    .environment(\.colorScheme, .dark)

                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    // ── Download button ──

    private var downloadButton: some View {
        Button {
            saveImage()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                    .environment(\.colorScheme, .dark)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }

    // ── Save to Photos ──

    private func saveImage() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    if success {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            showDownloadedToast = true
                        }
                        Task { try? await Task.sleep(for: .seconds(1.8))
                            withAnimation(.easeOut(duration: 0.2)) {
                                showDownloadedToast = false
                            }
                        }
                    }
                }
            }
        }
    }
}
