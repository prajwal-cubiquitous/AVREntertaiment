import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class CreateUserViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published var name = ""
    @Published var selectedRole: UserRole = .USER
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var showDuplicateAlert = false
    
    private let db = Firestore.firestore()
    
    var isFormValid: Bool {
        !phoneNumber.isEmpty && 
        !name.isEmpty && 
        phoneNumber.count >= 10 && 
        isValidPhoneNumber(phoneNumber)
    }
    
    private func isValidPhoneNumber(_ number: String) -> Bool {
        let phoneRegex = "^[0-9]{10}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: number)
    }
    
    func checkAndCreateUser(authService: FirebaseAuthService) async {
        guard isFormValid else {
            errorMessage = "Please fill all fields correctly"
            return
        }
        
        isLoading = true
        errorMessage = nil
        showSuccessMessage = false
        
        // Format phone number - remove any existing +91 prefix
        let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "")
        
        // Check if user exists
        do {
            let snapshot = try await db.collection("users")
                .whereField("phoneNumber", isEqualTo: cleanPhoneNumber)
                .getDocuments()
            
            if !snapshot.documents.isEmpty {
                // User exists, show alert
                showDuplicateAlert = true
                isLoading = false
                return
            }
            
            // No duplicate found, create user
            await createUser(authService: authService, overwrite: false)
        } catch {
            isLoading = false
            errorMessage = "Failed to check for existing user: \(error.localizedDescription)"
        }
    }
    
    func createUser(authService: FirebaseAuthService, overwrite: Bool) async {
        guard isFormValid else {
            errorMessage = "Please fill all fields correctly"
            return
        }
        
        if !isLoading {
            isLoading = true
            errorMessage = nil
            showSuccessMessage = false
        }
        
        // Format phone number - remove any existing +91 prefix
        let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "")
        
        let success = await authService.createUser(
            phoneNumber: cleanPhoneNumber,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            role: selectedRole,
            overwrite: overwrite
        )
        
        isLoading = false
        
        if success {
            showSuccessMessage = true
            // Reset form
            phoneNumber = ""
            name = ""
            selectedRole = .USER
            errorMessage = nil
        } else {
            errorMessage = authService.errorMessage ?? "Failed to create user"
        }
    }
}

 