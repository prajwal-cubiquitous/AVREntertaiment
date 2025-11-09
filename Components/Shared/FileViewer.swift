//
//  FileViewer.swift
//  AVREntertainment
//
//  File viewer component using QuickLook for PDFs and images
//

import SwiftUI
import QuickLook
import UniformTypeIdentifiers

// MARK: - File Viewer Sheet
struct FileViewerSheet: View {
    let fileURL: URL
    let fileName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var localFileURL: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let localURL = localFileURL {
                    QuickLookPreview(url: localURL)
                        .edgesIgnoringSafeArea(.all)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Failed to Load File")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading file...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(fileName ?? "File Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadFile()
        }
        .onDisappear {
            // Clean up temporary file
            if let localURL = localFileURL {
                try? FileManager.default.removeItem(at: localURL)
            }
        }
    }
    
    private func loadFile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Download file data
            let (data, _) = try await URLSession.shared.data(from: fileURL)
            
            // Determine file extension from URL or content type
            let fileExtension = fileURL.pathExtension.isEmpty ? "pdf" : fileURL.pathExtension
            
            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileName = "\(UUID().uuidString).\(fileExtension)"
            let tempFileURL = tempDir.appendingPathComponent(tempFileName)
            
            // Write data to temporary file
            try data.write(to: tempFileURL)
            
            await MainActor.run {
                self.localFileURL = tempFileURL
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to download file: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// MARK: - QuickLook Preview Wrapper
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

// MARK: - File Icon View
struct FileIconView: View {
    let fileName: String?
    let fileURL: String?
    let onTap: () -> Void
    let isReciept: Bool
    
    var body: some View {
        if let url = fileURL, !url.isEmpty {
            Button(action: {
                HapticManager.selection()
                onTap()
            }) {
                Image(systemName: fileIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isReciept ? .blue : .green)
                    .padding(8)
                    .background(isReciept ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var fileIcon: String {
        guard let fileName = fileName?.lowercased() else {
            return "doc.fill"
        }
        
        if fileName.hasSuffix(".pdf") {
            return "doc.fill"
        } else if fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") {
            return "photo.fill"
        } else if fileName.hasSuffix(".png") {
            return "photo.fill"
        } else {
            return "doc.fill"
        }
    }
}


