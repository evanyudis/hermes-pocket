import SwiftUI
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct AttachmentCardView: View {
    enum Style {
        case composer
        case message

        var trailingPadding: CGFloat {
            switch self {
            case .composer: 8
            case .message: 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .composer: 5
            case .message: 6
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .composer: 12
            case .message: 14
            }
        }

        var backgroundOpacity: Double { 0.08 }

        var gradientPalette: AttachmentGradientPalette {
            switch self {
            case .composer: .muted
            case .message: .vibrant
            }
        }
    }

    let attachment: AttachmentDTO
    var style: Style = .composer
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            AttachmentPreview(attachment: attachment, palette: style.gradientPalette)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(attachment.mime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 132, alignment: .leading)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, style.trailingPadding)
        .padding(.vertical, style.verticalPadding)
        .background(
            Color.white.opacity(style.backgroundOpacity),
            in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        )
    }
}

private struct AttachmentPreview: View {
    let attachment: AttachmentDTO
    let palette: AttachmentGradientPalette

    @State private var remoteImage: UIImage? = nil

    private var localFileExists: Bool {
        FileManager.default.fileExists(atPath: attachment.path)
    }

    var body: some View {
        let cornerRadius: CGFloat = 8

        Group {
            if attachmentIsImage(attachment) && localFileExists {
                // Image that exists locally — show preview
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.10))
                    .overlay {
                        if let image = UIImage(contentsOfFile: attachment.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            FileThumbnailView(url: URL(fileURLWithPath: attachment.path))
                        }
                    }
            } else if attachmentIsImage(attachment), let remoteImage {
                // Image downloaded from server
                Image(uiImage: remoteImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // Non-image file, or image not available locally — show format icon
                let fill: AnyShapeStyle = if case .other = attachmentFileFormatKind(for: attachment) {
                    AnyShapeStyle(Color.white.opacity(0.10))
                } else {
                    AnyShapeStyle(attachmentFileFormatGradient(for: attachment, palette: palette))
                }
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        Image(systemName: attachmentFileFormatIcon(for: attachment))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(attachmentFileFormatIconColor(for: attachment))
                    )
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task {
            // If image not available locally, try downloading from server
            if attachmentIsImage(attachment) && !localFileExists && remoteImage == nil {
                await downloadRemoteImage()
            }
        }
    }

    private func downloadRemoteImage() async {
        // Try to construct a valid server URL from the attachment path.
        // Server-side paths typically start with "/" and reference files
        // within the workspace. Try multiple URL patterns.
        let path = attachment.path
        guard path.hasPrefix("/") else { return }

        // Build candidate URLs from the server base URL
        let candidates = HermesFileURLBuilder.candidateURLs(for: path)
        for url in candidates {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run { self.remoteImage = image }
                    return
                }
            } catch {
                continue
            }
        }
    }
}

/// Constructs candidate server URLs for downloading attached files.
private enum HermesFileURLBuilder {
    static func candidateURLs(for path: String) -> [URL] {
        // Try to get base URL from the current connection store
        let baseURLString = CredentialStore().loadBaseURL()
        guard let baseURL = URL(string: baseURLString), !baseURLString.isEmpty else {
            return []
        }

        var candidates: [URL] = []

        // Pattern 1: {baseURL}/api/session/file?path={path}
        if var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) {
            components.path = "/api/session/file"
            components.queryItems = [URLQueryItem(name: "path", value: path)]
            if let url = components.url { candidates.append(url) }
        }

        // Pattern 2: {baseURL}/uploads/{filename}
        let filename = URL(fileURLWithPath: path).lastPathComponent
        if var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) {
            components.path = "/uploads/\(filename)"
            if let url = components.url { candidates.append(url) }
        }

        // Pattern 3: Raw path if it's an absolute URL
        if path.hasPrefix("http"), let url = URL(string: path) {
            candidates.append(url)
        }

        return candidates
    }
}

