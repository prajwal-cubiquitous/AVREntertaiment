import SwiftUI
import FirebaseFirestore

@available(iOS 14.0, *)
struct UserListView: View {
    @StateObject private var viewModel = UserListViewModel()
    @Environment(\.compatibleDismiss) private var dismiss
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
            .navigationBarTitle("All Users", displayMode: .large)
            .navigationBarItems(leading:
                Button("Done") {
                    dismiss()
                }
            )
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "Unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
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
        .onAppear {
            Task {
                await viewModel.fetchUsers()
            }
        }
        .overlay(
            Group {
                if viewModel.users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Users")
                            .font(.system(size: 22, weight: .bold))
                        Text("No users have been added yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                }
            )
        }
    }

@available(iOS 14.0, *)
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
                .accentColor(.accentColor)
                .onChange(of: isActive) { _ in
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
