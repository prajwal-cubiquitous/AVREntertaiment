import SwiftUI

struct UserManagementView: View {
    @State private var showCreateUser = false
    @State private var showUserList = false
    @State private var showRoleManagement = false
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.large) {
                    headerSection
                    managementOptionsSection
                }
                .padding(DesignSystem.Spacing.medium)
            }
            .navigationTitle("User Management")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showCreateUser) {
            CreateUserView()
        }
        .sheet(isPresented: $showUserList) {
            UserListView()
        }
        .sheet(isPresented: $showRoleManagement) {
            RoleManagementView()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            Text("User Management")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
            
            Text("Manage users, roles, and permissions")
                .font(DesignSystem.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignSystem.Spacing.medium)
    }
    
    private var managementOptionsSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            ManagementOptionCard(
                title: "Create New User",
                description: "Add a new user to the system with appropriate role",
                icon: "person.badge.plus",
                color: .blue,
                action: {
                    showCreateUser = true
                }
            )
            
            ManagementOptionCard(
                title: "View All Users",
                description: "Browse and manage existing users",
                icon: "person.3",
                color: .green,
                action: {
                    showUserList = true
                }
            )
            
            ManagementOptionCard(
                title: "Role Management",
                description: "Configure user roles and permissions",
                icon: "person.badge.shield.checkmark",
                color: .purple,
                action: {
                    showRoleManagement = true
                }
            )
        }
    }
}

struct ManagementOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(DesignSystem.Spacing.medium)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
struct UserManagementView_Previews: PreviewProvider {
    static var previews: some View {
        UserManagementView()
    }
} 