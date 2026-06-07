import SwiftUI

// MARK: - Tool Symbol Mapper

func toolSymbolName(for name: String) -> String {
    let lowered = name.lowercased()

    if lowered.contains("search") || lowered.contains("browse") || lowered.contains("fetch") || lowered.contains("web") || lowered.contains("url") {
        return "globe"
    }
    if lowered.contains("find") || lowered.contains("glob") || lowered.contains("grep") || lowered.contains("rg") || lowered.contains("locate") || lowered.contains("scan") {
        return "magnifyingglass"
    }
    if lowered.contains("bash") || lowered.contains("shell") || lowered.contains("terminal") || lowered.contains("command") || lowered == "exec" {
        return "terminal"
    }
    if lowered.contains("python") || lowered.contains("script") || lowered.contains("run_code") || lowered.contains("execute") {
        return "chevron.left.forwardslash.chevron.right"
    }
    if lowered.contains("write") || lowered.contains("edit") || lowered.contains("patch") || lowered.contains("create_file") || lowered.contains("update_file") {
        return "pencil"
    }
    if lowered.contains("read") || lowered.contains("open") || lowered.contains("view") || lowered.contains("file") {
        return "doc.text"
    }
    if lowered.contains("git") || lowered.contains("diff") || lowered.contains("commit") || lowered.contains("branch") {
        return "arrow.triangle.branch"
    }
    if lowered.contains("skill") || lowered.contains("docs") || lowered.contains("help") {
        return "book.closed"
    }
    if lowered.contains("memory") || lowered.contains("brain") || lowered.contains("remember") {
        return "brain"
    }
    if lowered.contains("image") || lowered.contains("photo") || lowered.contains("vision") || lowered.contains("screenshot") {
        return "photo"
    }
    return "hammer"
}

// MARK: - Tool Label Mapper

func formattedToolLabel(name: String, args: [String: String]) -> String {
    let lowered = name.lowercased()

    func argValue(_ keys: [String]) -> String? {
        for key in keys {
            if let value = args[key], !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func truncate(_ value: String?, max: Int = 42) -> String {
        let raw = (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !raw.isEmpty else { return "…" }
        if raw.count <= max { return raw }
        return String(raw.prefix(max)) + "…"
    }

    if lowered.contains("search") || lowered.contains("browse") || lowered.contains("fetch") || lowered.contains("web") {
        return "Search \(truncate(argValue(["query", "q", "term", "url"])))"
    }
    if lowered.contains("find") || lowered.contains("glob") || lowered.contains("grep") || lowered.contains("locate") || lowered.contains("scan") {
        return "Find \(truncate(argValue(["pattern", "query", "path", "file"])))"
    }
    if lowered == "terminal" || lowered.contains("bash") || lowered.contains("command") || lowered.contains("shell") || lowered == "exec" {
        return "Run \(truncate(argValue(["command", "cmd", "input"])))"
    }
    if lowered.contains("read") || lowered.contains("open") || lowered.contains("view") || lowered.contains("file") {
        return "Read \(truncate(argValue(["path", "file", "filepath"])))"
    }
    if lowered.contains("write") || lowered.contains("edit") || lowered.contains("patch") || lowered.contains("create_file") || lowered.contains("update_file") {
        return "Edit \(truncate(argValue(["path", "file", "filepath"])))"
    }
    if lowered.contains("git") || lowered.contains("diff") || lowered.contains("commit") || lowered.contains("branch") {
        return "Git \(truncate(argValue(["command", "action"])))"
    }

    return name
}

// MARK: - Activity Summary Builder

func activitySummary(for steps: [ToolCallStep]) -> String {
    if steps.isEmpty { return "Reasoned through the response" }

    let labels = steps.map { $0.name.lowercased() }

    let searchCount = labels.filter { $0.contains("search") || $0.contains("web") || $0.contains("grep") }.count
    let readCount = labels.filter { $0.contains("read") || $0.contains("open") || $0.contains("view") || $0.contains("file") || $0.contains("list") }.count
    let commandCount = labels.filter { $0.contains("bash") || $0.contains("terminal") || $0.contains("command") || $0.contains("shell") || $0.contains("exec") }.count
    let editCount = labels.filter { $0.contains("write") || $0.contains("edit") || $0.contains("patch") }.count
    let exploreCount = labels.filter { $0.contains("find") || $0.contains("glob") || $0.contains("locate") || $0.contains("scan") }.count
    let gitCount = labels.filter { $0.contains("git") || $0.contains("diff") || $0.contains("commit") }.count

    var clauses: [String] = []
    if searchCount > 0 { clauses.append("searched \(searchCount) time\(searchCount == 1 ? "" : "s")") }
    if readCount > 0 { clauses.append("read \(readCount) file\(readCount == 1 ? "" : "s")") }
    if commandCount > 0 { clauses.append("ran \(commandCount) command\(commandCount == 1 ? "" : "s")") }
    if editCount > 0 { clauses.append("edited \(editCount) file\(editCount == 1 ? "" : "s")") }
    if exploreCount > 0 { clauses.append("explored \(exploreCount) director\(exploreCount == 1 ? "y" : "ies")") }
    if gitCount > 0 { clauses.append("ran \(gitCount) git operation\(gitCount == 1 ? "" : "s")") }

    let knownCount = searchCount + readCount + commandCount + editCount + exploreCount + gitCount
    let otherCount = steps.count - knownCount
    if otherCount > 0 { clauses.append("used \(otherCount) other tool\(otherCount == 1 ? "" : "s")") }

    if clauses.isEmpty {
        return "Ran \(steps.count) tool call\(steps.count == 1 ? "" : "s")"
    }
    if clauses.count == 1 {
        return clauses[0].prefix(1).uppercased() + clauses[0].dropFirst()
    }
    if clauses.count == 2 {
        let first = clauses[0].prefix(1).uppercased() + clauses[0].dropFirst()
        return "\(first) and \(clauses[1])"
    }
    let leading = clauses.dropLast().joined(separator: ", ")
    let first = leading.prefix(1).uppercased() + leading.dropFirst()
    return "\(first), and \(clauses.last ?? "")"
}

func activitySummaryIcon(for steps: [ToolCallStep]) -> String {
    let labels = steps.map { $0.name.lowercased() }
    let commandCount = labels.filter { $0.contains("bash") || $0.contains("terminal") || $0.contains("command") }.count
    let searchCount = labels.filter { $0.contains("search") || $0.contains("web") || $0.contains("grep") }.count
    let readCount = labels.filter { $0.contains("read") || $0.contains("file") }.count

    if commandCount >= max(searchCount, readCount), commandCount > 0 { return "terminal" }
    if searchCount >= max(commandCount, readCount), searchCount > 0 { return "magnifyingglass" }
    if readCount > 0 { return "doc.text" }
    return "hammer"
}
