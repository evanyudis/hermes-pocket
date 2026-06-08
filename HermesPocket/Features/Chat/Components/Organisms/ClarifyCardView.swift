import SwiftUI

struct ClarifyCardView: View {
    let clarify: ClarifyPendingDTO
    let clarifyCount: Int
    let onChoice: (_ answer: String) -> Void
    let onDismiss: () -> Void
    let onHeightChange: (CGFloat) -> Void

    @State private var hasResponded = false
    @State private var customAnswer = ""
    @State private var selectedAnswer: String?

    private var choices: [String] {
        clarify.choicesOffered ?? clarify.choices ?? []
    }

    private var isMultiClarify: Bool {
        clarifyCount > 1
    }

    private var canSendCustom: Bool {
        !customAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasResponded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Question + pagination ──
            HStack(alignment: .top, spacing: 12) {
                Text(clarify.question ?? clarify.description ?? "Clarification needed")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineSpacing(6)
                    .tracking(-0.2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    if isMultiClarify {
                        Text("1 of \(clarifyCount)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Unified answers group ──
            VStack(spacing: 0) {
                // Predefined answer options
                ForEach(choices.indices, id: \.self) { index in
                    let choice = choices[index]

                    Button {
                        guard !hasResponded else { return }
                        hasResponded = true
                        selectedAnswer = choice
                        onChoice(choice)
                    } label: {
                        HStack(spacing: 12) {
                            Text(choice)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(hasResponded && selectedAnswer == choice ? .white : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)

                            if hasResponded && selectedAnswer == choice {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            hasResponded && selectedAnswer == choice
                                ? Color.accentColor
                                : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(hasResponded)
                    .opacity(hasResponded && selectedAnswer != choice ? 0.4 : 1)

                    // Divider after each option (last divider sits before custom answer)
                    Divider()
                        .background(.white.opacity(0.1))
                        .padding(.leading, 14)
                }

                // Custom answer row — always present, looks like an option row
                HStack(spacing: 12) {
                    TextField("Custom answer...", text: $customAnswer, axis: .vertical)
                        .font(.system(size: 18, weight: .regular))
                        .lineLimit(1...3)
                        .foregroundStyle(.primary)
                        .disabled(hasResponded)

                    Button {
                        guard canSendCustom else { return }
                        let answer = customAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                        hasResponded = true
                        selectedAnswer = answer
                        onChoice(answer)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(canSendCustom ? Color.white : Color.white.opacity(0.35))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSendCustom)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    hasResponded && selectedAnswer == customAnswer.trimmingCharacters(in: .whitespacesAndNewlines) && !customAnswer.isEmpty
                        ? Color.accentColor
                        : Color.clear
                )
            }
            .liquidGlass(RoundedRectangle(cornerRadius: 16, style: .continuous), preset: .panel)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .liquidGlass(RoundedRectangle(cornerRadius: 24, style: .continuous), preset: .composer)
        .padding(.horizontal, 26)
        .padding(.bottom, 20)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { onHeightChange(proxy.size.height) }
                    .onChange(of: proxy.size.height) { _, h in onHeightChange(h) }
            }
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
