import SwiftUI

struct LiveToolCallingView: View {
    let toolCall: ActiveToolCall

    var body: some View {
        ShimmeringTextView(text: statusText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusText: String {
        Self.mapStatus(toolCall)
    }

    // MARK: - Status mapper

    static func mapStatus(_ tool: ActiveToolCall) -> String {
        let name = tool.name.lowercased()
        let preview = tool.preview?.trimmingCharacters(in: .whitespacesAndNewlines)
        let args = tool.args

        // Use backend preview directly when it's meaningful
        // (skip generic/done markers)
        if let preview, !preview.isEmpty,
           preview.lowercased() != "done",
           preview.lowercased() != "running" {
            return preview
        }

        // Build from name + args
        let path = args["path"]
            ?? args["file_path"]
            ?? args["filename"]
            ?? args["file"]

        let query = args["query"]
            ?? args["search"]
            ?? args["q"]

        let command = args["command"]
            ?? args["cmd"]
            ?? args["script"]

        if name.contains("search") {
            if let query, !query.isEmpty {
                return "Searching for \(query)"
            }
            if let preview { return "Searching for \(preview)" }
            return "Searching"
        }

        if name.contains("bash") || name.contains("execute") || name.contains("command") {
            if let command, !command.isEmpty {
                // Truncate long commands
                let display = command.count > 60 ? String(command.prefix(57)) + "…" : command
                return "Running \(display)"
            }
            if let preview { return preview }
            return "Running command"
        }

        if name.contains("read") {
            if let path, !path.isEmpty { return "Reading \(path)" }
            if let preview { return preview }
            return "Reading file"
        }

        if name.contains("write") || name.contains("create") {
            if let path, !path.isEmpty { return "Writing to \(path)" }
            if let preview { return preview }
            return "Writing file"
        }

        if name.contains("edit") || name.contains("patch") {
            if let path, !path.isEmpty { return "Editing \(path)" }
            if let preview { return preview }
            return "Editing file"
        }

        if name.contains("explore") || name.contains("find") || name.contains("list") || name.contains("glob") || name.contains("directory") {
            if let path, !path.isEmpty { return "Exploring \(path)" }
            if let preview { return preview }
            return "Exploring files"
        }

        // Fallback: use preview or name
        if let preview, !preview.isEmpty { return preview }
        return "Working"
    }
}
