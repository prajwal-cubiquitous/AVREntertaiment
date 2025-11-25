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
    @State private var declinedProjects: [Project] = []
    @State private var inReviewProjects: [Project] = []
    @State private var userNames: [String: String] = [:] // rejectedBy: name
    @State private var isLoading = false
    
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
                // For ADMIN: Show declined projects
                if declinedProjects.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    declinedProjectsListView
                }
            } else if role == .APPROVER {
                // For APPROVER: Show IN_REVIEW projects
                if inReviewProjects.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    inReviewProjectsListView
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
            } else if role == .APPROVER {
                loadInReviewProjects()
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
    
    // MARK: - Declined Projects List (ADMIN)
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
    
    // MARK: - IN_REVIEW Projects List (APPROVER)
    private var inReviewProjectsListView: some View {
        VStack(spacing: 0) {
            // Header
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
            
            // IN_REVIEW projects list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(inReviewProjects) { project in
                        InReviewProjectNotificationCell(
                            project: project,
                            onTap: {
                                HapticManager.selection()
                                onProjectSelected(project)
                            }
                        )
                        
                        if project.id != inReviewProjects.last?.id {
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
                
                // Updated date
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(dateFormatter.string(from: project.updatedAt.dateValue()))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
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
