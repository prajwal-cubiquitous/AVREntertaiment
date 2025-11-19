//
//  UnifiedNotificationPopupView.swift
//  AVREntertainment
//
//  Created by Auto on 1/2/25.
//

import SwiftUI
import FirebaseFirestore

struct UnifiedNotificationPopupView: View {
    @ObservedObject var notificationViewModel: NotificationViewModel
    @ObservedObject var phaseRequestNotificationViewModel: PhaseRequestNotificationViewModel
    let project: Project
    let role: UserRole?
    let phoneNumber: String
    let customerId: String?
    @Binding var isPresented: Bool
    let onPhaseRequestTap: (PhaseRequestItem) -> Void
    
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
                    if hasNoNotifications {
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
            
            // Load phase requests if admin
            if role == .ADMIN, let projectId = project.id, let customerId = customerId {
                Task {
                    await phaseRequestNotificationViewModel.loadPendingRequests(
                        projectId: projectId,
                        customerId: customerId
                    )
                }
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
    
    // MARK: - Computed Properties
    
    private var hasNoNotifications: Bool {
        let hasFCMNotifications = !notificationViewModel.savedNotifications.isEmpty
        let hasPhaseRequests = role == .ADMIN && !phaseRequestNotificationViewModel.pendingRequests.isEmpty
        return !hasFCMNotifications && !hasPhaseRequests
    }
    
    private var totalNotificationCount: Int {
        var count = notificationViewModel.unreadNotificationCount
        if role == .ADMIN {
            count += phaseRequestNotificationViewModel.pendingRequestsCount
        }
        return count
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
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Phase Requests Section (Admin only)
                    if role == .ADMIN && !phaseRequestNotificationViewModel.pendingRequests.isEmpty {
                        phaseRequestsSection
                        
                        if !notificationViewModel.savedNotifications.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                    
                    // FCM Notifications Section
                    if !notificationViewModel.savedNotifications.isEmpty {
                        fcmNotificationsSection
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)
        }
    }
    
    // MARK: - Phase Requests Section
    
    private var phaseRequestsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Phase Requests")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(phaseRequestNotificationViewModel.pendingRequestsCount)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Phase request items
            ForEach(Array(phaseRequestNotificationViewModel.pendingRequests.enumerated()), id: \.element.id) { index, request in
                PhaseRequestNotificationRow(
                    request: request,
                    onTap: {
                        isPresented = false
                        onPhaseRequestTap(request)
                    }
                )
                
                if index < phaseRequestNotificationViewModel.pendingRequests.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
    }
    
    // MARK: - FCM Notifications Section
    
    private var fcmNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header (only show if there are phase requests above)
            if role == .ADMIN && !phaseRequestNotificationViewModel.pendingRequests.isEmpty {
                HStack {
                    Text("Notifications")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // FCM notification items
            ForEach(Array(notificationViewModel.savedNotifications.enumerated()), id: \.element.id) { index, notification in
                NotificationPopupRowView(
                    icon: iconForNotification(notification),
                    iconColor: colorForNotification(notification),
                    title: notification.title,
                    message: notification.body,
                    timeAgo: timeAgoString(from: notification.date)
                ) {
                    // Remove notification when clicked
                    NotificationManager.shared.removeNotification(byId: notification.id)
                    
                    // Handle navigation when tapped
                    let data = notification.data.mapValues { $0.value }
                    NotificationManager.shared.handleNavigation(data: data)
                    
                    // Reload notifications to reflect removal
                    if let projectId = project.id {
                        notificationViewModel.loadSavedNotifications(for: projectId)
                    } else {
                        notificationViewModel.loadSavedNotifications()
                    }
                    
                    isPresented = false
                }
                
                // Add divider between items (not after last item)
                if index < notificationViewModel.savedNotifications.count - 1 {
                    Divider()
                        .padding(.leading, 56)
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

// MARK: - Phase Request Notification Row

private struct PhaseRequestNotificationRow: View {
    let request: PhaseRequestItem
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }
    
    private var requestDate: String {
        request.createdAt.dateValue().formatted(date: .abbreviated, time: .omitted)
    }
    
    var body: some View {
        Button(action: {
            onTap()
            HapticManager.selection()
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Status icon
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(request.phaseName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(requestDate)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    if let userName = request.userName, !userName.isEmpty {
                        Text(userName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if let phoneNumber = request.userPhoneNumber, !phoneNumber.isEmpty {
                        Text(phoneNumber)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text("Extend to: \(request.extendedDate)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