enum AttachmentGradientPalette {
    case muted
    case vibrant
}

private struct FileThumbnailView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    @MainActor
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        context.coordinator.loadThumbnail(into: imageView)
        return imageView
    }

    @MainActor
    func updateUIView(_ uiView: UIImageView, context: Context) {
        context.coordinator.loadThumbnail(into: uiView)
    }

    final class Coordinator {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        @MainActor
        func loadThumbnail(into imageView: UIImageView) {
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: 120, height: 120),
                scale: imageView.traitCollection.displayScale,
                representationTypes: .thumbnail
            )

            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                guard let image = representation?.uiImage else { return }
                DispatchQueue.main.async {
                    imageView.image = image
                }
            }
        }
    }
}

private enum AttachmentFileFormatKind {
    case pdf
    case text
    case sheet
    case archive
    case other
}

private func attachmentFileFormatIcon(for attachment: AttachmentDTO) -> String {
    switch attachmentFileFormatKind(for: attachment) {
    case .pdf:
        return "doc.richtext"
    case .sheet:
        return "tablecells"
    case .text:
        return "doc.text"
    case .archive:
        return "doc.zipper"
    case .other:
        return "doc"
    }
}

private func attachmentFileFormatGradient(for attachment: AttachmentDTO, palette: AttachmentGradientPalette) -> LinearGradient {
    let kind = attachmentFileFormatKind(for: attachment)
    switch palette {
    case .muted:
        let base: Color
        switch kind {
        case .pdf:
            base = Color(hex: "490908")
        case .text:
            base = Color(hex: "043A4E")
        case .sheet:
            base = Color(hex: "153C17")
        case .archive:
            base = Color(hex: "5F4C07")
        case .other:
            base = Color(hex: "2A2A2C")
        }

        return LinearGradient(
            colors: [base.opacity(0.98), base.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    case .vibrant:
        switch kind {
        case .pdf:
            return LinearGradient(colors: [Color(hex: "FF6B6B"), Color(hex: "C92A2A")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sheet:
            return LinearGradient(colors: [Color(hex: "51CF66"), Color(hex: "2B8A3E")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .archive:
            return LinearGradient(colors: [Color(hex: "FCC419"), Color(hex: "E67700")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .text:
            return LinearGradient(colors: [Color(hex: "74C0FC"), Color(hex: "1C7ED6")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .other:
            return LinearGradient(colors: [Color(hex: "ADB5BD"), Color(hex: "495057")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private func attachmentFileFormatIconColor(for attachment: AttachmentDTO) -> Color {
    switch attachmentFileFormatKind(for: attachment) {
    case .pdf:
        return Color(hex: "E93835")
    case .text:
        return Color(hex: "16B8F3")
    case .sheet:
        return Color(hex: "59C55E")
    case .archive:
        return Color(hex: "F1CB41")
    case .other:
        return .white
    }
}

private func attachmentIsImage(_ attachment: AttachmentDTO) -> Bool {
    let ext = URL(fileURLWithPath: attachment.name).pathExtension.lowercased()
    if let type = UTType(filenameExtension: ext), type.conforms(to: .image) {
        return true
    }
    if let type = UTType(mimeType: attachment.mime), type.conforms(to: .image) {
        return true
    }
    return false
}

private func attachmentFileFormatKind(for attachment: AttachmentDTO) -> AttachmentFileFormatKind {
    let ext = URL(fileURLWithPath: attachment.name).pathExtension.lowercased()
    switch ext {
    case "pdf":
        return .pdf
    case "csv", "xls", "xlsx", "numbers":
        return .sheet
    case "doc", "docx", "pages", "txt", "md", "rtf", "json", "yaml", "yml", "xml", "log", "swift", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "java", "kt", "c", "cpp", "h":
        return .text
    case "zip", "tar", "gz", "rar", "7z":
        return .archive
    default:
        return .other
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
