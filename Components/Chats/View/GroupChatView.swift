//
//  GroupChatView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct GroupChatView: View {
    let project: Project
    let currentUserPhone: String?
    let role: UserRole
    
    @StateObject private var viewModel: GroupChatViewModel
    @Environment(\.compatibleDismiss) private var dismiss
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var showingVideoPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedDocument: URL?
    @State private var selectedVideo: URL?
    @State private var showingAttachmentOptions = false
    @State private var showingMentionPicker = false
    @State private var mentionText = ""
    
    init(project: Project, currentUserPhone: String?, role: UserRole) {
        self.project = project
        self.currentUserPhone = currentUserPhone
        self.role = role
        self._viewModel = StateObject(wrappedValue: GroupChatViewModel(project: project, currentUserPhone: currentUserPhone, role: role))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages List
                messagesListView
                
                // Attachment Preview
                if selectedImage != nil || selectedDocument != nil || selectedVideo != nil {
                    attachmentPreviewView
                }
                
                // Input Area
                inputAreaView
            }
            .navigationTitle("Project Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Info") {
                        // TODO: Show group info
                    }
                }
            }
            .confirmationDialog("Attach Media", isPresented: $showingAttachmentOptions) {
                Button("Photo") {
                    showingImagePicker = true
                }
                Button("Video") {
                    showingVideoPicker = true
                }
                Button("Document") {
                    showingDocumentPicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingVideoPicker) {
                VideoPicker(selectedVideo: $selectedVideo)
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.pdf, .plainText, .rtf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedDocument = url
                    }
                case .failure(let error):
                    print("Document picker error: \(error)")
                }
            }
            .task {
                await viewModel.loadGroupMessages()
            }
        }
    }
    
    // MARK: - Messages List View
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading messages...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                    } else if viewModel.messages.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No messages yet")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Start a conversation with your project team")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ForEach(viewModel.messages) { message in
                            GroupMessageBubble(message: message, currentUserPhone: currentUserPhone, currentUserRole: role, projectMembers: viewModel.projectMembers)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) {
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Attachment Preview View
    private var attachmentPreviewView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            Button(action: {
                                selectedImage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(.black.opacity(0.6)))
                            }
                            .offset(x: 8, y: -8),
                            alignment: .topTrailing
                        )
                }
                
                if let document = selectedDocument {
                    DocumentPreview(url: document) {
                        selectedDocument = nil
                    }
                }
                
                if let video = selectedVideo {
                    VideoPreview(url: video) {
                        selectedVideo = nil
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Input Area View
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Mention Button
                Button(action: {
                    showingMentionPicker = true
                }) {
                    Image(systemName: "at")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                // Attachment Button
                Button(action: {
                    showingAttachmentOptions = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                // Text Input
                HStack {
                    TextField("Message @team", text: $messageText, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(1...4)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                // Send Button
                Button(action: sendMessage) {
                    if viewModel.isSendingMessage {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(messageText.isEmpty && selectedImage == nil && selectedDocument == nil && selectedVideo == nil ? .gray : .blue)
                    }
                }
                .disabled(messageText.isEmpty && selectedImage == nil && selectedDocument == nil && selectedVideo == nil || viewModel.isSendingMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showingMentionPicker) {
            MentionPickerView(
                projectMembers: viewModel.projectMembers,
                onMentionSelected: { member in
                    messageText += "@\(member.name) "
                }
            )
        }
    }
    
    // MARK: - Send Message
    private func sendMessage() {
        guard !messageText.isEmpty || selectedImage != nil || selectedDocument != nil || selectedVideo != nil else { return }
        
        // Determine senderId based on role
        let senderId: String
        if role == .ADMIN {
            senderId = "Admin"
        } else {
            senderId = currentUserPhone ?? UserDefaults.standard.string(forKey: "currentUserPhone") ?? ""
        }
        
        Task {
            var mediaUrls: [String]? = nil
            
            // Upload media files if any
            if selectedImage != nil || selectedDocument != nil || selectedVideo != nil {
                mediaUrls = await uploadSelectedMedia()
            }
            
            // Extract mentions from message text
            let mentions = extractMentions(from: messageText)
            
            let message = Message(
                senderId: senderId,
                text: messageText.isEmpty ? nil : messageText,
                media: mediaUrls,
                timestamp: Date(),
                isRead: false,
                type: determineMessageType(),
                replyTo: nil,
                mentions: mentions.isEmpty ? nil : mentions,
                isGroupMessage: true
            )
            
            await MainActor.run {
                viewModel.sendMessage(message)
                
                // Clear input
                messageText = ""
                selectedImage = nil
                selectedDocument = nil
                selectedVideo = nil
            }
        }
    }
    
    private func extractMentions(from text: String) -> [String] {
        let mentionPattern = "@([A-Za-z0-9_]+)"
        let regex = try? NSRegularExpression(pattern: mentionPattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex?.matches(in: text, range: range) ?? []
        
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
            return nil
        }
    }
    
    
    private func uploadSelectedMedia() async -> [String]? {
        var mediaUrls: [String] = []
        
        if let image = selectedImage {
            do {
                let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
                let path = "group_chat_media/\(UUID().uuidString).jpg"
                let url = try await viewModel.uploadMediaAsync(imageData, path: path)
                mediaUrls.append(url)
            } catch {
                print("Error uploading image: \(error)")
            }
        }
        
        if let video = selectedVideo {
            do {
                let videoData = try await loadDataAsync(from: video)
                let path = "group_chat_media/\(UUID().uuidString).mp4"
                let url = try await viewModel.uploadMediaAsync(videoData, path: path)
                mediaUrls.append(url)
            } catch {
                print("Error uploading video: \(error)")
            }
        }
        
        if let document = selectedDocument {
            do {
                let documentData = try await loadDataAsync(from: document)
                let path = "group_chat_media/\(UUID().uuidString)_\(document.lastPathComponent)"
                let url = try await viewModel.uploadMediaAsync(documentData, path: path)
                mediaUrls.append(url)
            } catch {
                print("Error uploading document: \(error)")
            }
        }
        
        return mediaUrls.isEmpty ? nil : mediaUrls
    }
    
    private func determineMessageType() -> Message.MessageType {
        if selectedImage != nil {
            return .image
        } else if selectedVideo != nil {
            return .video
        } else if selectedDocument != nil {
            return .file
        } else {
            return .text
        }
    }
}

// MARK: - Group Message Bubble
struct GroupMessageBubble: View {
    let message: Message
    let currentUserPhone: String?
    let currentUserRole: UserRole
    let projectMembers: [ProjectMember]
    
    init(message: Message, currentUserPhone: String?, currentUserRole: UserRole, projectMembers: [ProjectMember]) {
        self.message = message
        self.currentUserPhone = currentUserPhone
        self.currentUserRole = currentUserRole
        self.projectMembers = projectMembers
    }
    
    private var isFromCurrentUser: Bool {
        // For admin, check if senderId is "Admin" and current user is admin
        if message.senderId == "Admin" {
            return currentUserRole == .ADMIN
        } else {
            // For regular users, check phone number match
            let currentPhone = currentUserPhone ?? UserDefaults.standard.string(forKey: "currentUserPhone") ?? ""
            return message.senderId == currentPhone
        }
    }
    
    private var senderName: String {
        if let member = projectMembers.first(where: { $0.phoneNumber == message.senderId }) {
            return member.name
        }
        return "Unknown"
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name for group messages
                if !isFromCurrentUser {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                // Message Content
                if let media = message.media, !media.isEmpty {
                    MediaView(media: media, type: message.type)
                } else if let text = message.text {
                    Text(highlightedText(text))
                        .font(.body)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isFromCurrentUser ? Color.secondary : Color(.systemGray5))
                        )
                }
                
                // Timestamp and Read Status
                HStack(spacing: 4) {
                    Text(timeString(from: message.timestamp ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isFromCurrentUser && message.isRead {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private func highlightedText(_ text: String) -> String {
        var attributedString = String(text)
        
        // Highlight mentions
        let mentionPattern = "@([A-Za-z0-9_]+)"
        let regex = try? NSRegularExpression(pattern: mentionPattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex?.matches(in: text, range: range) ?? []
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                let mentionRange = attributedString.range(of: String(text[range]))!
                attributedString[mentionRange].foregroundColor = .blue
                attributedString[mentionRange].font = .body.bold()
            }
        }
        
        return attributedString
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Project Member
struct ProjectMember: Identifiable, Hashable {
    let id: String
    let name: String
    let phoneNumber: String
    let role: UserRole
}

// MARK: - Mention Picker View
struct MentionPickerView: View {
    let projectMembers: [ProjectMember]
    let onMentionSelected: (ProjectMember) -> Void
    @Environment(\.compatibleDismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredMembers: [ProjectMember] {
        if searchText.isEmpty {
            return projectMembers
        } else {
            return projectMembers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            List(filteredMembers) { member in
                Button(action: {
                    onMentionSelected(member)
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text(member.role.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("@\(member.name)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .searchable(text: $searchText, prompt: "Search team members")
            .navigationTitle("Mention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    GroupChatView(
        project: Project.sampleData[0],
        currentUserPhone: "9876543210",
        role: .USER
    )
}
