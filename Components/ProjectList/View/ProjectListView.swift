//
//  projectListView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

// ProjectListView.swift
import SwiftUI

struct ProjectListView: View {
    
    @State private var isShowingCreateSheet = false
    @State private var isShowingMenuSheet = false
    @StateObject var viewModel: ProjectListViewModel
    let role: UserRole
    
    init(phoneNumber: String = "", role: UserRole = .APPROVER) {
        _viewModel = StateObject(wrappedValue: ProjectListViewModel(phoneNumber: phoneNumber, role: role))
        self.role = role
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack {
                    // Common Header with menu button
                    HStack {
                        if !viewModel.projects.isEmpty {
                            Text("Your Projects")
                                .font(DesignSystem.Typography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        if role == .APPROVER && !viewModel.projects.isEmpty {
                            Button {
                                HapticManager.selection()
                                viewModel.showingFullNotifications = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell")
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                    
                                    if !viewModel.pendingExpenses.isEmpty {
                                        Text("\(viewModel.pendingExpenses.count)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        
                        // Status Filter for Admin
                        if role == .ADMIN && !viewModel.projects.isEmpty {
                            Menu {
                                Button("All Projects") {
                                    viewModel.updateStatusFilter(nil)
                                }
                                Divider()
                                ForEach([ProjectStatus.ACTIVE, .INACTIVE, .COMPLETED], id: \.self) { status in
                                    Button(status.displayText) {
                                        viewModel.updateStatusFilter(status)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(viewModel.selectedStatusFilter?.displayText ?? "All")
                                        .font(.subheadline)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                            }
                        }
                        
                        Button {
                            HapticManager.selection()
                            isShowingMenuSheet = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.title3)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.top, DesignSystem.Spacing.medium)
                    
                    if !viewModel.projects.isEmpty {
                        let filteredCount = viewModel.filteredProjects.count
                        Text("\(filteredCount) project\(filteredCount == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.bottom, DesignSystem.Spacing.small)
                    }
                    
                    if viewModel.projects.isEmpty {
                        emptyStateView
                    } else {
                        projectsListView
                    }
                }
                
                // Floating Action Button
                if role == .ADMIN && !viewModel.projects.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            floatingActionButton
                        }
                    }
                }
            }
            .refreshable {
                viewModel.fetchProjects()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            CreateProjectView()
        }
        .onAppear {
            viewModel.fetchProjects()
        }
        .sheet(isPresented: $viewModel.showingFullNotifications) {
            NotificationView(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingMenuSheet) {
            MenuSheetView()
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
                .presentationBackground(.regularMaterial)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Spacer()
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: role == .ADMIN ? "folder.badge.plus" : "folder.badge.questionmark")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary.opacity(0.6))
                    .symbolRenderingMode(.hierarchical)
                
                Text(role == .ADMIN ? "No Projects Yet" : "No Projects Assigned")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(.primary)
                
                Text(emptyStateMessage)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.extraLarge)
            }
            
            if role == .ADMIN {
                Button("Create First Project") {
                    HapticManager.impact(.medium)
                    isShowingCreateSheet = true
                }
                .primaryButton()
                .padding(.horizontal, DesignSystem.Spacing.extraLarge)
            }
            
            Button("Refresh") {
                HapticManager.selection()
                viewModel.fetchProjects()
            }
            .secondaryButton()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Properties
    private var emptyStateMessage: String {
        switch role {
        case .ADMIN:
            return "Start by creating your first project to organize and track your entertainment productions"
        case .APPROVER:
            return "You haven't been assigned as a manager to any projects yet. Please contact the admin to get assigned to projects."
        case .USER:
            return "You haven't been added to any projects yet. Please contact the admin to get assigned to a project team."
        default:
            return "No projects available. Please contact the administrator."
        }
    }
    
    // MARK: - Projects List
    private var projectsListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.small) {
                // Project cards
                ForEach(viewModel.filteredProjects) { project in
                    if role == .APPROVER {
                        NavigationLink(value: project) {
                            ProjectCell(project: project, role: role)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            HapticManager.selection()
                        })
                    } else if role == .ADMIN {
                        NavigationLink(destination: DashboardView(project: project, role: role)) {
                            ProjectCell(project: project, role: role)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            HapticManager.selection()
                        })
                    } else {
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            ProjectCell(project: project, role: role)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            HapticManager.selection()
                        })
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.top, DesignSystem.Spacing.small)
            .padding(.bottom, 80) // Space for FAB
        }
        .animation(DesignSystem.Animation.standardSpring, value: viewModel.filteredProjects)
        .navigationDestination(for: Project.self) { project in
            DashboardView(project: project)
        }
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        Button {
            HapticManager.impact(.medium)
            withAnimation(DesignSystem.Animation.fastSpring) {
                isShowingCreateSheet = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(Constants.PrimaryOppositeColor))
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                        .shadow(
                            color: DesignSystem.Shadow.large.color,
                            radius: DesignSystem.Shadow.large.radius,
                            x: DesignSystem.Shadow.large.x,
                            y: DesignSystem.Shadow.large.y
                        )
                )
        }
        .scaleEffect(isShowingCreateSheet ? 0.9 : 1.0)
        .animation(DesignSystem.Animation.interactiveSpring, value: isShowingCreateSheet)
        .padding(.trailing, DesignSystem.Spacing.extraLarge)
        .padding(.bottom, DesignSystem.Spacing.extraLarge)
    }
}

// MARK: - Menu Sheet View
struct MenuSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogoutAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with X button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Menu")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Settings & Account")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    HapticManager.selection()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            // Content
            VStack(spacing: DesignSystem.Spacing.medium) {
                MenuItemView(
                    icon: "info.circle.fill",
                    title: "About",
                    subtitle: "App information & version",
                    action: {
                        HapticManager.selection()
                        // Handle about action
                    }
                )
                
                MenuItemView(
                    icon: "gear.circle.fill",
                    title: "Settings",
                    subtitle: "Preferences & configuration",
                    action: {
                        HapticManager.selection()
                        // Handle settings action
                    }
                )
                
                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, 8)
                
                // Logout Button
                Button {
                    HapticManager.impact(.medium)
                    showingLogoutAlert = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign Out")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.red)
                            
                            Text("Logout from your account")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.red.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.red.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) {
                HapticManager.selection()
            }
            Button("Sign Out", role: .destructive) {
                HapticManager.notification(.success)
                dismiss()
                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogout"), object: nil)
            }
        } message: {
            Text("Are you sure you want to sign out of your account?")
        }
    }
}

// MARK: - Menu Item View
struct MenuItemView: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct NotificationPreviewItem: View {
    let expense: Expense
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.department)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(expense.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("By: \(expense.submittedBy.formatPhoneNumber)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(expense.amountFormatted)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(8)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

#Preview{
    ProjectListView(phoneNumber: "9876543210", role: .APPROVER)
}
