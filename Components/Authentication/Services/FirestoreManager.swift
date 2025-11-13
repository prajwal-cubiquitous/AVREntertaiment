//
//  FirestoreManager.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/24/25.
//


import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging

class FirestoreManager {
    static let shared = FirestoreManager()
    private init() {}
    
    // Store current FCM token for cleanup on logout/uninstall
    private var currentFCMToken: String?
    
    // Store customer ID for cleanup
    private var currentCustomerId: String?

    func saveToken(token: String) async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Store token for later cleanup
        currentFCMToken = token
        
        do {
            // Check if this is an admin user (email-based) or OTP user (phone-based)
            if let email = currentUser.email, !email.isEmpty {
                // Admin user - store in customers collection
                let customerId = currentUser.uid
                currentCustomerId = customerId
                
                let customerRef = Firestore.firestore().collection("customers").document(customerId)
                
                // Get current FCMlist array or create new one
                let customerDoc = try await customerRef.getDocument()
                var fcmList: [String] = []
                
                if customerDoc.exists, let data = customerDoc.data(), let existingList = data["FCMlist"] as? [String] {
                    fcmList = existingList
                }
                
                // Add token if not already present
                if !fcmList.contains(token) {
                    fcmList.append(token)
                    try await customerRef.updateData(["FCMlist": fcmList])
                    print("✅ FCM token saved to customers collection for admin user: \(customerId)")
                } else {
                    print("ℹ️ FCM token already exists in FCMlist")
                }
            } else if let phoneNumber = currentUser.phoneNumber {
                // OTP user - store in users collection (existing behavior)
                let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                try await Firestore.firestore().collection("users").document(cleanPhoneNumber).updateData(["fcmToken": token])
                print("✅ FCM token saved to users collection for OTP user: \(cleanPhoneNumber)")
            }
        } catch {
            print("❌ Error saving FCM token: \(error.localizedDescription)")
        }
    }
    
    func removeToken() async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        do {
            // Check if this is an admin user (email-based) or OTP user (phone-based)
            if let email = currentUser.email, !email.isEmpty {
                // Admin user - remove from customers collection FCMlist
                let customerId = currentUser.uid
                let customerRef = Firestore.firestore().collection("customers").document(customerId)
                
                // Get current FCMlist
                let customerDoc = try await customerRef.getDocument()
                if customerDoc.exists, let data = customerDoc.data(), var fcmList = data["FCMlist"] as? [String] {
                    // Remove current token if we have it stored
                    if let tokenToRemove = currentFCMToken {
                        fcmList.removeAll { $0 == tokenToRemove }
                    } else {
                        // If we don't have stored token, try to get it from Messaging
                        if let token = try? await Messaging.messaging().token() {
                            fcmList.removeAll { $0 == token }
                        }
                    }
                    
                    // Update FCMlist (or delete field if empty)
                    if fcmList.isEmpty {
                        try await customerRef.updateData(["FCMlist": FieldValue.delete()])
                    } else {
                        try await customerRef.updateData(["FCMlist": fcmList])
                    }
                    print("✅ FCM token removed from customers collection FCMlist")
                }
            } else if let phoneNumber = currentUser.phoneNumber {
                // OTP user - remove from users collection (existing behavior)
                let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let docRef = Firestore.firestore().collection("users").document(cleanPhoneNumber)
                try await docRef.updateData(["fcmToken": FieldValue.delete()])
                print("✅ FCM token removed from users collection")
            }
            
            // Clear stored values
            currentFCMToken = nil
            currentCustomerId = nil
        } catch {
            print("❌ Error removing FCM token: \(error.localizedDescription)")
        }
    }
    
    // Method to remove token by token string (useful for cleanup)
    func removeToken(_ token: String, customerId: String) async {
        do {
            let customerRef = Firestore.firestore().collection("customers").document(customerId)
            let customerDoc = try await customerRef.getDocument()
            
            if customerDoc.exists, let data = customerDoc.data(), var fcmList = data["FCMlist"] as? [String] {
                fcmList.removeAll { $0 == token }
                
                if fcmList.isEmpty {
                    try await customerRef.updateData(["FCMlist": FieldValue.delete()])
                } else {
                    try await customerRef.updateData(["FCMlist": fcmList])
                }
                print("✅ FCM token removed from customers collection FCMlist: \(token)")
            }
        } catch {
            print("❌ Error removing FCM token: \(error.localizedDescription)")
        }
    }
}
