import SwiftUI

struct ChatInputView: View {
    @Binding var messageText: String
    let onSendTapped: () -> Void

    @State private var showAttachmentOptions = false

    var body: some View {
        VStack {

            HStack(spacing: 12) {
                // Plus button for attachments
                Button(action: {
                    showAttachmentOptions.toggle()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.loopedPrimary)
                }

                // Text input field
                HStack(spacing: 8) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(1...6)
                        .textFieldStyle(PlainTextFieldStyle())

                    Spacer()

                    HStack(spacing: 16) {
                        // Camera button
                        Button(action: {
                            // TODO: Implement camera functionality
                        }) {
                            Image(systemName: "camera")
                                .font(.system(size: 20))
                                .foregroundColor(.loopedPrimary)
                        }

                        // Microphone button
                        Button(action: {
                            // TODO: Implement voice recording functionality
                        }) {
                            Image(systemName: "mic")
                                .font(.system(size: 20))
                                .foregroundColor(.loopedPrimary)
                        }

                        // Send button - only show when there's text
                        if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: onSendTapped) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.loopedPrimary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.loopedMessageMutedColor)
                        .shadow(color: .black.opacity(0.10), radius: 1, x: 0, y: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 12)
        }
        .background(Color.loopedBackground)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .actionSheet(isPresented: $showAttachmentOptions) {
            ActionSheet(
                title: Text("Add Attachment"),
                message: Text("Choose an option"),
                buttons: [
                    .default(Text("Photo Library")) {
                        // TODO: Implement photo library picker
                    },
                    .default(Text("Camera")) {
                        // TODO: Implement camera capture
                    },
                    .default(Text("Document")) {
                        // TODO: Implement document picker
                    },
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Spacer()

        // Preview with empty text
        ChatInputView(
            messageText: .constant(""),
            onSendTapped: {}
        )

        // Preview with text (showing send button)
        ChatInputView(
            messageText: .constant("This is a sample message"),
            onSendTapped: {}
        )
    }
    .background(Color.loopedBackground)
}
