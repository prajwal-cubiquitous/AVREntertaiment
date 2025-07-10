import SwiftUI

struct RoleManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    roleCard(
                        role: .ADMIN,
                        description: "Full access to all features including user management and project creation",
                        permissions: [
                            "Create and manage projects",
                            "Manage users and roles",
                            "View all reports and analytics",
                            "System configuration"
                        ]
                    )
                    
                    roleCard(
                        role: .APPROVER,
                        description: "Reviews and approves project expenses and changes",
                        permissions: [
                            "Review project expenses",
                            "Approve/reject requests",
                            "View project details",
                            "Generate reports"
                        ]
                    )
                    
                    roleCard(
                        role: .USER,
                        description: "Basic access to assigned projects and expense submission",
                        permissions: [
                            "View assigned projects",
                            "Submit expenses",
                            "View personal reports",
                            "Update profile"
                        ]
                    )
                } header: {
                    Text("System Roles")
                } footer: {
                    Text("Roles define the access level and permissions for users in the system")
                }
            }
            .navigationTitle("Role Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func roleCard(role: UserRole, description: String, permissions: [String]) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Permissions")
                    .font(.headline)
                    .padding(.top, 4)
                
                ForEach(permissions, id: \.self) { permission in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(permission)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.vertical, 8)
        } label: {
            HStack {
                Text(role.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text(role.rawValue)
                    .font(.caption)
                    .padding(4)
                    .background(roleColor(for: role).opacity(0.2))
                    .foregroundColor(roleColor(for: role))
                    .cornerRadius(4)
            }
        }
    }
    
    private func roleColor(for role: UserRole) -> Color {
        switch role {
        case .ADMIN:
            return .purple
        case .APPROVER:
            return .blue
        case .USER:
            return .green
        }
    }
} 