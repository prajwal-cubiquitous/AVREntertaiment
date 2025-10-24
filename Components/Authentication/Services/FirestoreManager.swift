//
//  FirestoreManager.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/24/25.
//


import FirebaseFirestore
import FirebaseAuth

class FirestoreManager {
    static let shared = FirestoreManager()
    private init() {}

    func saveToken(token: String) {
        guard let userPhoneNumber = Auth.auth().currentUser?.phoneNumber else { return }
        let cleanPhoneNumber = userPhoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let docRef = Firestore.firestore().collection("users_ios").document(cleanPhoneNumber)
        docRef.setData(["fcmToken": token], merge: true) { error in
            if let error = error {
                print("Error saving FCM token: \(error.localizedDescription)")
            } else {
                print("FCM token saved to Firestore")
            }
        }
    }
    
    func removeToken() {
        guard let userPhoneNumber = Auth.auth().currentUser?.phoneNumber else { return }
        let cleanPhoneNumber = userPhoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let docRef = Firestore.firestore().collection("users_ios").document(cleanPhoneNumber)
        docRef.updateData(["fcmToken": FieldValue.delete()]) { error in
            if let error = error {
                print("Error removing FCM token: \(error.localizedDescription)")
            } else {
                print("FCM token removed from Firestore")
            }
        }
    }
}
