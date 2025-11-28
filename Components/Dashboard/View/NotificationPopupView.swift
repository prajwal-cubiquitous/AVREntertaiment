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
    @EnvironmentObject var navigationManager: NavigationManager
    
    
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
                    if notificationViewModel.savedNotifications.isEmpty {
                        emptyStateView
                    } else {
                        notificationsContent
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
            // Load notifications immediately from local storage (instant, no async needed)
            if let projectId = project.id {
                notificationViewModel.loadSavedNotifications(for: projectId)
            } else {
                notificationViewModel.loadSavedNotifications()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotificationManagerUpdated"))) { _ in
            // Reload notifications when NotificationManager updates (when notification is removed)
            if let projectId = project.id {
                notificationViewModel.loadSavedNotifications(for: projectId)
            } else {
                notificationViewModel.loadSavedNotifications()
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
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            Divider()
            
            // Notification Items - Continuous list sorted by time
            if notificationViewModel.savedNotifications.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("No Notifications")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Display all saved FCM notifications sorted by time (newest first)
                        ForEach(Array(notificationViewModel.savedNotifications.enumerated()), id: \.element.id) { index, notification in
                            NotificationPopupRowView(
                                icon: iconForNotification(notification),
                                iconColor: colorForNotification(notification),
                                title: notification.title,
                                message: notification.body,
                                timeAgo: timeAgoString(from: notification.date)
                            ) {
                                HapticManager.selection()
                                // Remove notification when clicked
                                NotificationManager.shared.removeNotification(byId: notification.id)
                                
                                // Handle navigation when tapped
                                let data = notification.data.mapValues { $0.value }
                                
                                // Debug: Check if expenseId is in notification data
                                if let screen = data["screen"] as? String, screen == "expense_detail" || screen == "expense_review" {
                                    if let expenseId = data["expenseId"] as? String {
                                        print("📋 Notification click: expense_detail, expenseId: \(expenseId)")
                                    } else {
                                        print("⚠️ Notification click: expense_detail but no expenseId in data")
                                    }
                                }
                                
                                // Close notification popup first
                                isPresented = false
                                
                                // Small delay to allow popup to close smoothly
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    // Handle navigation with role awareness and current project context
                                    NotificationManager.shared.handleNavigation(
                                        data: data,
                                        currentRole: role,
                                        currentProjectId: project.id
                                    )
                                }
                                
                                // Reload notifications to reflect removal
                                if let projectId = project.id {
                                    notificationViewModel.loadSavedNotifications(for: projectId)
                                } else {
                                    notificationViewModel.loadSavedNotifications()
                                }
                            }
                            
                            // Add divider between items (not after last item)
                            if index < notificationViewModel.savedNotifications.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400)
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
    
    private func iconForNotification(_ notification: AppNotification) -> String {
        // Determine icon based on notification data
        if let screen = notification.data["screen"]?.value as? String {
            switch screen {
            case "chat_detail":
                return "bubble.left.and.bubble.right.fill"
            case "expense_detail", "expense_chat":
                return "doc.text.fill"
            case "phase_detail":
                return "folder.fill"
            case "request_detail":
                return "doc.badge.plus"
            default:
                return "bell.fill"
            }
        }
        return "bell.fill"
    }
    
    private func colorForNotification(_ notification: AppNotification) -> Color {
        // Determine color based on notification data
        if let screen = notification.data["screen"]?.value as? String {
            switch screen {
            case "chat_detail":
                return .blue
            case "expense_detail", "expense_chat":
                return .green
            case "phase_detail":
                return .purple
            case "request_detail":
                return .orange
            default:
                return .gray
            }
        }
        return .gray
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Notification Popup Row View (for list-style notifications)

struct NotificationPopupRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let timeAgo: String
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: {
            action?()
            HapticManager.selection()
        }) {
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
        .buttonStyle(.plain)
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

