//
//  UserServices.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

typealias FirebaseUser = FirebaseAuth.User

@MainActor
class UserServices: ObservableObject {
    @Published var currentUserPhone: String? = nil
    @Published var currentUser: User? = nil
    @Published var isLoggedIn: Bool = false
    @Published var isAuthenticated: Bool = false
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    static let shared = UserServices()
    
    init() {
        // Listen for Firebase Auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                if let user = user {
                    await self?.handleAuthStateChange(user: user)
                } else {
                    await self?.handleSignOut()
                }
            }
        }
        
        // Load initial state
        Task {
            await loadInitialAuthState()
        }
    }
    
    // MARK: - Initial Load
    func loadInitialAuthState() async {
        if let firebaseUser = auth.currentUser {
            await handleAuthStateChange(user: firebaseUser)
        }
    }
    
    // MARK: - Auth State Handling
    private func handleAuthStateChange(user: FirebaseUser) async {
        isAuthenticated = true
        isLoggedIn = true
        
        // Determine phone number
        var phone: String?
        
        if let phoneNumber = user.phoneNumber {
            // User authenticated via phone (OTP)
            phone = cleanPhoneNumber(phoneNumber)
        } else if let email = user.email {
            // Admin user authenticated via email
            print("Admin user logged in: \(email)")
            phone = nil // Admin users don't have phone numbers
        }
        
        currentUserPhone = phone
        
        // Load user data from Firestore
        await loadCurrentUser(phone: phone)
    }
    
    private func handleSignOut() async {
        currentUserPhone = nil
        currentUser = nil
        isLoggedIn = false
        isAuthenticated = false
    }
    
    // MARK: - Phone Number Management
    func cleanPhoneNumber(_ phone: String) -> String {
        // Remove +91 prefix if it exists and clean whitespace
        let cleaned = phone.replacingOccurrences(of: "+91", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }
    
    // MARK: - User Data Loading
    private func loadCurrentUser(phone: String?) async {
        guard let phone = phone else {
            // This might be an admin user, currentUser will be set by FirebaseAuthService
            return
        }
        
        do {
            let document = try await db.collection(FirebaseCollections.users).document(phone).getDocument()
            if document.exists {
                currentUser = try document.data(as: User.self)
                print("✅ User loaded: \(currentUser?.name ?? "Unknown")")
            } else {
                currentUser = nil
                print("⚠️ User not found in database with phone: \(phone)")
            }
        } catch {
            print("❌ Error loading user: \(error)")
            currentUser = nil
        }
    }
    
    // MARK: - Public Methods
    func getCurrentUser() -> User? {
        return currentUser
    }
    
    func getCurrentPhoneNumber() -> String? {
        return currentUserPhone
    }
    
    func isCurrentUserAdmin() -> Bool {
        return currentUser?.role == .ADMIN
    }
    
    func isCurrentUserApprover() -> Bool {
        return currentUser?.role == .APPROVER
    }
    
    func isCurrentUserRegularUser() -> Bool {
        return currentUser?.role == .USER
    }
    
    // MARK: - Deprecated Methods (for backward compatibility)
    @available(*, deprecated, message: "Use FirebaseAuthService for sign in")
    func setCurrentUserPhone(_ phone: String) {
        // This method is deprecated in favor of Firebase Auth
        print("⚠️ setCurrentUserPhone is deprecated. Use FirebaseAuthService for authentication.")
    }
    
    @available(*, deprecated, message: "Sign out is handled by FirebaseAuthService")
    func removeCurrentUserPhone() {
        // This method is deprecated in favor of Firebase Auth sign out
        print("⚠️ removeCurrentUserPhone is deprecated. Use FirebaseAuthService.signOut() instead.")
    }
    
    // MARK: - Helper Functions
    func refreshCurrentUser() async {
        guard let phone = currentUserPhone else { return }
        await loadCurrentUser(phone: phone)
    }
}

