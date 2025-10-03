//
//  NotificationsView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import SwiftUI

struct NotificationsView: View {
    @Binding var showingPendingApprovals: Bool
    @State var OpenPendingApprovals: Bool = false
    let project: Project
    let role: UserRole?
    let phoneNumber:String
    // Static notifications for demo
    private let notifications: [NotificationItem] = [
        NotificationItem(
            id: "1",
            title: "New expense submitted:",
            message: "Set Design, ₹7,900",
            timestamp: Date().addingTimeInterval(-120),
            type: .expenseSubmitted
        ),
        NotificationItem(
            id: "2",
            title: "Expense approved:",
            message: "Costumes, ₹1,375",
            timestamp: Date().addingTimeInterval(-3600),
            type: .expenseApproved
        ),
        NotificationItem(
            id: "3",
            title: "3 expenses pending review",
            message: "Today",
            timestamp: Date(),
            type: .pendingReview
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Notifications")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Today")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DesignSystem.Spacing.medium)
            .padding(.bottom, DesignSystem.Spacing.small)
            
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.small)
            
            // Notifications List
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.extraSmall) {
                    ForEach(notifications, id: \.id) { notification in
                        NotificationRow(notification: notification)
                        
                        if notification.id != notifications.last?.id {
                            Divider()
                                .padding(.leading, 44) // Align with content
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
            }
            
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.small)
            
            // View All Button
            Button {
                // View all action
                OpenPendingApprovals = true
            } label: {
                Text("View all")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.vertical, DesignSystem.Spacing.medium)
                    .frame(maxWidth: .infinity)
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $OpenPendingApprovals) {
            NavigationStack {
                PendingApprovalsView(role: role, project: project, phoneNumber: phoneNumber)
            }
        }

    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let notification: NotificationItem
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.timestamp, relativeTo: Date())
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
            // Icon
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(iconColor)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(notification.title)
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(timeAgo)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(notification.message)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .contentShape(Rectangle())
    }
    
    private var iconName: String {
        switch notification.type {
        case .expenseSubmitted:
            return "plus.circle.fill"
        case .expenseApproved:
            return "checkmark.circle.fill"
        case .expenseRejected:
            return "xmark.circle.fill"
        case .pendingReview:
            return "clock.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .expenseSubmitted:
            return .blue
        case .expenseApproved:
            return .green
        case .expenseRejected:
            return .red
        case .pendingReview:
            return .orange
        }
    }
}

//#Preview {
//    NotificationsView(showingPendingApprovals: .constant(false))
//        .frame(width: 300, height: 400)
//        .background(Color(.systemBackground))
//} 
