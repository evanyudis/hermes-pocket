import SwiftUI

// MARK: - Parsed tool result segments

enum MessageSegment: Equatable {
    case text(String)
    case toolResult(ToolResultData)
}

enum ToolResultData: Equatable {
    case webSearch(results: [WebSearchResult])
    case unknown(source: String, raw: String)

    struct WebSearchResult: Equatable {
        let title: String
        let url: String
        let description: String
        let position: Int
    }
}

// MARK: - Parser

struct ToolResultParser {

    /// Splits message text into segments of plain text and tool results.
    static func parse(_ text: String) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        let pattern = #"<untrusted_tool_result\s+source="([^"]*)">([\s\S]*?)</untrusted_tool_result>"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        if matches.isEmpty {
            return [.text(text)]
        }

        var lastEnd = 0

        for match in matches {
            // Text before this match
            if match.range.location > lastEnd {
                let before = nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(.text(before))
                }
            }

            let source = nsText.substring(with: match.range(at: 1))
            let inner = nsText.substring(with: match.range(at: 2))
            let data = parseToolResult(source: source, inner: inner)
            segments.append(.toolResult(data))

            lastEnd = match.range.upperBound
        }

        // Remaining text after last match
        if lastEnd < nsText.length {
            let after = nsText.substring(with: NSRange(location: lastEnd, length: nsText.length - lastEnd))
            if !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.text(after))
            }
        }

        return segments
    }

    private static func parseToolResult(source: String, inner: String) -> ToolResultData {
        switch source {
        case "web_search":
            return parseWebSearch(inner)
        default:
            return .unknown(source: source, raw: inner)
        }
    }

    private static func parseWebSearch(_ json: String) -> ToolResultData {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = root["data"] as? [String: Any],
              let web = dataObj["web"] as? [[String: Any]] else {
            return .unknown(source: "web_search", raw: json)
        }

        let results: [ToolResultData.WebSearchResult] = web.compactMap { item in
            guard let title = item["title"] as? String,
                  let url = item["url"] as? String else { return nil }
            let description = item["description"] as? String ?? ""
            let position = item["position"] as? Int ?? 0
            return .init(title: title, url: url, description: description, position: position)
        }

        return .webSearch(results: results)
    }
}

// MARK: - Card view

struct ToolResultCardView: View {
    let data: ToolResultData

    var body: some View {
        switch data {
        case .webSearch(let results):
            WebSearchResultCard(results: results)
        case .unknown(let source, _):
            // Don't render unknown tool results — they're noise
            EmptyView()
        }
    }
}

// MARK: - Web search card

private struct WebSearchResultCard: View {
    let results: [ToolResultData.WebSearchResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "74C0FC"))
                Text("Search Results")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Result rows
            ForEach(Array(results.prefix(5).enumerated()), id: \.offset) { _, result in
                SearchResultRow(result: result)
                if result != results.prefix(5).last {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                        .padding(.horizontal, 12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SearchResultRow: View {
    let result: ToolResultData.WebSearchResult

    private var domain: String {
        URL(string: result.url)?.host ?? result.url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: "74C0FC"))
                .lineLimit(2)

            Text(domain)
                .font(.caption2)
                .foregroundStyle(Color(white: 0.5))

            if !result.description.isEmpty {
                Text(result.description)
                    .font(.caption)
                    .foregroundStyle(Color(white: 0.55))
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
