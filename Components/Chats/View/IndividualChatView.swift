//
//  IndividualChatView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Global Helper Functions
func loadDataAsync(from url: URL) async throws -> Data {
    return try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                continuation.resume(returning: data)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

struct IndividualChatView: View {
    let participant: ChatParticipant
    let project: Project
    let role: UserRole
    let currentUserPhoneNumber: String?
    
    @StateObject private var viewModel : IndividualChatViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: FirebaseAuthService
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var showingVideoPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedDocument: URL?
    @State private var selectedVideo: URL?
    @State private var showingAttachmentOptions = false
    
    init(participant: ChatParticipant, project: Project, role: UserRole, currentUserPhoneNumber: String?){
        self.participant = participant
        self.project = project
        self.role = role
        self.currentUserPhoneNumber = currentUserPhoneNumber
        self._viewModel = StateObject(wrappedValue: IndividualChatViewModel(currentUserPhone: currentUserPhoneNumber, role: role))
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
            .navigationTitle(participant.displayName)
            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button(action: {
//                        // TODO: Add call functionality
//                    }) {
//                        Image(systemName: "phone.fill")
//                            .font(.system(size: 16, weight: .medium))
//                            .foregroundColor(.blue)
//                    }
//                }
//            }
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
            .onAppear {
                // Set auth service in view model
                viewModel.setAuthService(authService)
                
                Task {
                    await viewModel.loadMessages(for: participant, project: project)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
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
                            Image(systemName: "message.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No messages yet")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Start a conversation with \(participant.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message, currentUserPhone: currentUserPhoneNumber, currentUserRole: role)
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
    }
    
    // MARK: - Send Message
    private func sendMessage() {
        guard !messageText.isEmpty || selectedImage != nil || selectedDocument != nil || selectedVideo != nil else { return }
        
        // Determine senderId based on role
        let senderId: String
        if role == .ADMIN {
            senderId = "Admin"
        } else {
            senderId = currentUserPhoneNumber ?? UserDefaults.standard.string(forKey: "currentUserPhone") ?? ""
        }
        
        Task {
            var mediaUrls: [String]? = nil
            
            // Upload media files if any
            if selectedImage != nil || selectedDocument != nil || selectedVideo != nil {
                mediaUrls = await uploadSelectedMedia()
                
                // Check if upload was successful
                if mediaUrls == nil || mediaUrls?.isEmpty == true {
                    await MainActor.run {
                        viewModel.errorMessage = "Failed to upload media files"
                    }
                    return
                }
            }
            
            let message = Message(
                senderId: senderId,
                text: messageText.isEmpty ? nil : messageText,
                media: mediaUrls,
                timestamp: Date(),
                isRead: false,
                type: determineMessageType(),
                replyTo: nil,
                mentions: nil,
                isGroupMessage: false
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
    
    private func uploadSelectedMedia() async -> [String]? {
        var mediaUrls: [String] = []
        
        if let image = selectedImage {
            do {
                let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
                let path = "chat_media/\(UUID().uuidString).jpg"
                let url = try await viewModel.uploadMediaAsync(imageData, path: path)
                mediaUrls.append(url)
            } catch {
                print("Error uploading image: \(error)")
            }
        }
        
        if let video = selectedVideo {
            do {
                let videoData = try await loadDataAsync(from: video)
                let path = "chat_media/\(UUID().uuidString).mp4"
                let url = try await viewModel.uploadMediaAsync(videoData, path: path)
                mediaUrls.append(url)
            } catch {
                print("Error uploading video: \(error)")
            }
        }
        
        if let document = selectedDocument {
            do {
                let documentData = try await loadDataAsync(from: document)
                let path = "chat_media/\(UUID().uuidString)_\(document.lastPathComponent)"
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
    let currentUserPhone: String?
    let currentUserRole: UserRole
    
    init(message: Message, currentUserPhone: String? = nil, currentUserRole: UserRole = .USER) {
        self.message = message
        self.currentUserPhone = currentUserPhone
        self.currentUserRole = currentUserRole
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
    @State private var showingImageViewer = false
    @State private var showingDocumentViewer = false
    
    var body: some View {
        switch type {
        case .image:
            if let imageUrl = media.first, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            showingImageViewer = true
                        }
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 200, height: 200)
                        .overlay(
                            ProgressView()
                        )
                }
                .sheet(isPresented: $showingImageViewer) {
                    ImageViewer(url: url)
                }
            }
        case .video:
            if let videoUrl = media.first {
                VideoThumbnailView(url: URL(string: videoUrl))
            }
        case .file:
            if let fileUrl = media.first, let url = URL(string: fileUrl) {
                DocumentView(url: url) {
                    showingDocumentViewer = true
                }
                .sheet(isPresented: $showingDocumentViewer) {
                    DocumentViewer(url: url)
                }
            }
        case .text:
            EmptyView()
        }
    }
}

// MARK: - Image Viewer
struct ImageViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Document Viewer
struct DocumentViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if url.pathExtension.lowercased() == "pdf" {
                    PDFViewer(url: url)
                } else {
                    // For other document types, show a web view or download option
                    VStack(spacing: 20) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                        
                        Text(url.lastPathComponent)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("Tap to download and view")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Download") {
                            // Handle download asynchronously
                            Task {
                                do {
                                    let data = try await loadDataAsync(from: url)
                                    // Save to documents or share
                                    print("Downloading document: \(url.lastPathComponent)")
                                } catch {
                                    print("Error downloading document: \(error)")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - PDF Viewer
struct PDFViewer: View {
    let url: URL
    @State private var pdfData: Data?
    
    var body: some View {
        VStack {
            if let data = pdfData {
                // For now, show a placeholder. In a real app, you'd use a PDF rendering library
                VStack(spacing: 20) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                    
                    Text("PDF Document")
                        .font(.headline)
                    
                    Text("PDF viewing requires additional implementation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open in Safari") {
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ProgressView("Loading PDF...")
            }
        }
        .task {
            do {
                pdfData = try await loadDataAsync(from: url)
            } catch {
                print("Error loading PDF: \(error)")
            }
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
    let onTap: (() -> Void)?
    
    init(url: URL?, onTap: (() -> Void)? = nil) {
        self.url = url
        self.onTap = onTap
    }
    
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
        .onTapGesture {
            onTap?()
        }
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
        project: Project.sampleData[0],
        role: .ADMIN,
        currentUserPhoneNumber: nil
    )
}
