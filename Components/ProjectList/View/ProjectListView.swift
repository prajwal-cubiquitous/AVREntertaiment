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
    @State private var selectedProject: Project?
    @State private var shouldNavigateToDashboard = false
    @State private var showingTempApproval = false
    @State private var tempApproverData: TempApprover?
    @State private var projectTempStatuses: [String: TempApproverStatus] = [:]
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
                        let filteredCount = viewModel.filteredProjectsForTempApprover.count
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
            if role == .APPROVER {
                loadTempApproverStatuses()
            }
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
        .sheet(isPresented: $viewModel.showingRejectionSheet) {
            tempApproverRejectionSheet
        }
        .sheet(isPresented: $showingTempApproval) {
            if let project = selectedProject, let tempApprover = tempApproverData {
                TempApproverApprovalView(
                    project: project,
                    tempApprover: tempApprover,
                    onAccept: {
                        await viewModel.acceptTempApproverRole()
                        showingTempApproval = false
                        shouldNavigateToDashboard = true
                    },
                    onReject: { reason in
                        await viewModel.confirmRejectionWithReason(reason)
                        showingTempApproval = false
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTempApproverStatuses() {
        Task {
            var statuses: [String: TempApproverStatus] = [:]
            
            for project in viewModel.projects {
                if let projectId = project.id,
                   let tempApprover = await viewModel.getTempApproverForProject(project) {
                    statuses[projectId] = tempApprover.status
                }
            }
            
            await MainActor.run {
                projectTempStatuses = statuses
            }
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
                    .applysymbolRenderingModeIfAvailable
                
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
        ZStack {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.small) {
                    // Project cards
                    ForEach(viewModel.filteredProjectsForTempApprover) { project in
                    if role == .APPROVER {
                        Button(action: {
                            Task {
                                selectedProject = project
                                let needsApproval = await viewModel.checkTempApproverStatusForProject(project)
                                if needsApproval {
                                    // Show temp approver approval view
                                    if let tempApprover = await viewModel.getTempApproverForProject(project) {
                                        tempApproverData = tempApprover
                                        showingTempApproval = true
                                    }
                                } else {
                                    shouldNavigateToDashboard = true
                                }
                            }
                        }) {
                            ProjectCell(
                                project: project, 
                                role: role, 
                                tempApproverStatus: projectTempStatuses[project.id ?? ""]
                            )
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            HapticManager.selection()
                        })
                    } else if role == .ADMIN {
                        NavigationLink(destination: DashboardView(project: project, role: role, phoneNumber: viewModel.phoneNumber)) {
                            ProjectCell(
                                project: project, 
                                role: role, 
                                tempApproverStatus: projectTempStatuses[project.id ?? ""]
                            )
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            HapticManager.selection()
                        })
                    } else {
                        NavigationLink(destination: ProjectDetailView(project: project,role: role, phoneNumber: viewModel.phoneNumber)) {
                            ProjectCell(
                                project: project, 
                                role: role, 
                                tempApproverStatus: projectTempStatuses[project.id ?? ""]
                            )
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
            .animation(DesignSystem.Animation.standardSpring, value: viewModel.filteredProjectsForTempApprover)
            .navigationDestination(isPresented: $shouldNavigateToDashboard) {
                if let project = selectedProject {
                    DashboardView(project: project, role: role, phoneNumber: viewModel.phoneNumber)
                }
            }
            
            // Temporary Approver Status Overlay
            if viewModel.tempApproverStatus == .pending {
                tempApproverPendingOverlay
            }
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
    
    // MARK: - Temporary Approver Views
    
    private var tempApproverPendingOverlay: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .blur(radius: 0.5)
            
            // Content
            VStack(spacing: DesignSystem.Spacing.large) {
                Image(systemName: "person.badge.clock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .applysymbolRenderingModeIfAvailable
                
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Text("Temporary Approver Role")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("You have been assigned as a temporary approver for a project. Please accept or reject this role to continue.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.large)
                }
                
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Button("Accept") {
                        Task {
                            await viewModel.acceptTempApproverRole()
                            // Navigate to dashboard after acceptance
//                            shouldNavigateToDashboard = true
                        }
                    }
                    .primaryButton()
                    
                    Button("Reject") {
                        viewModel.rejectTempApproverRole()
                    }
                    .secondaryButton()
                }
                .padding(.horizontal, DesignSystem.Spacing.large)
            }
            .padding(DesignSystem.Spacing.extraLarge)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(.regularMaterial)
                    .shadow(radius: 20)
            )
            .padding(.horizontal, DesignSystem.Spacing.large)
        }
    }
    
    private var tempApproverRejectionSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.large) {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "person.badge.clock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                        .applysymbolRenderingModeIfAvailable
                    
                    Text("Reject Temporary Approver Role")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Please provide a reason for rejecting this temporary approver role. This will help us understand your decision.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Reason for Rejection")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your reason...", text: $viewModel.rejectionReason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Spacer()
                
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Button("Cancel") {
                        viewModel.showingRejectionSheet = false
                        viewModel.rejectionReason = ""
                    }
                    .secondaryButton()
                    
                    Button("Confirm Rejection") {
                        Task {
                            await viewModel.confirmRejection()
                        }
                    }
                    .primaryButton()
                    .disabled(viewModel.rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(DesignSystem.Spacing.large)
            .navigationTitle("Reject Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        viewModel.showingRejectionSheet = false
                        viewModel.rejectionReason = ""
                    }
                }
            }
        }
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
