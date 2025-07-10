import SwiftUI
import Combine

/*
 🔧 QUICK VALIDATION CUSTOMIZATION GUIDE 🔧
 
 To change validation rules, modify the ValidationRules struct below:
 
 📱 Phone Number:
    - phoneNumberLength: Change required length (default: 10)
    - allowOnlyNumbers: true = only digits, false = allow letters
 
 🔐 OTP Code:
    - otpCodeLength: Change required length (default: 6)
    - allowOnlyNumbers: true = only digits, false = allow letters
 
 🔑 Password:
    - minimumPasswordLength: Change minimum length (default: 6)
 
 💡 Other Options:
    - allowEmptySpaces: true = allow spaces in inputs
 
 Example: For 8-digit phone numbers, change phoneNumberLength to 8
 Example: For 4-digit OTP, change otpCodeLength to 4
*/

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var phoneNumber = ""
    @Published var otpCode = ""
    @Published var isOtpSent = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firebaseAuth: FirebaseAuthService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Validation Configuration
    // ⚙️ EASY TO MODIFY VALIDATION RULES ⚙️
    // Change these values to customize validation behavior
    struct ValidationRules {
        // Phone number validation
        static let phoneNumberLength = 10        // Change to required phone number length
        
        // OTP validation  
        static let otpCodeLength = 6            // Change to required OTP length
        
        // Password validation
        static let minimumPasswordLength = 6     // Change minimum password length
        
        // Character type validation
        static let allowOnlyNumbers = true      // Set to false to allow letters in phone/OTP
        
        // Additional validation options
        static let allowEmptySpaces = false     // Set to true to allow spaces in inputs
    }
    
    init(authService: FirebaseAuthService) {
        self.firebaseAuth = authService
        
        // Subscribe to auth service updates
        firebaseAuth.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        firebaseAuth.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    var isEmailFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@") &&
        !password.isEmpty &&
        password.count >= ValidationRules.minimumPasswordLength
    }
    
    var isPhoneNumberValid: Bool {
        let processedPhone = ValidationRules.allowEmptySpaces ? phoneNumber : phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length
        guard processedPhone.count == ValidationRules.phoneNumberLength else {
            return false
        }
        
        // Check if only numbers (if required)
        if ValidationRules.allowOnlyNumbers {
            let charactersToCheck = ValidationRules.allowEmptySpaces ? processedPhone.replacingOccurrences(of: " ", with: "") : processedPhone
            return charactersToCheck.allSatisfy { $0.isNumber }
        }
        
        return true
    }
    
    var isOtpCodeValid: Bool {
        let processedOtp = ValidationRules.allowEmptySpaces ? otpCode : otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length
        guard processedOtp.count == ValidationRules.otpCodeLength else {
            return false
        }
        
        // Check if only numbers (if required)
        if ValidationRules.allowOnlyNumbers {
            let charactersToCheck = ValidationRules.allowEmptySpaces ? processedOtp.replacingOccurrences(of: " ", with: "") : processedOtp
            return charactersToCheck.allSatisfy { $0.isNumber }
        }
        
        return true
    }
    
    // MARK: - Helper Methods for Validation Display
    var phoneNumberValidationMessage: String {
        if phoneNumber.isEmpty {
            return "Enter your phone number"
        } else if phoneNumber.count < ValidationRules.phoneNumberLength {
            return "Phone number must be \(ValidationRules.phoneNumberLength) digits"
        } else if phoneNumber.count > ValidationRules.phoneNumberLength {
            return "Phone number is too long"
        } else if ValidationRules.allowOnlyNumbers && !phoneNumber.allSatisfy({ $0.isNumber }) {
            return "Phone number must contain only digits"
        }
        return ""
    }
    
    var otpValidationMessage: String {
        if otpCode.isEmpty {
            return "Enter verification code"
        } else if otpCode.count < ValidationRules.otpCodeLength {
            return "Code must be \(ValidationRules.otpCodeLength) digits"
        } else if otpCode.count > ValidationRules.otpCodeLength {
            return "Code is too long"
        } else if ValidationRules.allowOnlyNumbers && !otpCode.allSatisfy({ $0.isNumber }) {
            return "Code must contain only digits"
        }
        return ""
    }
    
    // MARK: - Email Authentication
    func signInWithEmail() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let success = await firebaseAuth.signInWithEmail(email: trimmedEmail, password: password)
        
        if success {
            // Navigation will be handled by ContentView based on auth state
            HapticManager.notification(.success)
        } else {
            HapticManager.notification(.error)
        }
    }
    
    // MARK: - OTP Authentication
    func sendOTP() async {
        let success = await firebaseAuth.sendOTP(to: phoneNumber)
        
        if success {
            isOtpSent = true
            HapticManager.notification(.success)
        } else {
            HapticManager.notification(.error)
        }
    }
    
    func verifyOTP() async {
        let success = await firebaseAuth.verifyOTP(code: otpCode)
        
        if success {
            // Navigation will be handled by ContentView based on auth state
            HapticManager.notification(.success)
        } else {
            HapticManager.notification(.error)
        }
    }
    
    // MARK: - Helper Methods
    func resetState() {
        email = ""
        password = ""
        phoneNumber = ""
        otpCode = ""
        isOtpSent = false
        errorMessage = nil
    }
    
    func resetToPhoneNumber() {
        otpCode = ""
        isOtpSent = false
        errorMessage = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Auth Service Access
    var authService: FirebaseAuthService {
        return firebaseAuth
    }
} 
