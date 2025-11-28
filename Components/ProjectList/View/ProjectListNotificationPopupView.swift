//
//  ProjectListNotificationPopupView.swift
//  AVREntertainment
//
//  Created for ProjectListView notification popup
//

import SwiftUI
import FirebaseFirestore

struct ProjectListNotificationPopupView: View {
    @ObservedObject var viewModel: ProjectListViewModel
    let role: UserRole
    let onProjectSelected: (Project) -> Void
    var onPhaseRequestSelected: ((PhaseRequestItem, Project) -> Void)? = nil
    @State private var declinedProjects: [Project] = []
    @State private var inReviewProjects: [Project] = []
    @State private var userNames: [String: String] = [:] // rejectedBy: name
    @State private var isLoading = false
    @StateObject private var phaseRequestNotificationViewModel = PhaseRequestNotificationViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @State private var showingAllPhaseRequests = false
    @State private var showingAllNotifications = false
    @State private var allPhaseRequests: [PhaseRequestItem] = []
    @State private var phaseRequestProjectMap: [String: String] = [:] // Maps request ID to project ID
    @EnvironmentObject var authService: FirebaseAuthService
    
    // Limit number of items shown in popup
    private let maxItemsToShow = 3
    
    private var customerId: String? {
        authService.currentCustomerId
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.showingFullNotifications = false
                    }
                }
            
            // Popup content - centered
            if role == .ADMIN {
                // For ADMIN: Show sections with phase requests and notifications
                if hasNoAdminNotifications {
                    emptyStateView
                } else {
                    adminNotificationsListView
                }
            } else if role == .APPROVER {
                // For APPROVER: Show sections with IN_REVIEW projects and notifications
                if hasNoApproverNotifications {
                    emptyStateView
                } else {
                    approverNotificationsListView
                }
            } else {
                // For other roles: Show pending expenses (existing behavior)
                if viewModel.pendingExpenses.isEmpty {
                    emptyStateView
                } else {
                    notificationsListView
                }
            }
        }
        .onAppear {
            if role == .ADMIN {
                loadDeclinedProjects()
                loadAllPhaseRequests()
                notificationViewModel.loadSavedNotifications()
            } else if role == .APPROVER {
                loadInReviewProjects()
                notificationViewModel.loadSavedNotifications()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotificationManagerUpdated"))) { _ in
            if role == .ADMIN {
                notificationViewModel.loadSavedNotifications()
            } else if role == .APPROVER {
                notificationViewModel.loadSavedNotifications()
            }
        }
        .sheet(isPresented: $showingAllPhaseRequests) {
            AllPhaseRequestsListView(
                requests: allPhaseRequests,
                projectMap: phaseRequestProjectMap,
                projects: viewModel.projects,
                onRequestTap: { request in
                    // Show phase request sheet for this request
                    if let projectId = phaseRequestProjectMap[request.id],
                       let project = viewModel.projects.first(where: { $0.id == projectId }) {
                        showingAllPhaseRequests = false
                        // Use phase request callback if available, otherwise fallback to project selection
                        if let onPhaseRequestSelected = onPhaseRequestSelected {
                            onPhaseRequestSelected(request, project)
                        } else {
                            viewModel.showingFullNotifications = false
                            onProjectSelected(project)
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showingAllNotifications) {
            AllNotificationsListView(
                notifications: notificationViewModel.savedNotifications,
                onNotificationTap: { notification in
                    // This will be handled in the view itself
                },
                role: role,
                projects: viewModel.projects
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasNoAdminNotifications: Bool {
        declinedProjects.isEmpty && 
        allPhaseRequests.isEmpty && 
        notificationViewModel.savedNotifications.isEmpty && 
        !isLoading
    }
    
    private var hasNoApproverNotifications: Bool {
        inReviewProjects.isEmpty && 
        notificationViewModel.savedNotifications.isEmpty && 
        !isLoading
    }
    
    // MARK: - Load All Phase Requests
    
    private func loadAllPhaseRequests() {
        Task {
            guard let customerId = customerId else { return }
            
            var allRequests: [(PhaseRequestItem, String)] = [] // Store request with projectId
            
            // Load phase requests from all projects
            for project in viewModel.projects {
                if let projectId = project.id {
                    await phaseRequestNotificationViewModel.loadPendingRequests(
                        projectId: projectId,
                        customerId: customerId
                    )
                    // Store requests with their projectId
                    for request in phaseRequestNotificationViewModel.pendingRequests {
                        allRequests.append((request, projectId))
                    }
                }
            }
            
            await MainActor.run {
                // Extract just the requests for display
                allPhaseRequests = allRequests.map { $0.0 }
                // Store projectId mapping in a dictionary for navigation
                phaseRequestProjectMap = Dictionary(uniqueKeysWithValues: allRequests.map { ($0.0.id, $0.1) })
            }
        }
    }
    
    // MARK: - Load Declined Projects
    private func loadDeclinedProjects() {
        isLoading = true
        
        Task {
            // Filter and sort declined projects
            let declined = viewModel.projects
                .filter { $0.statusType == .DECLINED }
                .sorted { $0.updatedAt.dateValue() > $1.updatedAt.dateValue() }
            
            await MainActor.run {
                declinedProjects = declined
                isLoading = false
            }
            
            // Load user names for rejectedBy fields
            await loadUserNames(for: declined)
        }
    }
    
    // MARK: - Load IN_REVIEW Projects (for APPROVER)
    private func loadInReviewProjects() {
        isLoading = true
        
        Task {
            // Filter and sort IN_REVIEW projects
            let inReview = viewModel.projects
                .filter { $0.statusType == .IN_REVIEW }
                .sorted { $0.updatedAt.dateValue() > $1.updatedAt.dateValue() }
            
            await MainActor.run {
                inReviewProjects = inReview
                isLoading = false
            }
        }
    }
    
    // MARK: - Load User Names
    private func loadUserNames(for projects: [Project]) async {
        let uniqueRejectedBy = Set(projects.compactMap { $0.rejectedBy })
        
        for rejectedBy in uniqueRejectedBy {
            if userNames[rejectedBy] == nil {
                if let name = await fetchUserName(phoneNumber: rejectedBy) {
                    await MainActor.run {
                        userNames[rejectedBy] = name
                    }
                }
            }
        }
    }
    
    // MARK: - Fetch User Name
    private func fetchUserName(phoneNumber: String) async -> String? {
        do {
            let db = Firestore.firestore()
            var cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove +91 prefix if present
            if cleanPhone.hasPrefix("+91") {
                cleanPhone = String(cleanPhone.dropFirst(3))
            }
            cleanPhone = cleanPhone.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try to get user by document ID (phone number)
            let userDoc = try await db
                .collection("users")
                .document(cleanPhone)
                .getDocument()
            
            if let userData = userDoc.data(),
               let name = userData["name"] as? String, !name.isEmpty {
                return name
            }
            
            // Fallback: try query by phoneNumber field
            let userQuery = try await db
                .collection("users")
                .whereField("phoneNumber", isEqualTo: cleanPhone)
                .limit(to: 1)
                .getDocuments()
            
            if let userData = userQuery.documents.first?.data(),
               let name = userData["name"] as? String, !name.isEmpty {
                return name
            }
            
            // If not found, return formatted phone number
            return cleanPhone.formatPhoneNumber
        } catch {
            print("Error loading user name for \(phoneNumber): \(error)")
            return phoneNumber.formatPhoneNumber
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Bell icon
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
            
            // Title
            Text("No Notifications")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            // Message
            Text("You're all caught up!")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            // Close button
            Button {
                HapticManager.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.showingFullNotifications = false
                }
            } label: {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 320)
        .scaleEffect(viewModel.showingFullNotifications ? 1.0 : 0.9)
        .opacity(viewModel.showingFullNotifications ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showingFullNotifications)
    }
    
    // MARK: - Admin Notifications List View
    
    private var adminNotificationsListView: some View {
        VStack(spacing: 0) {
            // Header
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Phase Requests Section
                    if !allPhaseRequests.isEmpty {
                        phaseRequestsSection
                        
                        if !declinedProjects.isEmpty || !notificationViewModel.savedNotifications.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                    
                    // Declined Projects Section
                    if !declinedProjects.isEmpty {
                        declinedProjectsSection
                        
                        if !notificationViewModel.savedNotifications.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                    
                    // Normal Notifications Section
                    if !notificationViewModel.savedNotifications.isEmpty {
                        normalNotificationsSection
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            // Close button
            Button {
                HapticManager.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.showingFullNotifications = false
                }
            } label: {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 340, maxHeight: 500)
        .scaleEffect(viewModel.showingFullNotifications ? 1.0 : 0.9)
        .opacity(viewModel.showingFullNotifications ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showingFullNotifications)
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
                Text("\(allPhaseRequests.count)")
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
            let itemsToShow = Array(allPhaseRequests.prefix(maxItemsToShow))
            ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, request in
                PhaseRequestNotificationRow(
                    request: request,
                    onTap: {
                        // Find project for this request and show phase request sheet
                        if let projectId = phaseRequestProjectMap[request.id],
                           let project = viewModel.projects.first(where: { $0.id == projectId }) {
                            HapticManager.selection()
                            // Use phase request callback if available, otherwise fallback to project selection
                            if let onPhaseRequestSelected = onPhaseRequestSelected {
                                onPhaseRequestSelected(request, project)
                            } else {
                                viewModel.showingFullNotifications = false
                                onProjectSelected(project)
                            }
                        }
                    }
                )
                
                if index < itemsToShow.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
            
            // View All button if there are more items
            if allPhaseRequests.count > maxItemsToShow {
                Button {
                    HapticManager.selection()
                    showingAllPhaseRequests = true
                } label: {
                    HStack {
                        Spacer()
                        Text("View All (\(allPhaseRequests.count))")
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
    
    // MARK: - Declined Projects Section
    
    private var declinedProjectsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("DECLINED PROJECTS")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                // Badge with count
                Text("\(declinedProjects.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Declined project items (limited)
            let itemsToShow = Array(declinedProjects.prefix(maxItemsToShow))
            ForEach(itemsToShow) { project in
                DeclinedProjectNotificationCell(
                    project: project,
                    rejectedByName: userNames[project.rejectedBy ?? ""] ?? project.rejectedBy?.formatPhoneNumber ?? "Unknown",
                    onTap: {
                        HapticManager.selection()
                        onProjectSelected(project)
                    }
                )
                
                if project.id != itemsToShow.last?.id {
                    Divider()
                        .padding(.leading, 16)
                }
            }
            
            // View All button if there are more items
            if declinedProjects.count > maxItemsToShow {
                Button {
                    HapticManager.selection()
                    // Show all declined projects in a sheet
                    // For now, just show all in the same view
                } label: {
                    HStack {
                        Spacer()
                        Text("View All (\(declinedProjects.count))")
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
    
    // MARK: - Normal Notifications Section
    
    private var normalNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("NOTIFICATIONS")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                // Badge with count
                Text("\(notificationViewModel.savedNotifications.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Notification items (limited)
            let itemsToShow = Array(notificationViewModel.savedNotifications.prefix(maxItemsToShow))
            ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, notification in
                NotificationPopupRowView(
                    icon: iconForNotification(notification),
                    iconColor: colorForNotification(notification),
                    title: formattedNotificationTitle(for: notification),
                    message: formattedNotificationMessage(for: notification),
                    timeAgo: timeAgoString(from: notification.date)
                ) {
                    HapticManager.selection()
                    NotificationManager.shared.removeNotification(byId: notification.id)
                    let data = notification.data.mapValues { $0.value }
                    
                    // Debug: Check if expenseId is in notification data
                    if let screen = data["screen"] as? String, screen == "expense_detail" || screen == "expense_review" {
                        if let expenseId = data["expenseId"] as? String {
                            print("📋 ProjectListNotificationPopupView: expense_detail, expenseId: \(expenseId)")
                        } else {
                            print("⚠️ ProjectListNotificationPopupView: expense_detail but no expenseId in data")
                        }
                    }
                    
                    // Close notification popup first
                    viewModel.showingFullNotifications = false
                    
                    // Small delay to allow popup to close smoothly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        // Handle navigation with role awareness
                        NotificationManager.shared.handleNavigation(
                            data: data,
                            currentRole: role,
                            currentProjectId: nil
                        )
                    }
                    
                    // Reload notifications
                    notificationViewModel.loadSavedNotifications()
                }
                
                if index < itemsToShow.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
            
            // View All button if there are more items
            if notificationViewModel.savedNotifications.count > maxItemsToShow {
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
    
    // MARK: - Helper Methods
    
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
    
    // MARK: - Notification Formatting
    
    /// Formats notification title based on notification type and data
    private func formattedNotificationTitle(for notification: AppNotification) -> String {
        // Try to get projectId from multiple sources
        let projectId = notification.projectId ?? 
                       notification.data["projectId"]?.value as? String
        
        // Check screen type or notification type
        let screen = notification.data["screen"]?.value as? String
        let type = notification.data["type"]?.value as? String
        
        // Debug logging
        print("🔔 Formatting notification: title='\(notification.title)', projectId=\(projectId ?? "nil"), screen=\(screen ?? "nil"), type=\(type ?? "nil")")
        
        // Handle chat notifications - check multiple conditions
        let isChatNotification = screen == "chat_detail" || 
                                 screen == "chat_screen" || 
                                 type == "chat_message" || 
                                 type == "project_communication" ||
                                 notification.title.localizedCaseInsensitiveContains("Communication") || 
                                 notification.title.localizedCaseInsensitiveContains("chat") || 
                                 notification.body.localizedCaseInsensitiveContains("sent a new message")
        
        if isChatNotification {
            // Try to get project name
            if let projectId = projectId, let project = viewModel.project(for: projectId) {
                print("✅ Found project '\(project.name)' for chat notification")
                return "\(project.name) received chat msg"
            } else {
                // If no projectId but it's a chat notification, try to find project from body
                // The body might contain project info or we can search all projects
                // For now, return formatted title without project name
                print("⚠️ No projectId for chat notification, using original title")
                return notification.title
            }
        }
        
        // For other notification types, require projectId
        guard let projectId = projectId else {
            return notification.title
        }
        
        // Get project name from viewModel
        guard let project = viewModel.project(for: projectId) else {
            print("⚠️ Project not found for ID: \(projectId) in notification formatting")
            return notification.title
        }
        
        // Handle other notification types
        if let screen = screen {
            switch screen {
            case "expense_detail", "expense_review":
                return "\(project.name) - Expense Update"
            case "expense_chat":
                return "\(project.name) - Expense Chat"
            case "phase_detail":
                return "\(project.name) - Phase Update"
            case "request_detail":
                return "\(project.name) - Phase Request"
            case "project_detail", "project_detail1":
                return "\(project.name) - Project Update"
            default:
                break
            }
        }
        
        // Handle by type if screen is not available
        if let type = type {
            switch type {
            case "expense_submitted", "expense_approved", "expense_rejected":
                return "\(project.name) - Expense Update"
            case "phase_updated", "phase_created":
                return "\(project.name) - Phase Update"
            case "project_rejected":
                return "\(project.name) - Project Rejected"
            default:
                break
            }
        }
        
        // Default: return original title
        return notification.title
    }
    
    /// Formats notification message based on notification type
    private func formattedNotificationMessage(for notification: AppNotification) -> String {
        // Return the original body message
        return notification.body
    }
    
    // MARK: - Declined Projects List (ADMIN) - Keep for backward compatibility
    private var declinedProjectsListView: some View {
        VStack(spacing: 0) {
            // Header
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
            
            // Declined projects list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(declinedProjects) { project in
                        DeclinedProjectNotificationCell(
                            project: project,
                            rejectedByName: userNames[project.rejectedBy ?? ""] ?? project.rejectedBy?.formatPhoneNumber ?? "Unknown",
                            onTap: {
                                HapticManager.selection()
                                onProjectSelected(project)
                            }
                        )
                        
                        if project.id != declinedProjects.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            // Close button
            Button {
                HapticManager.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.showingFullNotifications = false
                }
            } label: {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 340, maxHeight: 500)
        .scaleEffect(viewModel.showingFullNotifications ? 1.0 : 0.9)
        .opacity(viewModel.showingFullNotifications ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showingFullNotifications)
    }
    
    // MARK: - Approver Notifications List View
    
    private var approverNotificationsListView: some View {
        VStack(spacing: 0) {
            // Header
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    // IN_REVIEW Projects Section
                    if !inReviewProjects.isEmpty {
                        inReviewProjectsSection
                        
                        if !notificationViewModel.savedNotifications.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                    
                    // Normal Notifications Section
                    if !notificationViewModel.savedNotifications.isEmpty {
                        normalNotificationsSection
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            // Close button
            Button {
                HapticManager.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.showingFullNotifications = false
                }
            } label: {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 340, maxHeight: 500)
        .scaleEffect(viewModel.showingFullNotifications ? 1.0 : 0.9)
        .opacity(viewModel.showingFullNotifications ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showingFullNotifications)
    }
    
    // MARK: - IN_REVIEW Projects Section
    
    private var inReviewProjectsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("IN REVIEW")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                // Badge with count
                Text("\(inReviewProjects.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // IN_REVIEW project items (limited)
            let itemsToShow = Array(inReviewProjects.prefix(maxItemsToShow))
            ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, project in
                InReviewProjectNotificationCell(
                    project: project,
                    onTap: {
                        HapticManager.selection()
                        onProjectSelected(project)
                    }
                )
                
                if index < itemsToShow.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
            
            // View All button if there are more items
            if inReviewProjects.count > maxItemsToShow {
                Button {
                    HapticManager.selection()
                    // Show all IN_REVIEW projects in a sheet
                    // For now, just show all in the same view
                } label: {
                    HStack {
                        Spacer()
                        Text("View All (\(inReviewProjects.count))")
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
    
    // MARK: - Pending Expenses List (Other Roles)
    private var notificationsListView: some View {
        VStack(spacing: 0) {
            // Header
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
            
            // Notifications list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.projects) { project in
                        let projectExpenses = viewModel.pendingExpenses.filter { $0.projectId == project.id }
                        if !projectExpenses.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(project.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                
                                ForEach(projectExpenses) { expense in
                                    NotificationItemView(expense: expense)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            // Close button
            Button {
                HapticManager.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.showingFullNotifications = false
                }
            } label: {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 340, maxHeight: 500)
        .scaleEffect(viewModel.showingFullNotifications ? 1.0 : 0.9)
        .opacity(viewModel.showingFullNotifications ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showingFullNotifications)
    }
}

// MARK: - Declined Project Notification Cell
struct DeclinedProjectNotificationCell: View {
    let project: Project
    let rejectedByName: String
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter
    }
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Project name (smaller, grey - like section header)
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Project name (bold, primary color - main title)
                Text(project.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Rejection reason in red
                if let rejectionReason = project.rejectionReason, !rejectionReason.isEmpty {
                    Text(rejectionReason)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Date and rejected by info
                HStack(spacing: 12) {
                    // Rejected date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(dateFormatter.string(from: project.updatedAt.dateValue()))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Rejected by
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Rejected by: \(rejectedByName)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - IN_REVIEW Project Notification Cell
struct InReviewProjectNotificationCell: View {
    let project: Project
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter
    }
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack(spacing: 12) {
                // Icon with badge
                ZStack(alignment: .topTrailing) {
                    // Background circle
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    // SF Symbol icon
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.orange)
                        .symbolRenderingMode(.hierarchical)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Project name
                    Text(project.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Status badge and date
                    HStack(spacing: 8) {
                        // Status badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text("IN REVIEW")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.12))
                        )
                        
                        // Date
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(dateFormatter.string(from: project.updatedAt.dateValue()))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All Phase Requests List View

struct AllPhaseRequestsListView: View {
    let requests: [PhaseRequestItem]
    let projectMap: [String: String]
    let projects: [Project]
    let onRequestTap: (PhaseRequestItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if requests.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.6))
                            .symbolRenderingMode(.hierarchical)
                        
                        Text("No Phase Requests")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("You're all caught up!")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(requests) { request in
                            PhaseRequestNotificationRow(
                                request: request,
                                onTap: {
                                    onRequestTap(request)
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if let projectId = projectMap[request.id],
                                   let project = projects.first(where: { $0.id == projectId }) {
                                    Button {
                                        onRequestTap(request)
                                    } label: {
                                        Label("View Project", systemImage: "arrow.right.circle")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
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

// MARK: - All Notifications List View

struct AllNotificationsListView: View {
    let notifications: [AppNotification]
    let onNotificationTap: (AppNotification) -> Void
    let role: UserRole
    let projects: [Project] // Add projects to access project names
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
    
    // MARK: - Notification Formatting
    
    /// Formats notification title based on notification type and data
    private func formattedNotificationTitle(for notification: AppNotification) -> String {
        // Try to get projectId from multiple sources
        let projectId = notification.projectId ?? 
                       notification.data["projectId"]?.value as? String
        
        guard let projectId = projectId else {
            // If no projectId, check if title contains "New Project Communication"
            // and try to extract project info from body or other data
            if notification.title.contains("New Project Communication") || 
               notification.title.contains("Project Communication") {
                // Try to find project from body message or other notification data
                return notification.title
            }
            return notification.title
        }
        
        // Get project name from projects array
        guard let project = projects.first(where: { $0.id == projectId }) else {
            print("⚠️ Project not found for ID: \(projectId) in AllNotificationsListView formatting")
            return notification.title
        }
        
        // Check screen type or notification type
        let screen = notification.data["screen"]?.value as? String
        let type = notification.data["type"]?.value as? String
        
        // Handle chat notifications
        if screen == "chat_detail" || screen == "chat_screen" || 
           type == "chat_message" || type == "project_communication" ||
           notification.title.contains("Communication") || 
           notification.title.contains("chat") || 
           notification.body.contains("sent a new message") {
            return "\(project.name) received chat msg"
        }
        
        // Handle other notification types
        if let screen = screen {
            switch screen {
            case "expense_detail", "expense_review":
                return "\(project.name) - Expense Update"
            case "expense_chat":
                return "\(project.name) - Expense Chat"
            case "phase_detail":
                return "\(project.name) - Phase Update"
            case "request_detail":
                return "\(project.name) - Phase Request"
            case "project_detail", "project_detail1":
                return "\(project.name) - Project Update"
            default:
                break
            }
        }
        
        // Handle by type if screen is not available
        if let type = type {
            switch type {
            case "expense_submitted", "expense_approved", "expense_rejected":
                return "\(project.name) - Expense Update"
            case "phase_updated", "phase_created":
                return "\(project.name) - Phase Update"
            case "project_rejected":
                return "\(project.name) - Project Rejected"
            default:
                break
            }
        }
        
        // Default: return original title
        return notification.title
    }
    
    /// Formats notification message based on notification type
    private func formattedNotificationMessage(for notification: AppNotification) -> String {
        // Return the original body message
        return notification.body
    }
    
    var body: some View {
        NavigationStack {
            Group {
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
                } else {
                    List {
                        ForEach(notifications) { notification in
                            NotificationPopupRowView(
                                icon: iconForNotification(notification),
                                iconColor: colorForNotification(notification),
                                title: formattedNotificationTitle(for: notification),
                                message: formattedNotificationMessage(for: notification),
                                timeAgo: timeAgoString(from: notification.date)
                            ) {
                                HapticManager.selection()
                                NotificationManager.shared.removeNotification(byId: notification.id)
                                let data = notification.data.mapValues { $0.value }
                                
                                // Debug: Check if expenseId is in notification data
                                if let screen = data["screen"] as? String, screen == "expense_detail" || screen == "expense_review" {
                                    if let expenseId = data["expenseId"] as? String {
                                        print("📋 ProjectListNotificationPopupView (List): expense_detail, expenseId: \(expenseId)")
                                    } else {
                                        print("⚠️ ProjectListNotificationPopupView (List): expense_detail but no expenseId in data")
                                    }
                                }
                                
                                // Close sheet first
                                dismiss()
                                
                                // Small delay to allow sheet to close smoothly
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    // Handle navigation with role awareness
                                    NotificationManager.shared.handleNavigation(
                                        data: data,
                                        currentRole: role,
                                        currentProjectId: nil
                                    )
                                }
                                
                                // Reload notifications
                                notificationViewModel.loadSavedNotifications()
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
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
