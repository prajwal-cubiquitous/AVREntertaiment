//
//  ExpenseChatView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import SwiftUI
import PhotosUI
import FirebaseStorage

struct ExpenseChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ExpenseChatViewModel
    @State private var messageText = ""
    @State private var showingMediaPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isUploadingImage = false
    @State private var uploadProgress: Double = 0.0
    @State private var showingImageViewer = false
    @State private var selectedImageURL: String = ""
    @State private var selectedImageIndex: Int = 0
    
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
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                await loadSelectedImages(newPhotos)
            }
        }
        .sheet(isPresented: $showingImageViewer) {
            ImageViewerView(
                imageURL: selectedImageURL,
                imageIndex: selectedImageIndex,
                allImageURLs: viewModel.messages.flatMap { $0.mediaURL }
            )
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
                        isFromCurrentUser: message.senderId == userPhoneNumber,
                        onImageTapped: { url, index in
                            selectedImageURL = url
                            selectedImageIndex = index
                            showingImageViewer = true
                        }
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
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .images
            ) {
                HStack(spacing: 4) {
                    if isUploadingImage {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperclip")
                            .font(.title2)
                    }
                }
                .foregroundColor(.secondary)
            }
            .disabled(isUploadingImage)
            
            // Text Input
            VStack(spacing: 8) {
                // Selected Images Preview
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipped()
                                        .cornerRadius(8)
                                    
                                    Button {
                                        selectedImages.remove(at: index)
                                        selectedPhotos.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 70)
                }
                
                HStack {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                    
                    if !messageText.isEmpty || !selectedImages.isEmpty {
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
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
        .overlay(
            // Upload Progress Bar
            VStack {
                if isUploadingImage {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 2)
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                }
            },
            alignment: .top
        )
    }
    
    // MARK: - Helper Methods
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty else { return }
        
        if !selectedImages.isEmpty {
            Task {
                await uploadAndSendImages()
            }
        } else {
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
    
    private func loadSelectedImages(_ photos: [PhotosPickerItem]) async {
        guard !photos.isEmpty else { return }
        
        var loadedImages: [UIImage] = []
        
        for photo in photos {
            do {
                guard let data = try await photo.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    continue
                }
                loadedImages.append(image)
            } catch {
                print("Error loading image: \(error.localizedDescription)")
            }
        }
        
        selectedImages = loadedImages
    }
    
    private func uploadAndSendImages() async {
        guard !selectedImages.isEmpty else { return }
        
        isUploadingImage = true
        uploadProgress = 0.0
        
        var uploadedURLs: [String] = []
        
        for (index, image) in selectedImages.enumerated() {
            do {
                guard let data = image.jpegData(compressionQuality: 0.8) else {
                    continue
                }
                
                let url = try await uploadImageToFirebase(data: data, index: index)
                uploadedURLs.append(url)
                
                // Update progress
                uploadProgress = Double(index + 1) / Double(selectedImages.count)
                
            } catch {
                print("Error uploading image: \(error.localizedDescription)")
            }
        }
        
        // Send message with uploaded image URLs
        if !uploadedURLs.isEmpty {
            let message = ExpenseChat(
                textMessage: messageText.isEmpty ? "📷 Image" : messageText,
                mediaURL: uploadedURLs,
                mention: [],
                senderId: userPhoneNumber,
                senderRole: role
            )
            
            viewModel.sendMessage(message)
            messageText = ""
        }
        
        isUploadingImage = false
        uploadProgress = 0.0
        selectedImages = []
        selectedPhotos = []
    }
    
    private func uploadImageToFirebase(data: Data, index: Int) async throws -> String {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        // Create unique filename with user UID for better permissions
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "expense_chat_\(expense.id ?? "unknown")_\(timestamp)_\(index).jpg"
        // Use userPhoneNumber as the user identifier for storage path
        let imageRef = storageRef.child("expense_chat_images/\(userPhoneNumber)/\(filename)")
        
        // Upload the image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await imageRef.putDataAsync(data, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await imageRef.downloadURL()
        return downloadURL.absoluteString
    }
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: ExpenseChat
    let isFromCurrentUser: Bool
    let onImageTapped: (String, Int) -> Void
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender Name (only show for other users)
                if !isFromCurrentUser {
                    Text(message.senderRole.rawValue == "APPROVER" ? "\(message.senderRole.rawValue) - \(message.senderId)" : message.senderRole.rawValue)
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
                        ForEach(Array(message.mediaURL.enumerated()), id: \.offset) { index, url in
                            AsyncImage(url: URL(string: url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        onImageTapped(url, index)
                                    }
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
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isFromCurrentUser ? .trailing : .leading)
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
                        if isFromCurrentUser {
                            Spacer()
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isFromCurrentUser ? .trailing : .leading)
                }
                
                // Timestamp
                Text(formatTimestamp(message.timeStamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isFromCurrentUser ? .trailing : .leading)
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

// MARK: - Image Viewer View
struct ImageViewerView: View {
    let imageURL: String
    let imageIndex: Int
    let allImageURLs: [String]
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingControls = true
    @State private var dragOffset: CGSize = .zero
    
    init(imageURL: String, imageIndex: Int, allImageURLs: [String]) {
        self.imageURL = imageURL
        self.imageIndex = imageIndex
        self.allImageURLs = allImageURLs
        self._currentIndex = State(initialValue: imageIndex)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
                .opacity(0.95)
            
            // Main Image View
            TabView(selection: $currentIndex) {
                ForEach(Array(allImageURLs.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: URL(string: url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    // Pinch to zoom
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = min(max(scale * delta, 1.0), 5.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            if scale < 1.0 {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    scale = 1.0
                                                    offset = .zero
                                                }
                                            }
                                        },
                                    
                                    // Drag to pan
                                    DragGesture()
                                        .onChanged { value in
                                            if scale > 1.0 {
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.0
                                    }
                                }
                            }
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingControls.toggle()
                                }
                            }
                    } placeholder: {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("Loading...")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _, newIndex in
                // Reset zoom when changing images
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
            
            // Top Controls
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Image counter
                    Text("\(currentIndex + 1) of \(allImageURLs.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
            }
            .opacity(showingControls ? 1.0 : 0.0)
            
            // Bottom Controls
            VStack {
                Spacer()
                
                HStack(spacing: 20) {
                    // Share button
                    Button {
                        shareImage()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Download button
                    Button {
                        downloadImage()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .opacity(showingControls ? 1.0 : 0.0)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Auto-hide controls after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingControls = false
                }
            }
        }
    }
    
    private func shareImage() {
        guard let url = URL(string: allImageURLs[currentIndex]) else { return }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func downloadImage() {
        guard let url = URL(string: allImageURLs[currentIndex]) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let image = UIImage(data: data) else { return }
            
            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }.resume()
    }
}

#Preview {
    ExpenseChatView(
        expense: Expense.sampleData[0],
        userPhoneNumber: "+919876543210", projectId: "I1kHn5UTOs6FCBA33Ke5", role: .ADMIN
    )
}
