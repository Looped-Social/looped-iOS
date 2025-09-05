import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.channels) { channel in
                    NavigationLink(destination: ChatView(channel: channel)) {
                        ChannelRowView(channel: channel)
                    }
                }
            }
            .navigationTitle("Messages")
            .task {
                await viewModel.loadChannels()
            }
        }
    }
}

struct ChannelRowView: View {
    let channel: Channel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(channel.name)
                    .font(.headline)
                Spacer()
                Image(systemName: channel.isPublic ? "globe" : "lock")
                    .foregroundColor(.secondary)
            }
            
            Text("\(channel.memberCount) members")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct ChatView: View {
    let channel: Channel
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    
    var body: some View {
        VStack {
            List {
                ForEach(viewModel.messages) { message in
                    MessageRowView(message: message)
                }
            }
            
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    Task {
                        await viewModel.sendMessage(messageText, to: channel)
                        messageText = ""
                    }
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMessages(for: channel)
        }
    }
}

struct MessageRowView: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.senderDisplayName ?? "Anonymous")
                    .font(.caption)
                    .bold()
                Spacer()
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(message.content)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MessagesView()
}