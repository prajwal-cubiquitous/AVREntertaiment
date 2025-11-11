//
//  AddTeamMemberView.swift
//  AVREntertainment
//
//  Created by Auto on 12/19/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AddTeamMemberView: View {
    let project: Project
    let stateManager: DashboardStateManager
    let onMemberAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddTeamMemberViewModel()
    @State private var searchText = ""
    @State private var selectedUser: User?
    @State private var isAdding = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var filteredUsers: [User] {
        if searchText.isEmpty {
            return viewModel.availableUsers.filter { user in
                // Filter out users already in the project
                !project.teamMembers.contains(user.phoneNumber)
            }
        } else {
            return viewModel.availableUsers.filter { user in
                let matchesSearch = user.name.localizedCaseInsensitiveContains(searchText) ||
                                  user.phoneNumber.contains(searchText) ||
                                  (user.email?.localizedCaseInsensitiveContains(searchText) ?? false)
                let notInProject = !project.teamMembers.contains(user.phoneNumber)
                return matchesSearch && notInProject
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if filteredUsers.isEmpty {
                    emptyView
                } else {
                    usersListView
                }
            }
            .navigationTitle("Add Team Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            viewModel.loadAvailableUsers(for: project)
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search by name, phone, or email...", text: $searchText)
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
            
            Text("Loading users...")
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
            
            Text(searchText.isEmpty ? "No Available Users" : "No Results Found")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.top)
            
            Text(searchText.isEmpty ? 
                 "All users are already added to this project." :
                 "No users match \"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Users List View
    private var usersListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredUsers) { user in
                    UserRowView(user: user) {
                        selectedUser = user
                        addUserToProject(user)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Add User to Project
    private func addUserToProject(_ user: User) {
        guard let projectId = project.id else { return }
        
        isAdding = true
        
        Task {
            do {
                let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
                
                // Get member identifier (phone number for regular users, email for admin)
                let memberId = user.role == .ADMIN ? (user.email ?? "") : user.phoneNumber
                
                // Add member immediately to state manager (before Firebase update)
                stateManager.addTeamMember(user, memberId: memberId)
                
                // Get current team members
                let projectRef = FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                
                let projectDoc = try await projectRef.getDocument()
                if let data = projectDoc.data(),
                   var teamMembers = data["teamMembers"] as? [String] {
                    // Add the member if not already in the array
                    if !teamMembers.contains(memberId) {
                        teamMembers.append(memberId)
                        
                        // Update the project
                        try await projectRef.updateData([
                            "teamMembers": teamMembers
                        ])
                        
                        // Update state manager with final list
                        await MainActor.run {
                            stateManager.updateTeamMembers(stateManager.teamMembers, memberIds: teamMembers)
                            onMemberAdded()
                            isAdding = false
                            HapticManager.notification(.success)
                            // Notify that project was updated
                            NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
                            dismiss()
                        }
                    } else {
                        // Rollback state manager change
                        stateManager.removeTeamMember(memberId: memberId)
                        await MainActor.run {
                            isAdding = false
                            errorMessage = "User is already a team member"
                            showingError = true
                        }
                    }
                }
            } catch {
                print("❌ Error adding team member: \(error)")
                // Rollback state manager change
                if let user = selectedUser {
                    let memberId = user.role == .ADMIN ? (user.email ?? "") : user.phoneNumber
                    stateManager.removeTeamMember(memberId: memberId)
                }
                await MainActor.run {
                    isAdding = false
                    errorMessage = "Failed to add team member: \(error.localizedDescription)"
                    showingError = true
                    HapticManager.notification(.error)
                }
            }
        }
    }
}

// MARK: - User Row View
struct UserRowView: View {
    let user: User
    let onAdd: () -> Void
    @State private var isAdding = false
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            isAdding = true
            onAdd()
        }) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(user.role.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Text(user.name.prefix(1).uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(user.role.color)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(user.phoneNumber.isEmpty ? (user.email ?? "") : user.phoneNumber)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // Role indicator
                    HStack {
                        Circle()
                            .fill(user.role.color)
                            .frame(width: 8, height: 8)
                        
                        Text(user.role.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                // Add button
                if isAdding {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(isAdding)
    }
}

// MARK: - Add Team Member ViewModel
@MainActor
class AddTeamMemberViewModel: ObservableObject {
    @Published var availableUsers: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadAvailableUsers(for project: Project) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
                let db = Firestore.firestore()
                
                // Load all users for this customer
                let snapshot = try await db
                    .collection("users")
                    .whereField("ownerID", isEqualTo: customerId)
                    .whereField("role", isEqualTo: "USER")
                    .getDocuments()
                
                var loadedUsers: [User] = []
                for document in snapshot.documents {
                    do {
                        var user = try document.data(as: User.self)
                        user.id = document.documentID
                        loadedUsers.append(user)
                    } catch {
                        print("❌ Error decoding user document \(document.documentID): \(error)")
                    }
                }
                
                // Sort by name
                loadedUsers.sort { $0.name < $1.name }
                
                await MainActor.run {
                    self.availableUsers = loadedUsers
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading available users: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load users: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

