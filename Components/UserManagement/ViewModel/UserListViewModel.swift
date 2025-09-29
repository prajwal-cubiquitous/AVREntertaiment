import Foundation
import FirebaseFirestore

@MainActor
class UserListViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    func fetchUsers() async {
        isLoading = true
        do {
            let snapshot = try await db.collection("users_ios").getDocuments()
            users = snapshot.documents.compactMap { document -> User? in
                try? document.data(as: User.self)
            }.sorted { $0.name < $1.name } // Sort by name
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func toggleUserStatus(_ user: User) async {
        guard let userId = user.id else { return }
        
        // Optimistically update the UI
        if let index = users.firstIndex(where: { $0.id == userId }) {
            var updatedUser = users[index]
            updatedUser.isActive = !updatedUser.isActive
            users[index] = updatedUser
        }
        
        do {
            try await db.collection("users_ios").document(userId).updateData([
                "isActive": !user.isActive
            ])
            // No need to refresh the entire list since we already updated the UI
        } catch {
            // Revert the optimistic update on error
            if let index = users.firstIndex(where: { $0.id == userId }) {
                var revertedUser = users[index]
                revertedUser.isActive = user.isActive
                users[index] = revertedUser
            }
            showError = true
            errorMessage = "Failed to update user status: \(error.localizedDescription)"
        }
        
    }
} 
                             
