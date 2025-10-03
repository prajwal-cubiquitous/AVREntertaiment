//
//  TeamMembersDetailView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/1/25.
//

import SwiftUI
import FirebaseFirestore

struct TeamMembersDetailView: View {
    let project: Project
    @StateObject private var viewModel = TeamMembersDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedRole: UserRole? = nil
    
    private var filteredMembers: [User] {
        var members = viewModel.teamMembers
        
        // Filter by search text
        if !searchText.isEmpty {
            members = members.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText) ||
                user.phoneNumber.contains(searchText) ||
                user.email?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Filter by role
        if let role = selectedRole {
            members = members.filter { $0.role == role }
        }
        
        return members
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search and Filter
                searchAndFilterView
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.teamMembers.isEmpty {
                    emptyView
                } else {
                    membersListView
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadTeamMembers(for: project)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                        .font(.title2)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("TEAM MEMBERS")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\(viewModel.teamMembers.count) members")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: { viewModel.refreshData() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Search and Filter View
    private var searchAndFilterView: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search members...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Role Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TeamFilterChip(
                        title: "All",
                        isSelected: selectedRole == nil,
                        color: .blue
                    ) {
                        selectedRole = nil
                    }
                    
                    ForEach(UserRole.allCases, id: \.self) { role in
                        TeamFilterChip(
                            title: role.displayName,
                            isSelected: selectedRole == role,
                            color: role.color
                        ) {
                            selectedRole = selectedRole == role ? nil : role
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text("Loading team members...")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.top)
            
            Spacer()
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Team Members")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.top)
            
            Text("Team members will appear here once they are added to the project.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Members List View
    private var membersListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMembers) { member in
                    TeamMemberRowView(member: member)
                }
            }
            .padding()
        }
    }
}

// MARK: - Team Member Row View
struct TeamMemberRowView: View {
    let member: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(member.role.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(member.name.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(member.role.color)
            }
            
            // Member Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Role Badge
                    Text(member.role.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(member.role.color)
                        .cornerRadius(8)
                }
                
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(member.phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                if let email = member.email, !email.isEmpty {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                // Status indicator
                HStack {
                    Circle()
                        .fill(member.role == .ADMIN ? .green : .blue)
                        .frame(width: 8, height: 8)
                    
                    Text(member.role == .ADMIN ? "Project Manager" : "Team Member")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Team Filter Chip
struct TeamFilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? color : color.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Team Members Detail ViewModel
class TeamMembersDetailViewModel: ObservableObject {
    @Published var teamMembers: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadTeamMembers(for project: Project) {
        isLoading = true
        errorMessage = nil
        
        Task {
            let db = Firestore.firestore()
            var loadedMembers: [User] = []
            
            // Load team members in parallel
            await withTaskGroup(of: User?.self) { group in
                for memberId in project.teamMembers {
                    group.addTask {
                        await self.fetchUserDetails(userId: memberId, db: db)
                    }
                }
                
                for await member in group {
                    if let member = member {
                        loadedMembers.append(member)
                    }
                }
            }
            
            // Sort members by role (Admin first, then by name)
            loadedMembers.sort { first, second in
                if first.role == .ADMIN && second.role != .ADMIN {
                    return true
                } else if first.role != .ADMIN && second.role == .ADMIN {
                    return false
                } else {
                    return first.name < second.name
                }
            }
            
            await MainActor.run {
                self.teamMembers = loadedMembers
                self.isLoading = false
            }
        }
    }
    
    private func fetchUserDetails(userId: String, db: Firestore) async -> User? {
        do {
            let document = try await db
                .collection("users_ios")
                .document(userId)
                .getDocument()
            
            if document.exists {
                return try document.data(as: User.self)
            }
            return nil
        } catch {
            print("Error fetching user \(userId): \(error)")
            return nil
        }
    }
    
    func refreshData() {
        // This would be called from the refresh button
        // For now, we'll just reload the data
        if let project = project {
            loadTeamMembers(for: project)
        }
    }
    
    private var project: Project?
    
    func setProject(_ project: Project) {
        self.project = project
    }
}

// MARK: - UserRole Extension
extension UserRole {
    var color: Color {
        switch self {
        case .ADMIN:
            return .red
        case .APPROVER:
            return .orange
        case .USER:
            return .blue
        }
    }
}
