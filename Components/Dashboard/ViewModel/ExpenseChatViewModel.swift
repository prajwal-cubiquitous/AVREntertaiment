//
//  ExpenseChatViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class ExpenseChatViewModel: ObservableObject {
    @Published var messages: [ExpenseChat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    let expense: Expense
    let userPhoneNumber: String
    let projectID: String
    
    init(expense: Expense, userPhoneNumber: String, projectID: String) {
        self.expense = expense
        self.userPhoneNumber = userPhoneNumber
        self.projectID = projectID
    }
    
    deinit {
        listener?.remove()
    }
    
    
    // MARK: - Public Methods
    
    func loadChatMessages() {
        isLoading = true
        errorMessage = nil
        guard let ExpenseId = expense.id else {
            self.isLoading = false
            return
        }
        
        let chatCollection = db.collection("projects_ios").document(projectID).collection("expenses").document(ExpenseId).collection("expenseChats")
            .order(by: "timeStamp", descending: false)
        
        listener = chatCollection.addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.errorMessage = "No messages found"
                    return
                }
                
                self?.messages = documents.compactMap { document in
                    try? document.data(as: ExpenseChat.self)
                }
            }
        }
    }
    
    func sendMessage(_ message: ExpenseChat) {
        guard let ExpenseId = expense.id else {
            self.isLoading = false
            return
        }
        
        let chatData = message
        
        let docRef = db.collection("projects_ios").document(projectID)
                            .collection("expenses").document(ExpenseId)
                            .collection("expenseChats").document() // Let Firestore generate the ID

            // 3. Use the modern async call to write the data
        do{
            try docRef.setData(from: chatData)
        }catch{
            print("error")
        }
    }
    
    func loadUserData(userId: String) async throws -> String {
        let userDoc = try await db.collection("users_ios").document(userId).getDocument()
        
        guard userDoc.exists else {
            throw UserDataError.userNotFound
        }
        
        guard let userData = try? userDoc.data(as: User.self) else {
            throw UserDataError.invalidUserId
        }
        
        guard !userData.name.isEmpty else {
            throw UserDataError.missingNameField
        }
        
        return userData.name
    }
    
    // MARK: - Private Methods
    
    private func getCurrentUserRole() -> UserRole {
        // This should be determined based on the current user's role
        // For now, returning ADMIN as default
        return .ADMIN
    }
    
    private func getChatParticipants() -> [String] {
        var participants: [String] = []
        
        // Add the user who submitted the expense
        participants.append(expense.submittedBy)
        
//        // Add temp approver
//        participants.append(tempApproverId)
        
        // Add admin (you can get this from current user context)
        // participants.append(adminPhoneNumber)
        
        return participants
    }
}

// MARK: - Sample Data for Preview
extension ExpenseChatViewModel {
    static func sampleViewModel() -> ExpenseChatViewModel {
        let viewModel = ExpenseChatViewModel(
            expense: Expense.sampleData[0],
            userPhoneNumber: "+919876543210", projectID: "I1kHn5UTOs6FCBA33Ke5",
        )
        
        // Add sample messages for preview
        viewModel.messages = [
            ExpenseChat(
                textMessage: "Hi, I need clarification on this expense.",
                timeStamp: Date().addingTimeInterval(-3600),
                senderId: "+919876543210",
                senderRole: .ADMIN
            ),
            ExpenseChat(
                textMessage: "Sure, what would you like to know?",
                timeStamp: Date().addingTimeInterval(-3500),
                senderId: "+919876543211",
                senderRole: .ADMIN
            ),
            ExpenseChat(
                textMessage: "Is the amount within the approved budget?",
                timeStamp: Date().addingTimeInterval(-3400),
                senderId: "+919876543210",
                senderRole: .ADMIN
            )
        ]
        
        return viewModel
    }
}
