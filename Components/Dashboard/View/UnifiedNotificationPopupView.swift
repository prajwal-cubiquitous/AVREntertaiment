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
    @State private var showingAllPhaseRequests = false
    @State private var showingAllNotifications = false
    
    // Limit number of items shown in popup
    private let maxItemsToShow = 3
    
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
        .sheet(isPresented: $showingAllPhaseRequests) {
            AllPhaseRequestsView(
                requests: phaseRequestNotificationViewModel.pendingRequests,
                project: project,
                customerId: customerId,
                onRequestTap: { request in
                    showingAllPhaseRequests = false
                    isPresented = false
                    onPhaseRequestTap(request)
                }
            )
        }
        .sheet(isPresented: $showingAllNotifications) {
            AllNotificationsView(
                notifications: notificationViewModel.savedNotifications,
                project: project,
                onNotificationTap: { notification in
                    NotificationManager.shared.removeNotification(byId: notification.id)
                    let data = notification.data.mapValues { $0.value }
                    NotificationManager.shared.handleNavigation(data: data)
                    showingAllNotifications = false
                    isPresented = false
                }
            )
        }
    }
    
    // MARK: - Phase Requests Section
    
    private var phaseRequestsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with View All button
            HStack {
                Text("PHASE REQUESTS")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                // Badge with count
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
            
            // Phase request items (limited)
            let itemsToShow = Array(phaseRequestNotificationViewModel.pendingRequests.prefix(maxItemsToShow))
            ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, request in
                PhaseRequestNotificationRow(
                    request: request,
                    onTap: {
                        isPresented = false
                        onPhaseRequestTap(request)
                    }
                )
                
                if index < itemsToShow.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
            
            // View All button if there are more items
            if phaseRequestNotificationViewModel.pendingRequests.count > maxItemsToShow {
                Button {
                    HapticManager.selection()
                    showingAllPhaseRequests = true
                } label: {
                    HStack {
                        Spacer()
                        Text("View All (\(phaseRequestNotificationViewModel.pendingRequests.count))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - FCM Notifications Section
    
    private var fcmNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header (always show for admin, or if no phase requests)
            if role == .ADMIN {
                HStack {
                    Text("NOTIFICATIONS")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    // Badge with count
                    if notificationViewModel.savedNotifications.count > 0 {
                        Text("\(notificationViewModel.savedNotifications.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // FCM notification items (limited for admin)
            let itemsToShow = role == .ADMIN 
                ? Array(notificationViewModel.savedNotifications.prefix(maxItemsToShow))
                : Array(notificationViewModel.savedNotifications)
            
            ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, notification in
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
                if index < itemsToShow.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
            
            // View All button for admin if there are more items
            if role == .ADMIN && notificationViewModel.savedNotifications.count > maxItemsToShow {
                Button {
                    HapticManager.selection()
                    showingAllNotifications = true
                } label: {
                    HStack {
                        Spacer()
                        Text("View All (\(notificationViewModel.savedNotifications.count))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
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

struct PhaseRequestNotificationRow: View {
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

// MARK: - All Phase Requests View

struct AllPhaseRequestsView: View {
    let requests: [PhaseRequestItem]
    let project: Project
    let customerId: String?
    let onRequestTap: (PhaseRequestItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(requests) { request in
                    PhaseRequestNotificationRow(
                        request: request,
                        onTap: {
                            onRequestTap(request)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .navigationTitle("Phase Requests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.selection()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - All Notifications View

struct AllNotificationsView: View {
    let notifications: [AppNotification]
    let project: Project
    let onNotificationTap: (AppNotification) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationViewModel = NotificationViewModel()
    
    private func iconForNotification(_ notification: AppNotification) -> String {
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
    
    var body: some View {
        NavigationStack {
            if notifications.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("No Notifications")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("You're all caught up!")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            HapticManager.selection()
                            dismiss()
                        }
                    }
                }
            } else {
                List {
                    ForEach(notifications) { notification in
                        NotificationPopupRowView(
                            icon: iconForNotification(notification),
                            iconColor: colorForNotification(notification),
                            title: notification.title,
                            message: notification.body,
                            timeAgo: timeAgoString(from: notification.date)
                        ) {
                            onNotificationTap(notification)
                            // Reload notifications after removal
                            if let projectId = project.id {
                                notificationViewModel.loadSavedNotifications(for: projectId)
                            } else {
                                notificationViewModel.loadSavedNotifications()
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            HapticManager.selection()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

