//
//  UserServices.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

import Foundation
import Combine
import FirebaseFirestore

class UserServices: ObservableObject {
    @Published var currentUserPhone: String? = nil
    @Published var currentUser: User? = nil
    @Published var isLoggedIn: Bool = false
    
    private let db = Firestore.firestore()
    static let shared = UserServices()
    
    init() {
        // Check if user is already logged in
        if let savedPhone = UserDefaults.standard.string(forKey: "currentUserPhone") {
            currentUserPhone = savedPhone
            isLoggedIn = true
            Task {
                await loadCurrentUser()
            }
        }
    }

    @MainActor
    func setCurrentUserPhone(_ phone: String) {
        // Remove +91 prefix if it exists
        let cleanPhone = phone.hasPrefix("+91") ? String(phone.dropFirst(3)) : phone
        currentUserPhone = cleanPhone
        isLoggedIn = true
        UserDefaults.standard.set(cleanPhone, forKey: "currentUserPhone")
        
        Task {
            await loadCurrentUser()
        }
    }
    
    @MainActor
    func removeCurrentUserPhone() {
        currentUserPhone = nil
        currentUser = nil
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "currentUserPhone")
    }
    
    @MainActor
    private func loadCurrentUser() async {
        guard let phone = currentUserPhone else { return }
        
        do {
            let document = try await db.collection(FirebaseCollections.users).document(phone).getDocument()
            if document.exists {
                currentUser = try document.data(as: User.self)
            } else {
                // Don't create default user, just set to nil
                currentUser = nil
                print("User not found in database. Please contact admin for access.")
            }
        } catch {
            print("Error loading user: \(error)")
            currentUser = nil
        }
    }
}

