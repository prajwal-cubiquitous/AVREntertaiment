//
//  ExpenseChatView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import SwiftUI

struct ExpenseChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ExpenseChatViewModel
    @State private var messageText = ""
    @State private var showingMediaPicker = false
    
    let expense: Expense

    let userPhoneNumber: String
    let projectId: String
    let role : UserRole
    init(expense: Expense, userPhoneNumber: String, projectId: String, role: UserRole) {
        self.expense = expense

        self.userPhoneNumber = userPhoneNumber
        self._viewModel = StateObject(wrappedValue: ExpenseChatViewModel(
            expense: expense,
            userPhoneNumber: userPhoneNumber,
            projectID: projectId
        ))
        self.projectId = projectId
        self.role = role
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Chat Messages
                chatMessagesView
                
                // Message Input
                messageInputView
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadChatMessages()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Expense Chat")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("₹\(String(format: "%.2f", expense.amount)) • \(expense.department)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                // More options
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Chat Messages View
    private var chatMessagesView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.small) {
                ForEach(viewModel.messages) { message in
                    ChatMessageBubble(
                        message: message,
                        isFromCurrentUser: message.senderId == userPhoneNumber
                    )
                    .id(message.id)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Message Input View
    private var messageInputView: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            // Media Button
            Button {
                showingMediaPicker = true
            } label: {
                Image(systemName: "paperclip")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Text Input
            HStack {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                
                if !messageText.isEmpty {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 0.5),
            alignment: .top
        )
        .sheet(isPresented: $showingMediaPicker) {
            // Media picker implementation
            Text("Media Picker")
        }
    }
    
    // MARK: - Helper Methods
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = ExpenseChat(
            textMessage: messageText,
            mediaURL: [],
            mention: [],
            senderId: userPhoneNumber,
            senderRole: role
        )
        
        viewModel.sendMessage(message)
        messageText = ""
    }
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: ExpenseChat
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender Name (only show for other users)
                if !isFromCurrentUser {
                    Text(message.senderRole.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                }
                
                // Message Text
                Text(message.textMessage)
                    .font(.body)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isFromCurrentUser ? Color.accentColor : Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                
                // Media URLs
                if !message.mediaURL.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                        ForEach(message.mediaURL, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 100)
                                    .cornerRadius(8)
                                    .overlay(
                                        ProgressView()
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                }
                
                // Mentions
                if !message.mention.isEmpty {
                    HStack {
                        ForEach(message.mention, id: \.self) { mention in
                            Text("@\(mention)")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                }
                
                // Timestamp
                Text(formatTimestamp(message.timeStamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.medium)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ExpenseChatView(
        expense: Expense.sampleData[0],
        userPhoneNumber: "+919876543210", projectId: "I1kHn5UTOs6FCBA33Ke5", role: .ADMIN
    )
}
