//
//  AuthService.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//
import SwiftUI
import FirebaseAuth

class AuthService: ObservableObject {
    @Published var errorMessage: String?
    @Published var isOtpSent: Bool = false
    @Published var verificationID: String?
    
    func login(withPhoneNumber phoneNumber: String) async throws {
        let fullPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        PhoneAuthProvider.provider().verifyPhoneNumber(fullPhone, uiDelegate: nil) { [weak self] verificationID, error in
            guard let self = self else { return }
            Task { @MainActor in
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                self.verificationID = verificationID
                self.isOtpSent = true
            }
        }
    }
    
    @MainActor
    func verifyCode(_ code: String) async throws {
        do{
            
        }catch{
            
        }
    }
}
