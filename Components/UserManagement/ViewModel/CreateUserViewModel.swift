import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class CreateUserViewModel: ObservableObject {
    @Published var phoneNumber = "" {
        didSet {
            // Re-validate phone number when user types after validation has been attempted
            if hasAttemptedValidation {
                phoneNumberError = validatePhoneNumber()
            }
        }
    }
    @Published var name = ""
    @Published var selectedRole: UserRole = .USER
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var showDuplicateAlert = false
    @Published var phoneNumberError: String? = nil
    @Published var hasAttemptedValidation = false
    
    private let db = Firestore.firestore()
    
    // Computed property for form validation
    var isFormValid: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        phoneNumberError == nil
    }
    
    // Comprehensive phone number validation
    func validatePhoneNumber() -> String? {
        let cleanedNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if empty
        if cleanedNumber.isEmpty {
            return "Phone number is required"
        }
        
        // Remove any +91 prefix for validation
        let numberWithoutPrefix = cleanedNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if length is exactly 10
        if numberWithoutPrefix.count != 10 {
            return "Phone number must be exactly 10 digits"
        }
        
        // Check if all characters are digits
        if !numberWithoutPrefix.allSatisfy({ $0.isNumber }) {
            return "Phone number must contain only digits"
        }
        
        // Check for invalid patterns - all same digits (1111111111, 2222222222, etc.)
        let firstDigit = numberWithoutPrefix.first
        if numberWithoutPrefix.allSatisfy({ $0 == firstDigit }) {
            return "Phone number cannot be all the same digit"
        }
        
        // Check for sequential patterns (1234567890, 9876543210, etc.)
        if isSequentialNumber(numberWithoutPrefix) {
            return "Phone number cannot be sequential"
        }
        
        // Check for common invalid patterns (0000000000, 1234567890, etc.)
        if numberWithoutPrefix == "0000000000" || numberWithoutPrefix == "1234567890" || numberWithoutPrefix == "0987654321" {
            return "Please enter a valid phone number"
        }
        
        return nil // Valid phone number
    }
    
    // Helper function to check if number is sequential
    private func isSequentialNumber(_ number: String) -> Bool {
        guard number.count == 10 else { return false }
        
        let digits = number.compactMap { Int(String($0)) }
        guard digits.count == 10 else { return false }
        
        // Check ascending sequence
        var isAscending = true
        for i in 1..<digits.count {
            if digits[i] != digits[i-1] + 1 {
                isAscending = false
                break
            }
        }
        
        // Check descending sequence
        var isDescending = true
        for i in 1..<digits.count {
            if digits[i] != digits[i-1] - 1 {
                isDescending = false
                break
            }
        }
        
        return isAscending || isDescending
    }
    
    func checkAndCreateUser(authService: FirebaseAuthService) async {
        // Mark that validation has been attempted
        hasAttemptedValidation = true
        
        // Validate phone number
        phoneNumberError = validatePhoneNumber()
        
        // Validate name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = "Please fill all fields with valid information"
            return
        }
        
        // If phone number validation failed, return early
        if phoneNumberError != nil {
            errorMessage = "Please fill all fields with valid information"
            return
        }
        
        guard isFormValid else {
            errorMessage = "Please fill all fields with valid information"
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
            phoneNumberError = nil
            hasAttemptedValidation = false
        } else {
            errorMessage = authService.errorMessage ?? "Failed to create user"
        }
    }
}

 
