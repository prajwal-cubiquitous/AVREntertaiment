//
//  NotificationSummaryView.swift
//  AVREntertainment
//
//  Created by Auto on 10/29/25.
//

import SwiftUI

struct NotificationSummaryView: View {
    @ObservedObject var viewModel: NotificationViewModel
    var onPendingApprovalsTap: (() -> Void)?
    var onMessagesTap: (() -> Void)?
    var onExpenseChatsTap: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasNotifications {
                notificationsContent
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Loading notifications...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Notifications Content
    
    private var notificationsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)
                    .symbolRenderingMode(.hierarchical)
                
                Text("\(viewModel.totalNotifications) New Updates")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Notification Items
            VStack(spacing: 0) {
                if viewModel.pendingApprovalsCount > 0 {
                    NotificationSummaryItemView(
                        icon: "doc.text.magnifyingglass",
                        iconColor: Color.orange,
                        title: "\(viewModel.pendingApprovalsCount) Pending Approval\(viewModel.pendingApprovalsCount > 1 ? "s" : "")",
                        subtitle: "Expense updates waiting for review",
                        badgeColor: Color.orange
                    ) {
                        onPendingApprovalsTap?()
                    }
                }
                
                if viewModel.unreadMessagesCount > 0 {
                    if viewModel.pendingApprovalsCount > 0 {
                        Divider()
                            .padding(.leading, 40)
                    }
                    
                    NotificationSummaryItemView(
                        icon: "bubble.left.and.bubble.right.fill",
                        iconColor: Color.blue,
                        title: "\(viewModel.unreadMessagesCount) Unread Message\(viewModel.unreadMessagesCount > 1 ? "s" : "")",
                        subtitle: "New messages in your chats",
                        badgeColor: Color.blue
                    ) {
                        onMessagesTap?()
                    }
                }
                
                if viewModel.expenseChatUpdatesCount > 0 {
                    if viewModel.pendingApprovalsCount > 0 || viewModel.unreadMessagesCount > 0 {
                        Divider()
                            .padding(.leading, 40)
                    }
                    
                    NotificationSummaryItemView(
                        icon: "message.badge.fill",
                        iconColor: Color.green,
                        title: "\(viewModel.expenseChatUpdatesCount) Expense Discussion\(viewModel.expenseChatUpdatesCount > 1 ? "s" : "")",
                        subtitle: "Recent updates on your expenses",
                        badgeColor: Color.green
                    ) {
                        onExpenseChatsTap?()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Notification Item View

struct NotificationSummaryItemView: View {
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
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
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
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let viewModel = NotificationViewModel()
    viewModel.pendingApprovalsCount = 3
    viewModel.unreadMessagesCount = 2
    viewModel.expenseChatUpdatesCount = 1
    
    return NotificationSummaryView(viewModel: viewModel)
        .padding()
}

