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
    @Published var approveName: String?
    @Published var isSendingMessage = false
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
    
    func loadChatMessages() async throws {
        isLoading = true
        errorMessage = nil
        guard let ExpenseId = expense.id else {
            print("❌ Expense Chat: Expense ID is nil")
            self.isLoading = false
            return
        }
        
        let customerID = try await FirebasePathHelper.shared.fetchEffectiveUserID()
        
        let chatCollection = db.collection("customers").document(customerID)
            .collection("projects").document(projectID).collection("expenses").document(ExpenseId).collection("expenseChats")
            .order(by: "timeStamp", descending: false)
        
        listener = chatCollection.addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Expense Chat Error: Failed to load messages: \(error.localizedDescription)")
                    self?.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.errorMessage = "No messages found"
                    return
                }
                
                let parsedMessages = documents.compactMap { document -> ExpenseChat? in
                    do {
                        let message = try document.data(as: ExpenseChat.self)
                        // Create new message with document ID
                        let messageWithId = ExpenseChat(
                            id: document.documentID,
                            textMessage: message.textMessage,
                            mediaURL: message.mediaURL,
                            timeStamp: message.timeStamp,
                            mention: message.mention,
                            senderId: message.senderId,
                            senderRole: message.senderRole
                        )
                        
                        return messageWithId
                    } catch {
                        print("❌ Expense Chat: Failed to parse message document \(document.documentID): \(error.localizedDescription)")
                        return nil
                    }
                }
                
                self?.messages = parsedMessages
            }
        }
    }
    
    func sendMessage(_ message: ExpenseChat) async throws {
        
        guard let ExpenseId = expense.id else {
            return
        }
        
        let customerID = try await FirebasePathHelper.shared.fetchEffectiveUserID()
        
        // Set sending state to true
        isSendingMessage = true
        
        let chatData = message
        
        let docRef = db.collection("customers").document(customerID)
            .collection("projects").document(projectID)
                            .collection("expenses").document(ExpenseId)
                            .collection("expenseChats").document() // Let Firestore generate the ID

        // Use the modern async call to write the data
        Task {
            do {
                try await docRef.setData(from: chatData)
                await MainActor.run {
                    self.isSendingMessage = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Expense Chat: Error sending message: \(error.localizedDescription)")
                    self.isSendingMessage = false
                }
            }
        }
    }
    
    func loadUserData(_ userId: String) async throws -> String {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
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
