import SwiftUI
import FirebaseFirestore

struct UserListView: View {
    @StateObject private var viewModel = UserListViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else {
                    userList
                }
            }
            .navigationTitle("All Users")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error occurred")
        }
        .onAppear {
            Task {
                await viewModel.fetchUsers()
            }
        }
    }
    
    private var userList: some View {
        List {
            ForEach(viewModel.users) { user in
                UserRow(user: user) {
                    Task {
                        await viewModel.toggleUserStatus(user)
                    }
                }
            }
        }
        .refreshable {
            Task {
                await viewModel.fetchUsers()
            }
        }
        .overlay {
            if viewModel.users.isEmpty {
                ContentUnavailableView(
                    "No Users",
                    systemImage: "person.slash",
                    description: Text("No users have been added yet")
                )
            }
        }
    }
}

struct UserRow: View {
    let user: User
    let onToggle: () -> Void
    @State private var isActive: Bool
    
    init(user: User, onToggle: @escaping () -> Void) {
        self.user = user
        self.onToggle = onToggle
        _isActive = State(initialValue: user.isActive)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                
                Text(user.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(user.role.displayName)
                    .font(.caption)
                    .padding(4)
                    .background(roleColor.opacity(0.2))
                    .foregroundColor(roleColor)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            Toggle("", isOn: $isActive)
                .tint(.accentColor)
                .onChange(of: isActive) { oldValue, newValue in
                    onToggle()
                }
        }
        .contentShape(Rectangle())
    }
    
    private var roleColor: Color {
        switch user.role {
        case .ADMIN:
            return .purple
        case .APPROVER:
            return .blue
        case .USER:
            return .green
        }
    }
} 