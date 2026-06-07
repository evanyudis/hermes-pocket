import SwiftUI

// MARK: - Chain of Thought View

/// Notification posted when chain-of-thought expands, so ChatView can scroll to it.
extension Notification.Name {
    static let chainOfThoughtExpanded = Notification.Name("chainOfThoughtExpanded")
}

/// Collapsible summary of tool calls that occurred during an assistant turn.
/// Collapsed by default — shows a one-line summary with chevron.
/// Expands to show each step with icon, label, and status.
struct ChainOfThoughtView: View {
    let steps: [ToolCallStep]
    let messageID: UUID
    @State private var isExpanded: Bool = false

    var body: some View {
        // Don't render anything if there are no steps
        if steps.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header — always visible, tap to toggle
                HStack(spacing: 10) {
                    Image(systemName: activitySummaryIcon(for: steps))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(white: 0.58))

                    Text(activitySummary(for: steps))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(white: 0.58))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                    if isExpanded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            NotificationCenter.default.post(
                                name: .chainOfThoughtExpanded,
                                object: nil,
                                userInfo: ["messageID": messageID]
                            )
                        }
                    }
                }

                // Expanded steps list
                if isExpanded {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            ToolStepRow(step: step, isLast: index == steps.count - 1)
                        }
                    }
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

// MARK: - Tool Step Row

private struct ToolStepRow: View {
    let step: ToolCallStep
    let isLast: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            StepIndicator(status: step.status)
                .frame(width: 12, height: 12)

            // Tool icon
            Image(systemName: toolSymbolName(for: step.name))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(white: 0.58))
                .frame(width: 16)

            // Label
            Text(formattedToolLabel(name: step.name, args: step.args))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(white: 0.58))
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.leading, 6)
        // Vertical connector line
        .overlay(alignment: .leading) {
            if !isLast {
                Rectangle()
                    .fill(Color(white: 0.2).opacity(0.3))
                    .frame(width: 1)
                    .offset(x: -0.5)
                    .offset(x: 11) // align with indicator center
            }
        }
    }
}

// MARK: - Step Status Indicator

private struct StepIndicator: View {
    let status: ToolCallStep.Status

    var body: some View {
        Group {
            switch status {
            case .complete:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.58))
            case .error:
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
    }
}
