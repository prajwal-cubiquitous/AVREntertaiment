import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import Combine
import UniformTypeIdentifiers

@MainActor
class AddExpenseViewModel: ObservableObject {
    
    // MARK: - Form Inputs
    @Published var expenseDate: Date = Date()
    @Published var amount: String = ""
    @Published var selectedDepartment: String = ""
    @Published var categories: [String] = [""]
    @Published var description: String = ""
    @Published var selectedPaymentMode: PaymentMode = .cash
    @Published var attachmentURL: String?
    @Published var attachmentName: String?
    
    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var showingDocumentPicker: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading: Bool = false
    
    // MARK: - Project Data
    let project: Project
    var availableDepartments: [String] {
        Array(project.departments.keys).sorted()
    }
    
    // MARK: - Firebase References
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Computed Properties
    var amountValue: Double {
        Double(amount) ?? 0.0
    }
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amountValue)) ?? "₹0.00"
    }
    
    var isFormValid: Bool {
        !amount.isEmpty &&
        amountValue > 0 &&
        !selectedDepartment.isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !categories.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }).isEmpty
    }
    
    var nonEmptyCategories: [String] {
        categories.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    // MARK: - Initialization
    init(project: Project) {
        self.project = project
        // Set first department as default if available
        if let firstDepartment = availableDepartments.first {
            self.selectedDepartment = firstDepartment
        }
    }
    
    // MARK: - Category Management
    func addCategory() {
        categories.append("")
    }
    
    func removeCategory(at index: Int) {
        guard categories.count > 1 else { return }
        categories.remove(at: index)
    }
    
    // MARK: - File Upload
    func uploadAttachment(_ url: URL) {
        guard let projectId = project.id else { return }
        
        isUploading = true
        uploadProgress = 0.0
        
        // Get file name and extension
        let fileName = url.lastPathComponent
        attachmentName = fileName
        
        // Create unique file path
        let timestamp = Int(Date().timeIntervalSince1970)
        let storageRef = storage.reference()
            .child("projects_ios")
            .child(projectId)
            .child("expenses")
            .child("\(timestamp)_\(fileName)")
        
        // Upload file
        let uploadTask = storageRef.putFile(from: url, metadata: nil) { [weak self] metadata, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isUploading = false
                
                if let error = error {
                    self.alertMessage = "Upload failed: \(error.localizedDescription)"
                    self.showAlert = true
                    return
                }
                
                // Get download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        self.alertMessage = "Failed to get download URL: \(error.localizedDescription)"
                        self.showAlert = true
                        return
                    }
                    
                    if let downloadURL = url {
                        self.attachmentURL = downloadURL.absoluteString
                        self.alertMessage = "File uploaded successfully!"
                        self.showAlert = true
                    }
                }
            }
        }
        
        // Observe upload progress
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let progress = snapshot.progress else { return }
            
            DispatchQueue.main.async {
                self?.uploadProgress = Double(progress.fractionCompleted)
            }
        }
    }
    
    func removeAttachment() {
        // If there's an existing attachment URL, optionally delete it from storage
        if let urlString = attachmentURL,
           let url = URL(string: urlString) {
            let storageRef = Storage.storage().reference(forURL: urlString)
            storageRef.delete { [weak self] error in
                if let error = error {
                    print("Failed to delete file: \(error.localizedDescription)")
                }
            }
        }
        
        attachmentURL = nil
        attachmentName = nil
    }
    
    // MARK: - Submit Expense
    func submitExpense() {
        guard isFormValid else {
            alertMessage = "Please fill in all required fields correctly."
            showAlert = true
            return
        }
        
        guard let projectId = project.id else {
            alertMessage = "Project ID not found."
            showAlert = true
            return
        }
        
        guard let currentUserPhone = UserServices.shared.currentUserPhone else {
            alertMessage = "User not logged in."
            showAlert = true
            return
        }
        
        isLoading = true
        
        let expenseData: [String: Any] = [
            "projectId": projectId,
            "date": formatDate(expenseDate),
            "amount": amountValue,
            "department": selectedDepartment,
            "categories": nonEmptyCategories,
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "modeOfPayment": selectedPaymentMode.rawValue,
            "attachmentURL": attachmentURL as Any,
            "attachmentName": attachmentName as Any,
            "submittedBy": "+91\(currentUserPhone)",
            "status": ExpenseStatus.pending.rawValue,
            "createdAt": Timestamp(),
            "updatedAt": Timestamp()
        ]
        
        // Store in subcollection: projects_ios/{projectId}/expenses/{expenseId}
        db.collection("projects_ios")
            .document(projectId)
            .collection("expenses")
            .addDocument(data: expenseData) { [weak self] error in
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.alertMessage = "Error submitting expense: \(error.localizedDescription)"
                    } else {
                        self?.alertMessage = "Expense submitted successfully for approval!"
                        self?.resetForm()
                    }
                    self?.showAlert = true
                }
            }
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    private func resetForm() {
        expenseDate = Date()
        amount = ""
        description = ""
        categories = [""]
        selectedPaymentMode = .cash
        attachmentURL = nil
        attachmentName = nil
        uploadProgress = 0.0
        
        // Keep selected department as is for convenience
    }
}

// MARK: - Document Picker Support
extension AddExpenseViewModel {
    func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            uploadAttachment(url)
            
        case .failure(let error):
            alertMessage = "Failed to select file: \(error.localizedDescription)"
            showAlert = true
        }
    }
} 
