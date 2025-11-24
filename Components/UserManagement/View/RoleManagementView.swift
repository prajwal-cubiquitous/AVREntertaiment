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
                        title: "Administrator",
                        description: "System administrator for support, security, and backups.",
                        permissions: [
                            "Maintain system configuration and integrations",
                            "Manage data backups and recovery",
                            "Resolve user access and login issues",
                            "Monitor system health and audit logs "
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
                    
                    // Information card: Production Head (maps to admin-level permissions)
                    roleCard(
                        role: .HEAD,
                        title: "Production Head",
                        description: "Full administrative access to manage projects, users, and approvals",
                        permissions: [
                            "Oversee all projects and budgets",
                            "Manage users and roles",
                            "Review and approve expenses",
                            "Access all reports and analytics"
                        ]
                    )
                    
                    roleCard(
                        role: .USER,
                        description: "Basic access to assigned projects and expense submission",
                        permissions: [
                            "View assigned projects",
                            "Submit expenses",
                            "View personal reports"                        ]
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
    
    private func roleCard(role: UserRole, title: String? = nil, description: String, permissions: [String]) -> some View {
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
                Text(title ?? role.displayName)
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
        case .HEAD:
            return .orange
        @unknown default:
            return .gray
        }
    }
} 
