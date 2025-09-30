//
//  IndividualChatView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct IndividualChatView: View {
    let participant: ChatParticipant
    let project: Project
    
    @StateObject private var viewModel = IndividualChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var showingVideoPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedDocument: URL?
    @State private var selectedVideo: URL?
    @State private var showingAttachmentOptions = false
    
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
            .navigationTitle(participant.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Add call functionality
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
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
        }
    }
    
    // MARK: - Messages List View
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
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
                    TextField("Message", text: $messageText, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(1...4)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                // Send Button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(messageText.isEmpty && selectedImage == nil && selectedDocument == nil && selectedVideo == nil ? .gray : .blue)
                }
                .disabled(messageText.isEmpty && selectedImage == nil && selectedDocument == nil && selectedVideo == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Send Message
    private func sendMessage() {
        guard !messageText.isEmpty || selectedImage != nil || selectedDocument != nil || selectedVideo != nil else { return }
        
        let message = Message(
            senderId: UserDefaults.standard.string(forKey: "currentUserPhone") ?? "",
            text: messageText.isEmpty ? nil : messageText,
            media: createMediaArray(),
            timestamp: Date(),
            isRead: false,
            type: determineMessageType(),
            replyTo: nil
        )
        
        viewModel.sendMessage(message)
        
        // Clear input
        messageText = ""
        selectedImage = nil
        selectedDocument = nil
        selectedVideo = nil
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
    
    private func createMediaArray() -> [String]? {
        var mediaUrls: [String] = []
        
        if let image = selectedImage {
            // TODO: Upload image to Firebase Storage and get URL
            mediaUrls.append("image_url_placeholder")
        }
        
        if let video = selectedVideo {
            // TODO: Upload video to Firebase Storage and get URL
            mediaUrls.append("video_url_placeholder")
        }
        
        if let document = selectedDocument {
            // TODO: Upload document to Firebase Storage and get URL
            mediaUrls.append("document_url_placeholder")
        }
        
        return mediaUrls.isEmpty ? nil : mediaUrls
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    
    private var isFromCurrentUser: Bool {
        message.senderId == UserDefaults.standard.string(forKey: "currentUserPhone")
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message Content
                if let media = message.media, !media.isEmpty {
                    MediaView(media: media, type: message.type)
                } else if let text = message.text {
                    Text(text)
                        .font(.body)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isFromCurrentUser ? Color.blue : Color(.systemGray5))
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
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Media View
struct MediaView: View {
    let media: [String]
    let type: Message.MessageType
    
    var body: some View {
        switch type {
        case .image:
            if let imageUrl = media.first {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 200, height: 200)
                        .overlay(
                            ProgressView()
                        )
                }
            }
        case .video:
            if let videoUrl = media.first {
                VideoThumbnailView(url: URL(string: videoUrl))
            }
        case .file:
            if let fileUrl = media.first {
                DocumentView(url: URL(string: fileUrl))
            }
        case .text:
            EmptyView()
        }
    }
}

// MARK: - Document Preview
struct DocumentPreview: View {
    let url: URL
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("Document")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Video Preview
struct VideoPreview: View {
    let url: URL
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "video.fill")
                .font(.system(size: 24))
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("Video")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Video Thumbnail View
struct VideoThumbnailView: View {
    let url: URL?
    
    var body: some View {
        VStack {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .background(Circle().fill(.black.opacity(0.6)))
        }
        .frame(maxWidth: 200, maxHeight: 200)
        .background(Color(.systemGray4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Document View
struct DocumentView: View {
    let url: URL?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url?.lastPathComponent ?? "Document")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("Tap to open")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    IndividualChatView(
        participant: ChatParticipant(
            id: "123",
            name: "John Doe",
            phoneNumber: "9876543210",
            role: .APPROVER,
            isOnline: true,
            lastSeen: Date()
        ),
        project: Project.sampleData[0]
    )
}
