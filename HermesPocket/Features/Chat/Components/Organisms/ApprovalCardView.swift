import SwiftUI

struct ApprovalCardView: View {
    let approval: ApprovalPendingDTO
    let pendingApprovalCount: Int
    let onRespond: (_ choice: String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Approval Required", systemImage: "exclamationmark.shield")
                    .font(.headline)
                Spacer()
                if pendingApprovalCount > 1 {
                    Text("1 of \(pendingApprovalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let description = approval.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
            }

            if let command = approval.command, !command.isEmpty {
                Text(command)
                    .font(.footnote.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Button("Once") { onRespond("once") }
                Button("Session") { onRespond("session") }
                Button("Always") { onRespond("always") }
                Button("Deny", role: .destructive) { onRespond("deny") }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), preset: .banner)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
