import SwiftUI

struct AdminMainView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var selectedTab: AdminTab = .projects
    @State private var isShowingCreateProject = false
    @StateObject private var projectListViewModel = ProjectListViewModel(phoneNumber: "admin@avr.com", role: .ADMIN)
    
    enum AdminTab: String, CaseIterable {
        case projects = "Projects"
        case users = "User Management"
        
        var icon: String {
            switch self {
            case .projects: return "folder.fill"
            case .users: return "person.3.fill"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .projects: return "folder.fill"
            case .users: return "person.3.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Content
                TabView(selection: $selectedTab) {
                    // Projects Tab
                    projectsSection
                        .tag(AdminTab.projects)
                    
                    // User Management Tab
                    UserManagementView()
                        .environmentObject(authService)
                        .tag(AdminTab.users)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(DesignSystem.Animation.standardSpring, value: selectedTab)
                
                // Tab Bar at bottom
                customTabBar
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $isShowingCreateProject) {
            CreateProjectView()
                .environmentObject(authService)
        }
        .onAppear {
            projectListViewModel.fetchProjects()
        }
    }
    
    private var projectsSection: some View {
        VStack(spacing: 0) {
            // Projects list
            if let currentUser = authService.currentUser {
                ProjectListView(phoneNumber: currentUser.email ?? "", role: currentUser.role)
                    .environmentObject(authService)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No Projects Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Create your first project to get started")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Create Project") {
                        isShowingCreateProject = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AdminTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(DesignSystem.Animation.standardSpring) {
                        selectedTab = tab
                    }
                    HapticManager.selection()
                }) {
                    VStack(spacing: DesignSystem.Spacing.extraSmall) {
                        Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                            .font(.title3)
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        
                        Text(tab.rawValue)
                            .font(DesignSystem.Typography.caption1)
                            .fontWeight(selectedTab == tab ? .semibold : .medium)
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(
                        selectedTab == tab ?
                        Color.accentColor.opacity(0.1) :
                        Color.clear
                    )
                    .cornerRadius(DesignSystem.CornerRadius.small)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
    }
}

// MARK: - Preview
struct AdminMainView_Previews: PreviewProvider {
    static var previews: some View {
        AdminMainView()
            .environmentObject(FirebaseAuthService())
    }
} 
