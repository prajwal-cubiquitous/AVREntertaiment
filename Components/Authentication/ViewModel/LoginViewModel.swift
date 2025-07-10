//
//  LoginViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//


import Foundation
import FirebaseAuth
import SwiftUI

@MainActor
class LoginViewModel: ObservableObject {
    
    @Published var phoneNumber: String = ""
    @Published var otpCode: String = ""
    @Published var isOtpSent: Bool = false
    @Published var verificationID: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    func sendOTP() {
        let fullPhone = "+91"+phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullPhone.isEmpty else {
            errorMessage = "Phone number is required."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        PhoneAuthProvider.provider().verifyPhoneNumber(fullPhone, uiDelegate: nil) { [weak self] verificationID, error in
            guard let self = self else { return }
            Task { @MainActor in
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                self.verificationID = verificationID
                self.isOtpSent = true
            }
        }
    }
    
    func verifyOTP(completion: @escaping (Bool) -> Void) {
        guard let verificationID = verificationID else {
            errorMessage = "Verification ID not found."
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: otpCode
        )
        
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            Task { @MainActor in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                // Successful login
                completion(true)
            }
        }
    }
    
    func reset() {
        phoneNumber = ""
        otpCode = ""
        isOtpSent = false
        verificationID = nil
        errorMessage = nil
    }
}
