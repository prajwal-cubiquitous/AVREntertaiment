//
//  projectListView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

// ProjectListView.swift
import SwiftUI
import FirebaseFirestore


struct ProjectListView: View {
    
    @State private var isShowingCreateSheet = false
    @State private var isShowingMenuSheet = false
    @State private var selectedProject: Project?
    @State private var shouldNavigateToDashboard = false
    @State private var showingTempApproval = false
    @State private var tempApproverData: TempApprover?
    @State private var projectTempStatuses: [String: TempApproverStatus] = [:]
    @State private var businessName: String = "Your Projects"
    @State private var projectToReview: Project?
    @State private var showingReports = false
    @State private var searchText: String = ""
    @State private var showingBusinessNameAlert = false
    @State private var selectedDeclinedProject: Project?
    @State private var showingDeclinedProjectEdit = false
    @State private var selectedInReviewProject: Project?
    @StateObject var viewModel: ProjectListViewModel
    @StateObject private var sharedStateManager = DashboardStateManager()
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.scenePhase) private var scenePhase
    let role: UserRole
    
    init(phoneNumber: String = "", role: UserRole = .APPROVER, customerId: String? = nil) {
        _viewModel = StateObject(wrappedValue: ProjectListViewModel(phoneNumber: phoneNumber, role: role, customerId: customerId))
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
                    HStack(spacing: 8) {
                        HStack(spacing: 0) {
                            Text(truncatedBusinessName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
//                                .lineLimit(1)
//                                .truncationMode(.tail)
//                                .allowsTightening(false)
//                            
                            if shouldShowTruncation {
                                Text("...")  // Whatever dots YOU want
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                                    .onTapGesture {
                                        HapticManager.selection()
                                        showingBusinessNameAlert = true
                                    }
                            }
                        }

                        
                        Spacer(minLength: 4)
                        
                        // Show notification bell for all roles
                        if !viewModel.projects.isEmpty {
                            Button {
                                HapticManager.selection()
                                viewModel.showingFullNotifications = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell")
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                    
                                    if shouldShowNotificationBadge {
                                        Text("\(notificationBadgeCount)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        // Status Filter for Admin
                        if role == .ADMIN && !viewModel.projects.isEmpty {
                            Menu {
                                Button("All Projects") {
                                    viewModel.updateStatusFilter(nil)
                                }
                                Divider()
                                ForEach([ProjectStatus.IN_REVIEW, .STANDBY, .LOCKED ,.ACTIVE, .MAINTENANCE, .COMPLETED, .DECLINED, .ARCHIVE], id: \.self) { status in
                                    Button(status.displayText) {
                                        viewModel.updateStatusFilter(status)
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(viewModel.selectedStatusFilter?.displayText ?? "All")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
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
                        .padding(.leading, 4)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.top, DesignSystem.Spacing.medium)
                    
                    if !viewModel.projects.isEmpty {
                        let filteredCount = filteredProjects.count
                        Text("\(filteredCount) project\(filteredCount == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.bottom, DesignSystem.Spacing.small)
                        
                        // Search Bar
                        searchBar
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.bottom, DesignSystem.Spacing.small)
                    }
                    
                    if viewModel.projects.isEmpty {
                        emptyStateView
                    } else if !searchText.trimmingCharacters(in: .whitespaces).isEmpty && filteredProjects.isEmpty {
                        searchEmptyStateView
                    } else {
                        projectsListView
                    }
                }
                
                // Floating Action Buttons
                if role == .ADMIN && !viewModel.projects.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            // Reports button on the left
                            floatingReportsButton
                            
                            Spacer()
                            
                            // Create project button on the right
                            floatingActionButton
                        }
                    }
                }
            }
            .refreshable {
                viewModel.fetchProjects()
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $navigationManager.activeProjectId) { projectNavigationItem in
                let projectId = projectNavigationItem.id
                if let project = viewModel.project(for: projectId) {
                    // If project is DECLINED and user is ADMIN, show edit view
                    if role == .ADMIN && project.statusType == .DECLINED {
                        CreateProjectView(projectToEdit: project)
                    } else if role == .USER {
                        ProjectDetailView(project: project,
                                          role: role,
                                          phoneNumber: viewModel.phoneNumber,
                                          customerId: authService.currentCustomerId,
                                          stateManager: sharedStateManager)
                    } else {
                        DashboardView(project: project, role: role, phoneNumber: viewModel.phoneNumber, customerId: authService.currentCustomerId, stateManager: sharedStateManager)
                    }
                } else {
                    Text("Project not found")
                }
            }
            .onChange(of: navigationManager.activeExpenseId) { newValue in
                if let expenseItem = newValue {
                    let expenseId = expenseItem.id
                    let isExpenseChat = navigationManager.expenseScreenType == .chat
                    let screenType = navigationManager.expenseScreenType ?? .detail
                    
                    Task {
                        guard let customerId = authService.currentCustomerId else {
                            print("⚠️ Customer ID not available for expense navigation")
                            navigationManager.setExpenseId(nil)
                            return
                        }
                        
                        // Ensure projects are loaded
                        if viewModel.projects.isEmpty {
                            await viewModel.fetchProjects()
                        }
                        
                        // Get projectId from navigation manager
                        guard let projectId = navigationManager.activeProjectId?.id else {
                            print("⚠️ Project ID not available for expense navigation - will wait for project to be set")
                            // Don't clear expenseId - wait for project to be set first
                            // The project navigation will happen first, then expense will be handled
                            return
                        }
                        
                        // Navigate to the project first
                        // DashboardView will handle showing the expense chat
                        await MainActor.run {
                            // Ensure project is set and expenseId is preserved with correct screen type
                            navigationManager.setProjectId(projectId)
                            navigationManager.setExpenseId(expenseId, screenType: screenType)
                        }
                    }
                }
            }
            .onChange(of: navigationManager.activeProjectId) { newValue in
                if let navigationItem = newValue {
                    let id = navigationItem.id
                    print("🔄 Navigation trigger detected for project ID: \(id)")
                    Task {
                        if viewModel.projects.isEmpty {
                            await viewModel.fetchProjects()
                        }

                        // Ensure UI updates happen on main thread
                        await MainActor.run {
                            if let project = viewModel.project(for: id) {
                                print("✅ Project found for navigation: \(project.name)")
                                // Navigation will be handled by navigationDestination
                                
                                // If there's a pending expense navigation, ensure it's processed after project loads
                                if let expenseId = navigationManager.activeExpenseId?.id {
                                    let screenType = navigationManager.expenseScreenType ?? .detail
                                    print("🔄 Project loaded, ensuring expense navigation is set: \(expenseId), screenType: \(screenType)")
                                    // Re-set expenseId to trigger navigation in DashboardView
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        navigationManager.setExpenseId(expenseId, screenType: screenType)
                                    }
                                }
                            } else {
                                print("⚠️ Project not found yet for ID: \(id)")
                                // Clear the navigation if project not found
                                navigationManager.setProjectId(nil)
                            }
                        }
                    }
                }
            }
            .onChange(of: navigationManager.activeRequestId) { newValue in
                if let requestItem = newValue {
                    let requestId = requestItem.id
                    print("📝 Request navigation trigger detected for request ID: \(requestId)")
                    
                    Task {
                        guard let customerId = authService.currentCustomerId else {
                            print("⚠️ Customer ID not available for request navigation")
                            navigationManager.setRequestId(nil)
                            return
                        }
                        
                        // Load request to get projectId
                        let phaseRequestVM = PhaseRequestNotificationViewModel()
                        if let (request, projectId) = await phaseRequestVM.loadRequestByIdWithProject(
                            requestId: requestId,
                            customerId: customerId
                        ) {
                            // Navigate to the project first
                            navigationManager.setProjectId(projectId)
                            // Keep requestId set so DashboardView can show it
                            print("✅ Request loaded, navigating to project: \(projectId)")
                        } else {
                            print("⚠️ Request not found: \(requestId)")
                            navigationManager.setRequestId(nil)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            CreateProjectView()
        }
        .onAppear {
            
            navigationManager.markProjectListLoaded()

            viewModel.fetchProjects()
            if role == .APPROVER {
                loadTempApproverStatuses()
            }
            loadBusinessName()
            
            // Mark ProjectListView as ready for navigation
            // Add delay to ensure navigation stack is fully set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                navigationManager.markProjectListLoaded()
            }
            
            // Removed automatic unsuspend - status updates are now manual only
            // Task {
            //     try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            //     await viewModel.checkAndUnsuspendExpiredProjects()
            // }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProjectUpdated"))) { _ in
            // Reload state manager when project is updated
            if let projectId = navigationManager.activeProjectId?.id,
               let customerId = authService.currentCustomerId {
                Task {
                    await sharedStateManager.loadAllData(projectId: projectId, customerId: customerId)
                    await sharedStateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                }
            }
            // Check and update project statuses based on phases in background (don't block UI)
            Task.detached(priority: .background) {
                await viewModel.checkAndUpdateProjectStatusesBasedOnPhases()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PhaseUpdated"))) { _ in
            // Check and update project statuses when a phase is created/updated (in background)
            Task.detached(priority: .background) {
                await viewModel.checkAndUpdateProjectStatusesBasedOnPhases()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExpenseStatusUpdated"))) { notification in
            // Update state manager when expense status changes
            if let userInfo = notification.userInfo,
               let phaseId = userInfo["phaseId"] as? String,
               let department = userInfo["department"] as? String,
               let oldStatusStr = userInfo["oldStatus"] as? String,
               let newStatusStr = userInfo["newStatus"] as? String,
               let amount = userInfo["amount"] as? Double,
               let oldStatus = ExpenseStatus(rawValue: oldStatusStr),
               let newStatus = ExpenseStatus(rawValue: newStatusStr) {
                sharedStateManager.updateExpenseStatus(
                    expenseId: userInfo["expenseId"] as? String ?? "",
                    phaseId: phaseId,
                    department: department,
                    oldStatus: oldStatus,
                    newStatus: newStatus,
                    amount: amount
                )
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Check project statuses when app becomes active
            if newPhase == .active && oldPhase != .active {
                // Mark ProjectListView as ready when app becomes active
                // This ensures navigation works when returning from background
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    navigationManager.markProjectListLoaded()
                }
                
                // Removed automatic status validation - status updates are now manual only
                // Task {
                //     await viewModel.checkAndUnsuspendExpiredProjects()
                //     await viewModel.checkAndUpdateProjectStatuses()
                // }
            }
        }
        .overlay {
            if viewModel.showingFullNotifications {
                ProjectListNotificationPopupView(
                    viewModel: viewModel,
                    role: role,
                    onProjectSelected: { project in
                        Task { @MainActor in
                            if role == .ADMIN {
                                // For ADMIN: Open CreateProjectView for declined projects
                                selectedDeclinedProject = project
                                viewModel.showingFullNotifications = false
                                // Small delay to allow popup to close before showing sheet
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                showingDeclinedProjectEdit = true
                            } else if role == .APPROVER {
                                // For APPROVER: Open ProjectApprovalReviewView for IN_REVIEW projects
                                selectedInReviewProject = project
                                viewModel.showingFullNotifications = false
                                // Small delay to allow popup to close before showing sheet
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                projectToReview = project
                            }
                        }
                    },
                    onPhaseRequestSelected: { request, project in
                        Task { @MainActor in
                            viewModel.showingFullNotifications = false
                            // Navigate to project first, then set request ID so DashboardView can show the sheet
                            if let projectId = project.id {
                                // Set project ID to navigate to DashboardView
                                navigationManager.setProjectId(projectId)
                                // Small delay to allow navigation to start
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                // Set request ID - DashboardView will detect this and show the sheet
                                navigationManager.setRequestId(request.id)
                            }
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingDeclinedProjectEdit) {
            if let project = selectedDeclinedProject {
                CreateProjectView(projectToEdit: project)
            }
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
        .sheet(item: $projectToReview) { project in
            ProjectApprovalReviewView(
                project: project,
                customerId: authService.currentCustomerId,
                onApprove: {
                    Task {
                        await approveProject(project)
                        projectToReview = nil
                    }
                },
                onReject: { reason in
                    Task {
                        await rejectProject(project, reason: reason)
                        projectToReview = nil
                    }
                },
                onDismiss: {
                    projectToReview = nil
                }
            )
        }
        .sheet(isPresented: $showingReports) {
            MainReportView(searchTextBinding: $searchText)
                .environmentObject(authService)
                .presentationDetents([.large])
        }
        .alert("Business Name", isPresented: $showingBusinessNameAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(businessName)
        }
    }
    
    // MARK: - Project Approval/Rejection
    
    private func approveProject(_ project: Project) async {
        guard let projectId = project.id,
              let customerId = authService.currentCustomerId else {
            return
        }
        
        do {
            // When approver accepts, always set status to LOCKED
            // The status check logic will automatically transition LOCKED to ACTIVE when planned date or phase start date arrives
            
            // Parse plannedDate string to Date for comparison
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            let plannedDateObj = project.plannedDate.flatMap { dateFormatter.date(from: $0) }
            let isPlannedDatePassed = plannedDateObj.map { $0 < Date() } ?? false

            try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .updateData([
                    "status": isPlannedDatePassed ? ProjectStatus.ACTIVE.rawValue : ProjectStatus.LOCKED.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

            
            // Post notification to refresh project list
            NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            
            await MainActor.run {
                HapticManager.notification(.success)
            }
        } catch {
            print("Error approving project: \(error.localizedDescription)")
            await MainActor.run {
                HapticManager.notification(.error)
            }
        }
    }
    
    private func rejectProject(_ project: Project, reason: String) async {
        guard let projectId = project.id,
              let customerId = authService.currentCustomerId else {
            return
        }
        
        do {
            // Update project status to DECLINED so admin can edit and resubmit
            try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .updateData([
                    "status": ProjectStatus.DECLINED.rawValue,
                    "rejectionReason": reason,
                    "rejectedBy": viewModel.phoneNumber,
                    "rejectedAt": Timestamp(),
                    "updatedAt": Timestamp()
                ])
            
            // Post notification to refresh project list
            NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            
            await MainActor.run {
                HapticManager.notification(.success)
            }
        } catch {
            print("Error rejecting project: \(error.localizedDescription)")
            await MainActor.run {
                HapticManager.notification(.error)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadBusinessName() {
        Task {
            guard let customerId = authService.currentCustomerId else {
                // Fallback to default if customer ID not available
                await MainActor.run {
                    businessName = "Your Projects"
                }
                return
            }
            
            do {
                let customerDoc = try await Firestore.firestore()
                    .collection("customers")
                    .document(customerId)
                    .getDocument()
                
                if customerDoc.exists,
                   let customer = try? customerDoc.data(as: Customer.self) {
                    await MainActor.run {
                        businessName = customer.businessName.isEmpty ? "Your Projects" : customer.businessName
                    }
                } else {
                    await MainActor.run {
                        businessName = "Your Projects"
                    }
                }
            } catch {
                print("Error loading business name: \(error.localizedDescription)")
                await MainActor.run {
                    businessName = "Your Projects"
                }
            }
        }
    }
    
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
    private var searchEmptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Spacer()
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary.opacity(0.6))
                    .symbolRenderingMode(.hierarchical)
                
                Text("No Projects Found")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(.primary)
                
                Text("No projects match \"\(searchText)\"")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.extraLarge)
            }
            
            Button("Clear Search") {
                HapticManager.selection()
                searchText = ""
            }
            .secondaryButton()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
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
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField("Search projects", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
            
            if !searchText.isEmpty {
                Button(action: {
                    HapticManager.selection()
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.small + 2)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Computed Properties
    
    /// Truncated business name (23 characters max)
    private var truncatedBusinessName: String {
        if businessName.count > 20 {
            return String(businessName.prefix(20))
        }
        return businessName
    }
    
    /// Whether to show truncation dots
    private var shouldShowTruncation: Bool {
        businessName.count > 20
    }
    
    /// Filtered projects based on search text (case-insensitive search on project name)
    private var filteredProjects: [Project] {
        let baseProjects = viewModel.filteredProjectsForTempApprover
        
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return baseProjects
        }
        
        let searchTerm = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return baseProjects.filter { project in
            project.name.lowercased().contains(searchTerm)
        }
    }
    
    /// Notification badge count - declined projects for ADMIN, IN_REVIEW for APPROVER, pending expenses for others
    private var notificationBadgeCount: Int {
        if role == .ADMIN {
            return viewModel.projects.filter { $0.statusType == .DECLINED }.count
        } else if role == .APPROVER {
            return viewModel.projects.filter { $0.statusType == .IN_REVIEW }.count
        } else {
            return viewModel.pendingExpenses.count
        }
    }
    
    /// Whether to show notification badge
    private var shouldShowNotificationBadge: Bool {
        notificationBadgeCount > 0
    }
    
    // MARK: - Helper Properties
    private var emptyStateMessage: String {
        switch role {
        case .ADMIN:
            return "You have not created any project yet. Start by creating your first project to organize and track your entertainment productions."
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
                    ForEach(filteredProjects) { project in
                        if role == .APPROVER {
                            Button(action: {
                                Task {
                                    selectedProject = project
                                    // Check if project is IN_REVIEW - show review view
                                    if project.statusType == .IN_REVIEW {
                                        projectToReview = project
                                    } else {
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
                                }
                            }) {
                                ProjectCell(
                                    project: project,
                                    role: role,
                                    tempApproverStatus: projectTempStatuses[project.id ?? ""],
                                    onReviewTap: {
                                        projectToReview = project
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.selection()
                            })
                        } else if role == .ADMIN {
                            // If project is DECLINED, navigate to edit view, otherwise to dashboard
                            if project.statusType == .DECLINED {
                                NavigationLink(destination: CreateProjectView(projectToEdit: project).environmentObject(navigationManager)) {
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
                                NavigationLink(destination: DashboardView(project: project, role: role, phoneNumber: viewModel.phoneNumber, customerId: authService.currentCustomerId, stateManager: sharedStateManager).environmentObject(navigationManager)) {
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
                        } else {
                            // For USER role, disable navigation if project is IN_REVIEW or DECLINED
                            if role == .USER && (project.statusType == .IN_REVIEW || project.statusType == .DECLINED) {
                                ProjectCell(
                                    project: project,
                                    role: role,
                                    tempApproverStatus: projectTempStatuses[project.id ?? ""]
                                )
                                .opacity(0.6)
                                .disabled(true)
                            } else {
                                NavigationLink(destination: ProjectDetailView(project: project, role: role, phoneNumber: viewModel.phoneNumber, customerId: authService.currentCustomerId, stateManager: sharedStateManager).environmentObject(navigationManager)) {
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
                }
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.top, DesignSystem.Spacing.small)
                .padding(.bottom, 80) // Space for FAB
            }
            .animation(DesignSystem.Animation.standardSpring, value: filteredProjects)
            .navigationDestination(isPresented: $shouldNavigateToDashboard) {
                if let project = selectedProject {
                    DashboardView(project: project, role: role, phoneNumber: viewModel.phoneNumber, customerId: authService.currentCustomerId, stateManager: sharedStateManager)
                }
            }
            
            // Temporary Approver Status Overlay
            if viewModel.tempApproverStatus == .pending {
                tempApproverPendingOverlay
            }
        }
    }
    
    // MARK: - Floating Action Buttons
    private var floatingReportsButton: some View {
        Button {
            HapticManager.impact(.medium)
            withAnimation(DesignSystem.Animation.fastSpring) {
                showingReports = true
            }
        } label: {
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.blue)
                        .shadow(
                            color: DesignSystem.Shadow.large.color,
                            radius: DesignSystem.Shadow.large.radius,
                            x: DesignSystem.Shadow.large.x,
                            y: DesignSystem.Shadow.large.y
                        )
                )
        }
        .scaleEffect(showingReports ? 0.9 : 1.0)
        .animation(DesignSystem.Animation.interactiveSpring, value: showingReports)
        .padding(.leading, DesignSystem.Spacing.extraLarge)
        .padding(.bottom, DesignSystem.Spacing.extraLarge)
    }
    
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
                    .symbolRenderingMode(.hierarchical)
                
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
                        .symbolRenderingMode(.hierarchical)
                    
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
                Task {
                    await FirestoreManager.shared.removeToken()
                    await MainActor.run {
                        HapticManager.notification(.success)
                        dismiss()
                        NotificationCenter.default.post(name: NSNotification.Name("UserDidLogout"), object: nil)
                    }
                }
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

// MARK: - Reports Dummy View
struct ReportsDummyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.large) {
                Spacer()
                
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Reports")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Reports feature coming soon")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.selection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Reports")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

#Preview{
    ProjectListView(phoneNumber: "9876543210", role: .APPROVER)
}
