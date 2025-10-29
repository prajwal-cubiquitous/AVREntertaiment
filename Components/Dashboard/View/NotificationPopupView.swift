//
//  NotificationPopupView.swift
//  AVREntertainment
//
//  Created by Auto on 10/29/25.
//

import SwiftUI
import FirebaseFirestore

struct NotificationPopupView: View {
    @ObservedObject var notificationViewModel: NotificationViewModel
    let project: Project
    let role: UserRole?
    let phoneNumber: String
    @Binding var isPresented: Bool
    
    @State private var showingPendingApprovals = false
    @State private var showingChats = false
    @State private var showingExpenseChat = false
    @State private var selectedExpenseForChat: Expense?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
                
                // Popup content - positioned at top
                VStack(spacing: 0) {
                    if notificationViewModel.isLoading {
                        loadingView
                    } else if notificationViewModel.hasNotifications {
                        notificationsContent
                    } else {
                        emptyStateView
                    }
                }
                .frame(maxWidth: 340)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                .scaleEffect(isPresented ? 1.0 : 0.9)
                .opacity(isPresented ? 1.0 : 0.0)
                .offset(y: isPresented ? 0 : -20)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
                .padding(.top, geometry.safeAreaInsets.top + 44) // Positioned right below navigation bar
                .padding(.trailing, 16) // Aligned to right edge near bell icon
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) // Top-right aligned container
            }
        }
        .onAppear {
            Task {
                if let projectId = project.id {
                    await notificationViewModel.fetchProjectNotifications(
                        projectId: projectId,
                        currentUserPhone: phoneNumber,
                        currentUserRole: role ?? .USER
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showingPendingApprovals) {
            NavigationStack {
                PendingApprovalsView(role: role, project: project, phoneNumber: phoneNumber)
            }
        }
        .sheet(isPresented: $showingChats) {
            if role == .ADMIN {
                ChatsView(
                    project: project,
                    currentUserRole: .ADMIN
                )
                .presentationDetents([.large])
            } else {
                ChatsView(
                    project: project,
                    currentUserPhone: phoneNumber,
                    currentUserRole: role ?? .USER
                )
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingExpenseChat) {
            if let expense = selectedExpenseForChat {
                ExpenseChatView(
                    expense: expense,
                    userPhoneNumber: phoneNumber,
                    projectId: project.id ?? "",
                    role: role ?? .USER
                )
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading notifications...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(24)
    }
    
    // MARK: - Notifications Content
    
    private var notificationsContent: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Notifications")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Today")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            // Notification Items
            ScrollView {
                LazyVStack(spacing: 0) {
                    if notificationViewModel.pendingApprovalsCount > 0 {
                        NotificationPopupItemView(
                            icon: "doc.text.magnifyingglass",
                            iconColor: Color.orange,
                            title: "\(notificationViewModel.pendingApprovalsCount) Pending Approval\(notificationViewModel.pendingApprovalsCount > 1 ? "s" : "")",
                            subtitle: "Expense updates waiting for review",
                            badgeColor: Color.orange
                        ) {
                            showingPendingApprovals = true
                            isPresented = false
                        }
                    }
                    
                    if notificationViewModel.unreadMessagesCount > 0 {
                        if notificationViewModel.pendingApprovalsCount > 0 {
                            Divider()
                                .padding(.leading, 56)
                        }
                        
                        NotificationPopupItemView(
                            icon: "bubble.left.and.bubble.right.fill",
                            iconColor: Color.blue,
                            title: "\(notificationViewModel.unreadMessagesCount) Unread Message\(notificationViewModel.unreadMessagesCount > 1 ? "s" : "")",
                            subtitle: "New messages in your chats",
                            badgeColor: Color.blue
                        ) {
                            showingChats = true
                            isPresented = false
                        }
                    }
                    
                    if notificationViewModel.expenseChatUpdatesCount > 0 {
                        if notificationViewModel.pendingApprovalsCount > 0 || notificationViewModel.unreadMessagesCount > 0 {
                            Divider()
                                .padding(.leading, 56)
                        }
                        
                        NotificationPopupItemView(
                            icon: "message.badge.fill",
                            iconColor: Color.green,
                            title: "\(notificationViewModel.expenseChatUpdatesCount) Expense Discussion\(notificationViewModel.expenseChatUpdatesCount > 1 ? "s" : "")",
                            subtitle: "Recent updates on your expenses",
                            badgeColor: Color.green
                        ) {
                            // Navigate to first expense with chat update
                            Task {
                                await openExpenseChat()
                            }
                            isPresented = false
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 280)
            
            Divider()
            
            // View all button
            if notificationViewModel.hasNotifications {
                Button {
                    showingPendingApprovals = true
                    isPresented = false
                } label: {
                    Text("View all")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
            
            Text("No Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("You're all caught up!")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Button("Close") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPresented = false
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(32)
    }
    
    // MARK: - Helper Methods
    
    private func openExpenseChat() async {
        guard let projectId = project.id else { return }
        
        let db = Firestore.firestore()
        
        do {
            // Fetch expenses with recent chat messages
            let expensesSnapshot = try await db
                .collection("projects_ios")
                .document(projectId)
                .collection("expenses")
                .getDocuments()
            
            for expenseDoc in expensesSnapshot.documents {
                guard let expenseData = try? expenseDoc.data(as: Expense.self),
                      expenseData.submittedBy == phoneNumber,
                      expenseData.status != .approved else { continue }
                
                // Check for recent expense chat messages
                let expenseChatSnapshot = try await db
                    .collection("projects_ios")
                    .document(projectId)
                    .collection("expenses")
                    .document(expenseDoc.documentID)
                    .collection("expenseChats")
                    .order(by: "timeStamp", descending: true)
                    .limit(to: 1)
                    .getDocuments()
                
                if let lastMessage = expenseChatSnapshot.documents.first,
                   let messageData = try? lastMessage.data(as: ExpenseChat.self) {
                    let last24Hours = Date().addingTimeInterval(-24 * 60 * 60)
                    if messageData.timeStamp > last24Hours {
                        await MainActor.run {
                            selectedExpenseForChat = expenseData
                            showingExpenseChat = true
                        }
                        return
                    }
                }
            }
        } catch {
            print("Error fetching expense chat: \(error)")
        }
    }
}

// MARK: - Notification Popup Row View (for list-style notifications)

struct NotificationPopupRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let timeAgo: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(iconColor)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(timeAgo)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Notification Popup Item View

struct NotificationPopupItemView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badgeColor: Color
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: {
            action?()
            HapticManager.selection()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    let viewModel = NotificationViewModel()
    viewModel.pendingApprovalsCount = 3
    viewModel.unreadMessagesCount = 2
    viewModel.expenseChatUpdatesCount = 1
    
    return ZStack {
        Color.gray.opacity(0.3)
        
        NotificationPopupView(
            notificationViewModel: viewModel,
            project: Project.sampleData[0],
            role: .APPROVER,
            phoneNumber: "1234567890",
            isPresented: $isPresented
        )
    }
}

