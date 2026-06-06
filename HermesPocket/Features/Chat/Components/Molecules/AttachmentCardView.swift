import SwiftUI

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

    var body: some View {
        let cornerRadius: CGFloat = 8

        Group {
            if attachment.mime.hasPrefix("image/"),
               let image = UIImage(contentsOfFile: attachment.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(attachmentFileFormatGradient(for: attachment, palette: palette))
                    .overlay(
                        Image(systemName: attachmentFileFormatIcon(for: attachment))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    )
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

enum AttachmentGradientPalette {
    case muted
    case vibrant
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
    switch palette {
    case .muted:
        let base: Color
        switch attachmentFileFormatKind(for: attachment) {
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
        switch attachmentFileFormatKind(for: attachment) {
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

private extension Color {
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
