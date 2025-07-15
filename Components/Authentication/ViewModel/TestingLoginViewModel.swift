//
//  TestingLoginViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

import SwiftUI
import FirebaseFirestore

@MainActor
class TestingLoginViewModel: ObservableObject {
    
    @Published var phoneNumber: String = ""
    @Published var otpCode: String = ""
    @Published var isOtpSent: Bool = false
    @Published var verificationID: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var PhoneOtp : [String : String] = [:]
    @Published var isAuthenticated: Bool = false
    
    private var authService: FirebaseAuthService?
    
    func setAuthService(_ service: FirebaseAuthService) {
        self.authService = service
    }
    
    func sendOTP() {
        isLoading = true
        errorMessage = nil
        
        // Clean phone number of any potential prefixes
        let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        checkMobileNumberInFirebase { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                if !result {
                    self.errorMessage = "Mobile Number not registered, please contact admin"
                    self.isOtpSent = false
                } else {
                    let otp = String(format: "%06d", Int.random(in: 0...999999))
                    self.PhoneOtp[cleanPhoneNumber] = otp
                    print("Test OTP has been generated for \(cleanPhoneNumber): \(otp)")
                    self.isOtpSent = true
                }
                self.isLoading = false
            }
        }
    }
    
    @MainActor func verifyOTP() -> Bool {
        print("Starting OTP verification...")
        isLoading = true
        errorMessage = nil
        
        // Clean phone number of any potential prefixes
        let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let sentOtp = PhoneOtp[cleanPhoneNumber] else {
            print("No OTP found for number: \(cleanPhoneNumber)")
            errorMessage = "No OTP found for this number. Please request a new OTP."
            isLoading = false
            return false 
        }
        
        let isValid = sentOtp == otpCode
        print("OTP validation result: \(isValid)")
        
        if isValid {
            print("OTP verified successfully")
            UserServices.shared.setCurrentUserPhone(cleanPhoneNumber)
            // Clear the OTP after successful verification
            PhoneOtp.removeValue(forKey: cleanPhoneNumber)
            
            // Update auth service state immediately
            self.isAuthenticated = true
            
            // Then update the auth service
            Task { @MainActor in
                await authService?.loadOTPUser(phoneNumber: cleanPhoneNumber)
                print("Auth service updated with phone: \(cleanPhoneNumber)")
            }
        } else {
            print("OTP verification failed")
            errorMessage = "Invalid OTP. Please try again."
        }
        
        isLoading = false
        return isValid
    }
    
    func reset() {
        phoneNumber = ""
        otpCode = ""
        isOtpSent = false
        verificationID = nil
        isLoading = false
        errorMessage = nil
        PhoneOtp.removeAll()
    }
    
    func checkMobileNumberInFirebase(completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        // Clean phone number of any potential prefixes
        let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let docRef = db.collection(FirebaseCollections.users).document(cleanPhoneNumber)
        
        docRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching document: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let document = document, document.exists {
                completion(true)
            } else {
                print("User not found. Please contact admin for access.")
                completion(false)
            }
        }
    }
    
    func returnOTP(phoneNUmber: String)-> String {
        let phoneNumber = phoneNUmber
        let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return PhoneOtp[cleanPhoneNumber] ?? ""
    }
}
