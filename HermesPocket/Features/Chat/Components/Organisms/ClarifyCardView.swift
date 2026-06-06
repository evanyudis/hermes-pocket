import SwiftUI

struct ClarifyCardView: View {
    let clarify: ClarifyPendingDTO
    @Binding var draft: String
    let onChoice: (_ choice: String) -> Void
    let onReply: () -> Void

    private var choices: [String] {
        clarify.choicesOffered ?? clarify.choices ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Clarification Needed", systemImage: "questionmark.bubble")
                .font(.headline)

            Text(clarify.question ?? clarify.description ?? "Reply to continue.")
                .font(.subheadline)

            if !choices.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(choices, id: \.self) { choice in
                            Button(choice) {
                                onChoice(choice)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Type your response", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button("Reply", action: onReply)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), preset: .banner)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
