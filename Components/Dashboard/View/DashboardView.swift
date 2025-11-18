//
//  DashboardView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct DepartmentSelection: Identifiable {
    let id = UUID()
    let name: String
    let phaseId: String?
}

// MARK: - Department Key Helpers
extension String {
    /// Formats department key for storage: "phaseId_departmentName"
    static func departmentKey(phaseId: String, departmentName: String) -> String {
        return "\(phaseId)_\(departmentName)"
    }
    
    /// Extracts department name from stored key by removing "phaseId_" prefix
    /// Handles both old format (just department name) and new format (phaseId_departmentName)
    func displayDepartmentName() -> String {
        // Check if it contains underscore (new format)
        if let underscoreIndex = self.firstIndex(of: "_") {
            // Extract everything after the first underscore
            return String(self[self.index(after: underscoreIndex)...])
        }
        // Old format or no underscore, return as is
        return self
    }
    
    /// Checks if a department key matches a given department name
    /// Handles both old format (just department name) and new format (phaseId_departmentName)
    func matchesDepartmentName(_ departmentName: String) -> Bool {
        let displayName = self.displayDepartmentName()
        return displayName == departmentName || self == departmentName
    }
}


struct DashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DashboardViewModel
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showingPendingApprovals = false
    @State private var showingReportSheet = false
    @State private var showingActionMenu = false
    @State private var showingAddExpense = false
    @State private var showingAnalytics = false
    @State private var showingDelegate = false
    @State private var showingChats = false
    @State private var showingDepartmentDetail = false
    @State private var selectedDepartmentForDetail: String? = nil
    @State private var selectedPhaseIdForDetail: String? = nil
    @State private var showingTeamMembersDetail = false
    @State private var showingAnonymousExpensesDetail = false
    @State private var scrollToDepartmentSection = false
    @StateObject private var ProjectDetialViewModel : ProjectDetailViewModel
    @EnvironmentObject var navigationManager: NavigationManager
    @State private var showProjectDetail = false
    @State private var showingAddDepartment = false
    @State private var phaseForDepartmentAdd: PhaseSummary? = nil
    @State private var showingPhaseRequestNotifications = false
    @State private var selectedRequest: PhaseRequestItem? = nil
    @State private var showingRequestActionSheet = false
    @StateObject private var phaseRequestNotificationViewModel = PhaseRequestNotificationViewModel()
    @StateObject private var stateManager: DashboardStateManager
    @State private var showingCompletePhaseConfirmation = false
    @State private var phaseToComplete: PhaseSummary? = nil
    @State private var showingStartNowConfirmation = false
    @State private var phaseToStart: PhaseSummary? = nil
    @State private var showingExpenseChat = false
    @State private var expenseForChat: Expense? = nil
    @StateObject private var notificationViewModel = NotificationViewModel()
    @State private var showingNotifications = false
    let role: UserRole?
    let phoneNumber: String
    @State private var selectedProject: Project?
    
    // Accept a single project as parameter - made @State to allow updates from AdminProjectDetailView
    @State var project: Project?
    
    // Customer ID for multi-tenant support
    private var customerId: String? {
        authService.currentCustomerId
    }
    
    // MARK: - Phase Data
    struct PhaseSummary: Identifiable, Hashable {
        let id: String
        let name: String
        let start: Date?
        let end: Date?
        let departments: [String: Double]
    }
    
    struct PhaseBudget: Identifiable {
        let id: String
        let totalBudget: Double
        let spent: Double
        var remaining: Double {
            totalBudget - spent
        }
    }
    
    @State private var allPhases: [PhaseSummary] = []
    @State private var phaseEnabledMap: [String: Bool] = [:]
    @State private var phaseBudgetMap: [String: PhaseBudget] = [:]
    @State private var phaseExtensionMap: [String: Bool] = [:] // Track if phase has accepted extension
    @State private var phaseAnonymousExpensesMap: [String: Double] = [:] // Track anonymous expenses per phase
    @State private var phaseDepartmentSpentMap: [String: [String: Double]] = [:] // Track spent per department per phase [phaseId: [department: spent]]
    
    // Permanent approver
    
    @State private var permanentApproverName: String?
    
    // Temporary Approver Properties
    @State private var tempApproverName: String?
    @State private var tempApproverPhoneNumber: String?
    @State private var tempApproverStatus: TempApproverStatus?
    @State private var tempApproverEndDate: Date?
    
    // Date formatter for temp approver end date
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
    
    init(project: Project? = nil, role: UserRole? = nil, phoneNumber: String = "", customerId: String? = nil, stateManager: DashboardStateManager? = nil) {
        self._project = State(initialValue: project)
        self.role = role
        self.phoneNumber = phoneNumber
        self._viewModel = StateObject(wrappedValue: DashboardViewModel(project: project, phoneNumber: phoneNumber, customerId: customerId))
        self._ProjectDetialViewModel = StateObject(wrappedValue: ProjectDetailViewModel(project: project ?? Project.sampleData[0], CurrentUserPhone: phoneNumber, customerId: customerId))
        // Use provided state manager or create a new one
        self._stateManager = StateObject(wrappedValue: stateManager ?? DashboardStateManager())
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground).opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.large) {
                            // Project Overview Section
                            if let project = project {
                                projectOverviewSection
                            }
                            
                            // Current Phases with Departments (Horizontal)
                            currentPhasesSection
                                .id("departmentBudgetSection")
                            
                            // Enhanced Charts Section
                            chartsSection
                            
                        }
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.bottom, DesignSystem.Spacing.extraLarge)
                    }
                    .refreshable {
                        await refreshAllData()
                    }
                    .onChange(of: scrollToDepartmentSection) { newValue in
                        if newValue {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                proxy.scrollTo("departmentBudgetSection", anchor: UnitPoint.top)
                            }
                            scrollToDepartmentSection = false
                        }
                    }
                }
                
                // Floating Action Buttons - Using Overlay for True Independence
                VStack {
                    Spacer()
                    
                    // Left side floating action menu
                    HStack {
                        ZStack(alignment: .bottomLeading) {
                            // Action buttons (positioned absolutely)
                            if showingActionMenu {
                                VStack(spacing: 12) {
                                    if role == .ADMIN {
                                        ActionMenuButton(icon: "person.2.badge.gearshape.fill", title: "Delegate", color: Color.purple) {
                                            showingDelegate = true
                                            showingActionMenu = false
                                            HapticManager.selection()
                                        }
                                    }
                                    
                                    ActionMenuButton(icon: "chart.bar.fill", title: "Dashboard", color: Color.blue) {
                                        showingActionMenu = false
                                        HapticManager.selection()
                                    }
                                    
                                    ActionMenuButton(icon: "clock.badge.checkmark.fill", title: "Pending Approvals", color: Color.orange) {
                                        showingPendingApprovals = true
                                        showingActionMenu = false
                                        HapticManager.selection()
                                    }
                                    
                                    ActionMenuButton(
                                        icon: "plus.circle.fill",
                                        title: "Add Expense",
                                        color: Color.green,
                                        isDisabled: project?.isSuspended == true || project?.statusType == .ARCHIVE
                                    ) {
                                        if project?.isSuspended != true && project?.statusType != .ARCHIVE {
                                            showingAddExpense = true
                                            showingActionMenu = false
                                            HapticManager.selection()
                                        } else {
                                            HapticManager.notification(.error)
                                        }
                                    }
                                    
                                    if role == .ADMIN {
                                        ActionMenuButton(icon: "chart.line.uptrend.xyaxis", title: "Analytics", color: Color.indigo) {
                                            showingAnalytics = true
                                            showingActionMenu = false
                                            HapticManager.selection()
                                        }
                                    }
                                    
                                    ActionMenuButton(icon: "message.fill", title: "Chats", color: Color.teal) {
                                        showingChats = true
                                        showingActionMenu = false
                                        HapticManager.selection()
                                    }
                                }
                                .padding(.bottom, 80) // Space for the main button
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Main FAB (fixed position)
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingActionMenu.toggle()
                                }
                                HapticManager.impact(.medium)
                            }) {
                                Image(systemName: showingActionMenu ? "xmark" : "chevron.up")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())
                                    .shadow(radius: 8)
                                    .rotationEffect(.degrees(showingActionMenu ? 180 : 0))
                            }
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
                .overlay(
                    // Right side Report button - Completely independent overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showingReportSheet = true
                                HapticManager.impact(.light)
                            }) {
                                Image(systemName: "doc.text.fill")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 8)
                            }
                            .padding(.trailing, 20)
                        }
                        .padding(.bottom, 20)
                    },
                    alignment: .bottom
                )
                
                // Phase Request Notification popup overlay (Admin only)
                if showingPhaseRequestNotifications && role == .ADMIN {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                showingPhaseRequestNotifications = false
                            }
                        }
                    
                    // Responsive phase request notification popup
                    VStack {
                        HStack {
                            Spacer()
                            
                            PhaseRequestNotificationFloatingView(
                                requests: phaseRequestNotificationViewModel.pendingRequests,
                                onRequestTap: { request in
                                    // Handle request tap - show accept/reject sheet
                                    selectedRequest = request
                                    showingPhaseRequestNotifications = false
                                    showingRequestActionSheet = true
                                },
                                onDismiss: {
                                    withAnimation(.spring(response: 0.3)) {
                                        showingPhaseRequestNotifications = false
                                    }
                                }
                            )
                            .frame(
                                width: min(360, geometry.size.width - 32),
                                height: min(600, geometry.size.height * 0.7)
                            )
                            .padding(.trailing, 16)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                            .onTapGesture { }  // Prevent tap from dismissing
                        }
                        
                        Spacer()
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 60) // Account for navigation bar
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    TruncatedTextWithTooltip(
                        project?.name ?? "Project Dashboard",
                        font: .headline,
                        foregroundColor: .primary,
                        lineLimit: 1
                    )
                    
//                    Text(project?.statusType.rawValue ?? "")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    // FCM Notifications Button (for APPROVER and ADMIN roles)
//                    if role == .APPROVER || role == .ADMIN {
//                        Button {
//                            HapticManager.selection()
//                            showingNotifications = true
//                        } label: {
//                            ZStack(alignment: .topTrailing) {
//                                Image(systemName: "bell")
//                                    .font(.title3)
//                                    .foregroundColor(.primary)
//                                
//                                if notificationViewModel.unreadNotificationCount > 0 {
//                                    Text(notificationViewModel.unreadNotificationCount > 99 ? "99+" : "\(notificationViewModel.unreadNotificationCount)")
//                                        .font(.system(size: 11, weight: .bold))
//                                        .foregroundColor(.white)
//                                        .padding(.horizontal, notificationViewModel.unreadNotificationCount > 99 ? 4 : 5)
//                                        .padding(.vertical, 2)
//                                        .background(Color.red)
//                                        .clipShape(Capsule())
//                                        .overlay(
//                                            Capsule()
//                                                .stroke(Color.white, lineWidth: 1.5)
//                                        )
//                                        .offset(x: 8, y: -8)
//                                        .minimumScaleFactor(0.5)
//                                        .lineLimit(1)
//                                }
//                            }
//                        }
//                    }
                    
                    // Phase Request Notification Button (Admin only, before pencil)
                    if role == .ADMIN {
                        Button {
                            HapticManager.impact(.light)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingPhaseRequestNotifications.toggle()
                                if showingPhaseRequestNotifications {
                                    Task {
                                        await phaseRequestNotificationViewModel.loadPendingRequests(
                                            projectId: project?.id ?? "",
                                            customerId: customerId
                                        )
                                    }
                                }
                            }
                        } label: {
                            ZStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.primary)
                                
                                if phaseRequestNotificationViewModel.pendingRequestsCount > 0 {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Text("\(phaseRequestNotificationViewModel.pendingRequestsCount)")
                                                .font(.system(size: 10))
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 10, y: -10)
                                }
                            }
                        }
                    }
                    
                    // Edit Button (always visible for ADMIN, but editing is restricted inside AdminProjectDetailView for archived projects)
                    if let project = project, role == .ADMIN {
                        NavigationLink(destination: AdminProjectDetailView(project: project)) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                    }
                    
                }
            }
        }
        .sheet(isPresented: $showingPendingApprovals) {
            if let project = project{
                PendingApprovalsView(role: role, project: project, phoneNumber: phoneNumber)
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            // TODO: Add Report View here
            ReportView(projectId: project?.id)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingAddExpense) {
            if let project = project {
                AddExpenseView(project: project)
                    .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingAddDepartment, onDismiss: {
            Task { await loadPhases() }
        }) {
            if let projectId = project?.id, let phase = phaseForDepartmentAdd {
                AddDepartmentSheet(
                    projectId: projectId,
                    phaseId: phase.id,
                    phaseName: phase.name,
                    onSaved: {
                        HapticManager.impact(.light)
                        Task { await loadPhases() }
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showingAnalytics) {
            //            if let projectId = project?.id , let projectBudget = project?.budget{
            ////                PredictiveAnalysisView1(projectId: projectId, budget: projectBudget)
            ////                    .presentationDetents([.large])
            //                AnalyticsDashboardView(projectId: projectId)
            //                    .presentationDetents([.large])
            //            }
            
            
            if let project = project{
                PredictiveAnalysisScreen(project: project)
            }
            
        }
        .sheet(isPresented: $showingDelegate) {
            if let project = project, let role = role {
                DelegateView(project: project, currentUserRole: role, showingDelegate: $showingDelegate)
                    .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingChats) {
            if role == .ADMIN{
                if let project = project {
                    ChatsView(
                        project: project,
                        currentUserRole: .ADMIN
                    )
                    .presentationDetents([.large])
                }
            }else{
                if let project = project {
                    ChatsView(
                        project: project,
                        currentUserPhone: phoneNumber,
                        currentUserRole: role ?? .USER
                    )
                    .presentationDetents([.large])
                }
            }
        }
        .sheet(isPresented: $showingDepartmentDetail) {
            if let department = selectedDepartmentForDetail, let project = project, let projectId = project.id, !projectId.isEmpty {
                DepartmentBudgetDetailView(
                    department: department,
                    projectId: projectId,
                    role: role,
                    phoneNumber: phoneNumber,
                    phaseId: selectedPhaseIdForDetail,
                    projectStatus: project.statusType,
                    stateManager: stateManager
                )
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingTeamMembersDetail) {
            if let project = project {
                TeamMembersDetailView(project: project, role: role, stateManager: stateManager)
                    .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingAnonymousExpensesDetail) {
            if let project = project {
                AnonymousExpensesDetailView(project: project)
                    .presentationDetents([.large])
            }
        }
        .fullScreenCover(isPresented: $showProjectDetail) {
            if let project = selectedProject {
                PendingApprovalsView(role: role, project: project, phoneNumber: phoneNumber)
            } else {
                ProgressView("Loading project...")
            }
        }
        .sheet(isPresented: $showingExpenseChat) {
            if let expense = expenseForChat {
                ExpenseChatView(
                    expense: expense,
                    userPhoneNumber: phoneNumber,
                    projectId: project?.id ?? "",
                    role: role ?? .USER
                )
                .presentationDetents([.large])
            }
        }
        .overlay {
            if showingNotifications, let project = project {
                NotificationPopupView(
                    notificationViewModel: notificationViewModel,
                    project: project,
                    role: role,
                    phoneNumber: phoneNumber,
                    isPresented: $showingNotifications
                )
            }
        }
        .sheet(isPresented: $showingRequestActionSheet) {
            if let request = selectedRequest, let projectId = project?.id {
                PhaseRequestActionSheet(
                    request: request,
                    projectId: projectId,
                    customerId: customerId,
                    onAccept: {
                        Task {
                            await phaseRequestNotificationViewModel.handleRequestAction(
                                request: request,
                                projectId: projectId,
                                customerId: customerId,
                                action: .accept,
                                reason: phaseRequestNotificationViewModel.reasonToReact
                            )
                            
                            // Wait for Firebase to sync (increased delay for better reliability)
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                            
                            // Reload pending requests
                            await phaseRequestNotificationViewModel.loadPendingRequests(
                                projectId: projectId,
                                customerId: customerId
                            )
                            // Reload phases and extensions
                            await loadPhases()
                            // Wait for phases to fully load
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            await loadPhaseExtensions()
                        }
                        showingRequestActionSheet = false
                    },
                    onReject: {
                        Task {
                            await phaseRequestNotificationViewModel.handleRequestAction(
                                request: request,
                                projectId: projectId,
                                customerId: customerId,
                                action: .reject,
                                reason: phaseRequestNotificationViewModel.reasonToReact
                            )
                            // Reload pending requests
                            await phaseRequestNotificationViewModel.loadPendingRequests(
                                projectId: projectId,
                                customerId: customerId
                            )
                        }
                        showingRequestActionSheet = false
                    },
                    onDismiss: {
                        showingRequestActionSheet = false
                        phaseRequestNotificationViewModel.reasonToReact = ""
                    },
                    reasonToReact: $phaseRequestNotificationViewModel.reasonToReact
                )
                .presentationDetents([.medium])
            }
        }
        .alert("Complete Phase", isPresented: $showingCompletePhaseConfirmation) {
            Button("Cancel", role: .cancel) {
                phaseToComplete = nil
            }
            Button("Confirm", role: .destructive) {
                if let phase = phaseToComplete {
                    Task {
                        await completePhase(phase)
                    }
                }
                phaseToComplete = nil
            }
        } message: {
            if let phase = phaseToComplete {
                Text("From tomorrow, this stage will be closed. Users cannot add any expense to this phase. The phase end date will be set to today (\(phaseDateFormatter.string(from: Date()))).")
            }
        }
        .alert("Start Phase Now", isPresented: $showingStartNowConfirmation) {
            Button("Cancel", role: .cancel) {
                phaseToStart = nil
            }
            Button("Confirm") {
                if let phase = phaseToStart {
                    Task {
                        await startPhaseNow(phase)
                    }
                }
                phaseToStart = nil
            }
        } message: {
            if let phase = phaseToStart {
                let message: String
                if project?.statusType == .LOCKED {
                    message = "The phase start date will be set to today (\(phaseDateFormatter.string(from: Date()))). The project planned start date will also be updated to today since the project is locked."
                } else {
                    message = "The phase start date will be set to today (\(phaseDateFormatter.string(from: Date())))."
                }
                return Text(message)
            }
            return Text("")
        }

        .onAppear {
            if let projectId = project?.id{
                viewModel.loadDashboardData()
                // Load state manager data
                if let customerId = customerId {
                    Task {
                        await stateManager.loadAllData(projectId: projectId, customerId: customerId)
                        // Load team members
                        await stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                    }
                }
            }
            Task {
                await loadPhases()
                await fetchTempApproverData()
                // Load phase request notifications for admin
                if role == .ADMIN, let projectId = project?.id {
                    await phaseRequestNotificationViewModel.loadPendingRequests(
                        projectId: projectId,
                        customerId: customerId
                    )
                }
                // Load FCM notifications for APPROVER and ADMIN
                if (role == .APPROVER || role == .ADMIN), let projectId = project?.id {
                    await notificationViewModel.fetchProjectNotifications(
                        projectId: projectId,
                        currentUserPhone: phoneNumber,
                        currentUserRole: role ?? .USER
                    )
                }
            }
        }
        .onChange(of: project) { _ in
            viewModel.updateProject(project)
            Task {
                await loadPhases()
                await fetchTempApproverData()
            }
        }
        .onChange(of: navigationManager.activeExpenseId) { newValue in
            if let expenseItem = newValue {
                // Check screen type to determine if we should show chat or detail
                let showChat = navigationManager.expenseScreenType == .chat
                showingExpenseChat = true
//                handleExpenseChange(expenseItem.id, showChat: showChat)
            }
        }
        .onChange(of: navigationManager.activePhaseId) { newValue in
            if let phaseItem = newValue {
                handlePhaseChange(phaseItem.id)
            }
        }
        .onChange(of: navigationManager.activeRequestId) { newValue in
            if let requestItem = newValue {
                handleRequestChange(requestItem.id)
            }
        }
        .navigationDestination(item: $navigationManager.activeChatId) { chatNavigationItem in
            if let project = project {
                ChatNavigationDestinationView(
                    chatId: chatNavigationItem.id,
                    project: project,
                    role: role ?? .USER,
                    phoneNumber: phoneNumber
                )
            } else {
                ProgressView("Loading project...")
            }
        }
        .onChange(of: navigationManager.activeChatId) { oldValue, newValue in
            if let chatItem = newValue {
                print("💬 Chat navigation trigger detected in DashboardView for chat ID: \(chatItem.id)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExpenseStatusUpdated"))) { notification in
            // Immediately update state when expense status changes
            if let userInfo = notification.userInfo,
               let phaseId = userInfo["phaseId"] as? String,
               let department = userInfo["department"] as? String,
               let oldStatusStr = userInfo["oldStatus"] as? String,
               let newStatusStr = userInfo["newStatus"] as? String,
               let amount = userInfo["amount"] as? Double,
               let oldStatus = ExpenseStatus(rawValue: oldStatusStr),
               let newStatus = ExpenseStatus(rawValue: newStatusStr) {
                stateManager.updateExpenseStatus(
                    expenseId: userInfo["expenseId"] as? String ?? "",
                    phaseId: phaseId,
                    department: department,
                    oldStatus: oldStatus,
                    newStatus: newStatus,
                    amount: amount
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProjectUpdated"))) { notification in
            // Reload project data when updated from AdminProjectDetailView
            if let projectId = project?.id, let customerId = customerId {
                Task {
                    // Reload project from Firestore to get latest changes
                    await reloadProjectFromFirestore(projectId: projectId, customerId: customerId)
                    
                    // Reload all related data
                    await stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                    await stateManager.loadAllData(projectId: projectId, customerId: customerId)
                    await loadPhases()
                    await fetchTempApproverData()
                    
                    // Reload dashboard data
                    await MainActor.run {
                        viewModel.loadDashboardData()
                    }
                }
            }
        }

    }
    
    

    func handleExpenseChange(_ expenseId: String?, showChat: Bool = false) {
        guard let expenseId = expenseId else {
            return
        }
        
        // Get projectId - prefer the project parameter, fallback to navigationManager
        let projectId = project?.id ?? navigationManager.activeProjectId?.id
        
        guard let projectId = projectId,
              let customerId = customerId else {
            // If projectId is not available yet, wait a bit and retry
            if navigationManager.activeProjectId != nil {
                Task {
                    // Wait for project to be available (navigation might be in progress)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    // Retry
                    handleExpenseChange(expenseId, showChat: showChat)
                }
            }
            return
        }
        
        Task {
            do {
                // Load the expense by ID
                let expenseDoc = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .document(expenseId)
                    .getDocument()
                
                if expenseDoc.exists, var expense = try? expenseDoc.data(as: Expense.self) {
                    expense.id = expenseDoc.documentID
                    
                    await MainActor.run {
                        if showChat {
                            // Show expense chat view
                            expenseForChat = expense
                            showingExpenseChat = true
                            // Clear navigation after showing
                            navigationManager.setExpenseId(nil)
                        } else {
                            // Show expense detail (existing behavior)
                            // Load project and show detail
                            Task {
                                if let project = try? await viewModel.fetchProject(byId: projectId) {
                                    await MainActor.run {
                                        selectedProject = project
                                        showProjectDetail = true
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("⚠️ Expense not found: \(expenseId)")
                    await MainActor.run {
                        navigationManager.setExpenseId(nil)
                    }
                }
            } catch {
                print("❌ Error loading expense: \(error)")
                await MainActor.run {
                    navigationManager.setExpenseId(nil)
                }
            }
        }
    }
    
    func handlePhaseChange(_ phaseId: String?) {
        // When phase notification is tapped, ensure we're in the correct project
        // The phase will be visible in the All Phases section
        // If we're already in the project, just reload phases
        // The phase will be visible once phases are loaded
        Task {
            // Get project ID from navigation manager (should be set when notification is tapped)
            if let projectId = navigationManager.activeProjectId?.id {
                // If we're not in this project, navigation will happen automatically
                // Just ensure phases are loaded
                if project?.id == projectId {
                    await loadPhases()
                }
            }
            
            // Clear the navigation after handling
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                navigationManager.setPhaseId(nil)
            }
        }
    }
    
    func handleRequestChange(_ requestId: String?) {
        guard let requestId = requestId,
              let customerId = customerId else {
            return
        }
        
        Task {
            // Load the specific request by ID from customer's requests collection
            // This function will also extract projectId from the request data
            if let (request, projectId) = await phaseRequestNotificationViewModel.loadRequestByIdWithProject(
                requestId: requestId,
                customerId: customerId
            ) {
                // If we're not in the correct project, we need to navigate to it first
                if let currentProjectId = project?.id, currentProjectId != projectId {
                    // Navigate to the correct project first
                    navigationManager.setProjectId(projectId)
                    // Wait a bit for project to load, then show request
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
                
                // Reload pending requests to ensure we have the latest data
                await phaseRequestNotificationViewModel.loadPendingRequests(
                    projectId: projectId,
                    customerId: customerId
                )
                
                await MainActor.run {
                    selectedRequest = request
                    showingRequestActionSheet = true
                    // Clear the navigation after handling
                    navigationManager.setRequestId(nil)
                }
            } else {
                print("⚠️ Request not found: \(requestId)")
                // Clear the navigation even if request not found
                navigationManager.setRequestId(nil)
            }
        }
    }

    
    // MARK: - Project Overview Section
    private var projectOverviewSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Project Overview")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Project Details")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)

            }
            
            // Project Dates Card - Full width above the grid
            if let project = project {
                ProjectDatesCard(project: project)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.medium) {
                // Show suspended status card if project is suspended (priority over temp approver)
                if project?.isSuspended == true {
                    SuspendedProjectStatsCard(
                        suspendedDate: project?.suspendedDate,
                        suspensionReason: project?.suspensionReason
                    )
                } else if let tempApproverName = tempApproverName {
                    TempApproverStatsCard(
                        approverName: tempApproverName,
                        phoneNumber: tempApproverPhoneNumber ?? "",
                        status: tempApproverStatus,
                        endDate: tempApproverEndDate
                    )
                } else {
                    ProjectStatsCard(
                        title: "Project Status",
                        value: project?.statusType.rawValue ?? "N/A",
                        icon: "circle.fill",
                        color: project?.statusType == .ACTIVE ? .green : .orange
                    )
                }
                
                TotalBudgetCard(viewModel: viewModel, stateManager: stateManager)
                
                Button(action: {
                    showingTeamMembersDetail = true
                    HapticManager.selection()
                }) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(DesignSystem.Typography.title3)
                                .foregroundColor(.blue)
                                .symbolRenderingMode(.hierarchical)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(stateManager.teamMembers.count > 0 ? stateManager.teamMembers.count : (project?.teamMembers.count ?? 0))")
                                .font(DesignSystem.Typography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                            
                            Text("View Team Members")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(DesignSystem.Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 100)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(DesignSystem.CornerRadius.large)
                    .cardStyle(shadow: DesignSystem.Shadow.small)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    scrollToDepartmentSection = true
                    HapticManager.selection()
                }) {
                    ProjectStatsCard(
                        title: "",
                        value: "\(allPhases.count) Phases",
                        icon: "folder.fill",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Enhanced Department Budget Section (Active Phases)
    private var currentPhasesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Section Header - styled like Project Overview with Project Details
            if !filteredCurrentPhases.isEmpty{
                HStack {

                    
                    Spacer()
                    
                    Text("Active Phases")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if filteredCurrentPhases.isEmpty {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                    Text("No Active phases to show")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    NavigationLink {
                        AllPhasesView(
                            phases: allPhases,
                            project: project,
                            role: role,
                            phoneNumber: phoneNumber,
                            onPhaseAdded: {
                                Task {
                                    await loadPhases()
                                }
                            },
                            stateManager: stateManager
                        )
                    } label: {
                        Text("View All Phases")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                    }
                    .secondaryButton()
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.medium)
                .cardStyle()
            
            } else {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    ForEach(filteredCurrentPhases, id: \.id) { phase in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            // Header (only phase name + timeline inline)
                            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.small) {
                                VStack(alignment: .leading, spacing: 2) {
                                    TruncatedTextWithTooltip(
                                        phase.name,
                                        font: DesignSystem.Typography.headline,
                                        foregroundColor: .primary,
                                        lineLimit: 1
                                    )

                                    if let daysInfo = daysRemaining(for: phase) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock.fill")
                                                .font(.caption2)
                                                .foregroundColor(daysInfo.color)
                                                .accessibilityHidden(true)
                                            Text(daysInfo.text)
                                                .font(DesignSystem.Typography.caption1)
                                                .foregroundColor(daysInfo.color)
                                                .fontWeight(daysInfo.color == .red || daysInfo.color == .orange ? .semibold : .regular)
                                        }
                                    }
                                    
                                    if let phaseBudget = phaseBudgetMap[phase.id] {
                                        HStack {
                                            Text("Total")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.purple.opacity(0.15))
                                                .foregroundColor(.purple)
                                                .cornerRadius(8)

                                            Spacer(minLength: 8)

                                            Text(Int(phaseBudget.totalBudget).formattedCurrency)
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.purple)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.purple.opacity(0.08))
                                        .cornerRadius(12)

                                    }
                                }

                                Spacer()

                                HStack(spacing: 6){
                                    // Phase Status Badges
                                    VStack(spacing: 4){
                                        // Show "Completed" badge if phase is completed
                                        if isPhaseCompleted(phase) {
                                            Text("Completed")
                                                .font(DesignSystem.Typography.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.12))
                                                .clipShape(Capsule())
                                                .accessibilityLabel("Phase status: Completed")
                                        }
                                        // Show "In Progress" badge if phase is in progress AND enabled
                                        else if isPhaseInProgress(phase) && (phaseEnabledMap[phase.id] ?? true) {
                                            Text("Active")
                                                .font(DesignSystem.Typography.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.green.opacity(0.12))
                                                .clipShape(Capsule())
                                                .accessibilityLabel("Phase status: Active")
                                        }
                                        // Show "Planned" badge if phase is in the future
                                        else if isPhaseInFuture(phase) {
                                            Text("Planned")
                                                .font(DesignSystem.Typography.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.purple)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.purple.opacity(0.12))
                                                .clipShape(Capsule())
                                                .accessibilityLabel("Phase status: Planned")
                                        }
                                        
                                        // Extension Badge - Show if phase has accepted extension
                                        if phaseExtensionMap[phase.id] == true {
                                            HStack(spacing: 4) {
                                                Text("Extended")
                                                    .font(DesignSystem.Typography.caption2)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.12))
                                            .clipShape(Capsule())
                                            .accessibilityLabel("Phase extended via accepted request")
                                            .transition(.opacity.combined(with: .scale))
                                        }
                                    }
                                    Spacer()
                                    VStack{
                                        HStack{
                                            Spacer()
                                            
                                            // 3-dot menu for Complete Phase (available for all roles, hidden when archived)
                                            if project?.statusType != .ARCHIVE {
                                                Menu {
                                                    Button(role: .destructive) {
                                                        HapticManager.selection()
                                                        phaseToComplete = phase
                                                        showingCompletePhaseConfirmation = true
                                                    } label: {
                                                        Label("Complete Phase", systemImage: "checkmark.circle.fill")
                                                    }
                                                } label: {
                                                    Image(systemName: "ellipsis")
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 24, height: 24)
                                                        .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                                .padding(.leading, role == .ADMIN ? 4 : 0)
                                                .padding(.vertical, 2)
                                            }
                                        }

                                        
                                            if isPhaseInProgress(phase) && (phaseEnabledMap[phase.id] ?? true) && !isPhaseCompleted(phase) {
                                                if role == .ADMIN{
                                                    HStack{
                                                    // Enable toggle (not shown for completed phases or archived projects)
                                                    if project?.statusType != .ARCHIVE {
                                                        Toggle("", isOn: Binding(
                                                            get: { phaseEnabledMap[phase.id] ?? true },
                                                            set: { newValue in
                                                                phaseEnabledMap[phase.id] = newValue
                                                                updatePhaseEnabled(phaseId: phase.id, enabled: newValue)
                                                            }
                                                        ))
                                                        .labelsHidden()
                                                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                                        .scaleEffect(0.85)
                                                        .padding(.leading, 6)
                                                    }
                                                        Spacer()
                                                    // Hide Add Department button when project is archived
                                                    if project?.statusType != .ARCHIVE {
                                                        Button {
                                                            HapticManager.selection()
                                                            phaseForDepartmentAdd = phase
                                                            showingAddDepartment = true
                                                        } label: {
                                                            Image(systemName: "plus.circle.fill")
                                                                .font(.system(size: 16, weight: .medium))
                                                                .foregroundColor(.accentColor)
                                                                .accessibilityLabel("Add department to this phase")
                                                        }
                                                        .buttonStyle(.plain)
                                                        .padding(.leading, 2)
                                                        .padding(.vertical, 2)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Phase Budget Summary
                            if let phaseBudget = phaseBudgetMap[phase.id] {
                                HStack(spacing: DesignSystem.Spacing.medium) {
                                    // Total Budget
//                                    VStack(alignment: .leading, spacing: 4) {
//                                        Text("Total Budget")
//                                            .font(DesignSystem.Typography.caption1)
//                                            .foregroundColor(.secondary)
//                                        Text(Int(phaseBudget.totalBudget).formattedCurrency)
//                                            .font(DesignSystem.Typography.subheadline)
//                                            .fontWeight(.semibold)
//                                            .foregroundColor(.primary)
//                                    }
                                    
//                                    Spacer()
                                    
                                    // Approved Amount
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("Approved")
                                            .font(DesignSystem.Typography.caption1)
                                            .foregroundColor(.secondary)
                                        Text(Int(phaseBudget.spent).formattedCurrency)
                                            .font(DesignSystem.Typography.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Spacer()
                                    
                                    // Remaining Amount
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Remaining")
                                            .font(DesignSystem.Typography.caption1)
                                            .foregroundColor(.secondary)
                                        Text(Int(phaseBudget.remaining).formattedCurrency)
                                            .font(DesignSystem.Typography.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(phaseBudget.remaining >= 0 ? .green : .red)
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.small)
                                .padding(.vertical, DesignSystem.Spacing.small)
                                .background(Color(.tertiarySystemFill).opacity(0.5))
                                .cornerRadius(DesignSystem.CornerRadius.small)
                            }
                            
                            // Horizontal departments scroller (cell style) with scroll hint
                            ZStack(alignment: .leading) {
                                ScrollView(.horizontal, showsIndicators: true) {
                                    HStack(spacing: DesignSystem.Spacing.medium) {
                                        ForEach(phase.departments.sorted(by: { $0.key < $1.key }), id: \.key) { deptKey, amount in
                                            // Strip phaseId_ prefix for display
                                            let displayName = deptKey.displayDepartmentName()
                                            DepartmentMiniCard(
                                                title: displayName,
                                                amount: amount,
                                                spent: phaseDepartmentSpentMap[phase.id]?[deptKey] ?? 0,
                                                onTap: {
                                                    // Use the display name (without phaseId prefix) for selection
                                                    selectedDepartmentForDetail = displayName
                                                    selectedPhaseIdForDetail = phase.id
                                                    // Small delay to ensure state is set before showing sheet
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                        showingDepartmentDetail = true
                                                    }
                                                }
                                            )
                                        }
                                        
                                        // Add "Other" department card for anonymous expenses
                                        if let anonymousSpent = phaseAnonymousExpensesMap[phase.id], anonymousSpent > 0 {
                                            OtherDepartmentCard(
                                                spent: anonymousSpent,
                                                onTap: {
                                                    // Set a special marker to indicate "Other" department
                                                    selectedDepartmentForDetail = "Other"
                                                    selectedPhaseIdForDetail = phase.id
                                                    // Store phase ID for filtering anonymous expenses
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                        showingDepartmentDetail = true
                                                    }
                                                }
                                            )
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                                .scrollIndicators(.visible)
                                .scrollIndicatorsFlash(onAppear: false)
                                // Left scroll hint
                                HStack {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(6)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .padding(.leading, 6)
                                    Spacer()
                                }
                                .allowsHitTesting(false)
                            }
                        }
                        .padding(DesignSystem.Spacing.medium)
                        .cardStyle()
                    }
                    
                    // View All Phases button under the last scroller
                    NavigationLink {
                        AllPhasesView(
                            phases: allPhases,
                            project: project,
                            role: role,
                            phoneNumber: phoneNumber,
                            onPhaseAdded: {
                                Task {
                                    await loadPhases()
                                }
                            },
                            stateManager: stateManager
                        )
                    } label: {
                        Text("View All Phases")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                    }
                    .secondaryButton()
                }
//                .onAppear{
//                    print("DEEBG 1: Current Phases:\(filteredCurrentPhases.count)")
//                }
            }
        }
    }
    
    // MARK: - Enhanced Charts Section
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
            // Department Distribution Chart
            if !viewModel.departmentBudgets.isEmpty {
                departmentDistributionChart
            }
            
            //            // Budget vs Spent Chart
            //            if !viewModel.departmentBudgets.isEmpty {
            //                budgetComparisonChart
            //            }
        }
    }
    
    // MARK: - Department Distribution Chart
    private var departmentDistributionChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Header
            HStack {
                Text("Department Distribution")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Budget Allocation")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Chart Content
            VStack(spacing: DesignSystem.Spacing.large) {
                // Enhanced Donut Chart
                ZStack {
                    // Background circle with subtle styling
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 24)
                        .frame(width: 220, height: 220)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGray6), lineWidth: 2)
                                .frame(width: 220, height: 220)
                        )
                    
                    // Data segments with enhanced styling
                    ForEach(Array(viewModel.departmentBudgets.enumerated()), id: \.element.department) { index, budget in
                        Circle()
                            .trim(from: viewModel.startAngle(for: index), to: viewModel.endAngle(for: index))
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        budget.color,
                                        budget.color.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 24, lineCap: .round)
                            )
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(-90))
                            .animation(
                                .easeInOut(duration: 1.2)
                                .delay(Double(index) * 0.15),
                                value: viewModel.departmentBudgets
                            )
                            .shadow(color: budget.color.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    
                    // Enhanced center content
                    VStack(spacing: 6) {
                        Text("Total Budget")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(viewModel.totalProjectBudgetFormatted)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        
                        //                        Text("₹")
                        //                            .font(DesignSystem.Typography.caption2)
                        //                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    )
                }
                
                // Enhanced Legend
                departmentLegendView
            }
            .padding(DesignSystem.Spacing.large)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .stroke(Color(.systemGray5), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        }
    }
    
    // MARK: - Department Legend View
    private var departmentLegendView: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            ForEach(Array(viewModel.departmentBudgets.enumerated()), id: \.element.department) { index, budget in
                departmentLegendRow(budget: budget, index: index)
            }
        }
    }

    // MARK: - Helpers for Phases
    private var phaseDateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }
    
    private var now: Date { Date() }
    
    private var filteredCurrentPhases: [PhaseSummary] {
        allPhases.filter { phase in
            // Only show phases that are in progress AND enabled
            isPhaseInProgress(phase) && (phaseEnabledMap[phase.id] ?? true)
        }
    }
    
    private func isPhaseInFuture(_ phase: PhaseSummary) -> Bool {
        let current = now
        if let startDate = phase.start {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: current)
            let phaseStart = calendar.startOfDay(for: startDate)
            return phaseStart > today
        }
        return false
    }
    
    private func isPhaseCompleted(_ phase: PhaseSummary) -> Bool {
        let current = now
        if let endDate = phase.end {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: current)
            let phaseEnd = calendar.startOfDay(for: endDate)
            return today > phaseEnd
        }
        return false
    }

    private func isPhaseInProgress(_ phase: PhaseSummary) -> Bool {
        let current = now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: current)
        
        if let startDate = phase.start, let endDate = phase.end {
            // both are non-nil - compare at start of day level
            let phaseStart = calendar.startOfDay(for: startDate)
            let phaseEnd = calendar.startOfDay(for: endDate)
            // Phase is in progress if today is between start and end (inclusive)
            return phaseStart <= today && today <= phaseEnd
        } else if let startDate = phase.start {
            // only startDate
            let phaseStart = calendar.startOfDay(for: startDate)
            return phaseStart <= today
        } else if let endDate = phase.end {
            // only endDate - compare at start of day level
            let phaseEnd = calendar.startOfDay(for: endDate)
            // Phase is in progress if today is on or before the end date
            return today <= phaseEnd
        } else {
            // neither provided
            return true
        }
    }

    private func phaseTimelineText(_ phase: PhaseSummary) -> String {
        switch (phase.start, phase.end) {
        case (nil, nil):
            return ""
        case (let s?, nil):
            return "Since: \(phaseDateFormatter.string(from: s))"
        case (nil, let e?):
            return "Until: \(phaseDateFormatter.string(from: e))"
        case (let _?, let e?):
            return "Until: \(phaseDateFormatter.string(from: e))"
        }
    }
    
    private func daysRemaining(for phase: PhaseSummary) -> (text: String, color: Color)? {
        let current = now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: current)
        
        guard let endDate = phase.end else {
            // If no end date, check start date
            if let startDate = phase.start {
                let phaseStart = calendar.startOfDay(for: startDate)
                let daysSince = calendar.dateComponents([.day], from: phaseStart, to: today).day ?? 0
                return daysSince >= 0 ? ("\(daysSince) days passed", .secondary) : nil
            }
            return nil
        }
        
        // Compare at start of day level
        let phaseEnd = calendar.startOfDay(for: endDate)
        let daysRemaining = calendar.dateComponents([.day], from: today, to: phaseEnd).day ?? 0
        
        if daysRemaining < 0 {
            return ("\(abs(daysRemaining)) days overdue", Color.red)
        } else if daysRemaining == 0 {
            return ("0 days remaining", Color.red)
        } else if daysRemaining < 5 {
            return ("\(daysRemaining) days remaining", Color.red)
        } else if daysRemaining < 15 {
            return ("\(daysRemaining) days remaining", Color.orange)
        } else {
            return ("\(daysRemaining) days remaining", Color.secondary)
        }
    }
    
    // MARK: - Refresh All Data
    /// Comprehensive refresh function that fetches all data from Firebase
    /// Follows Apple's refreshable pattern for pull-to-refresh
    /// Reloads project from Firestore to get latest changes
    /// This ensures DashboardView reflects changes made in AdminProjectDetailView
    /// Follows Apple's best practices for data synchronization
    private func reloadProjectFromFirestore(projectId: String, customerId: String) async {
        do {
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .getDocument()
            
            if projectDoc.exists, var updatedProject = try? projectDoc.data(as: Project.self) {
                // Ensure the project ID is set (Firestore document ID)
                updatedProject.id = projectDoc.documentID
                
                // Update the project property which will trigger onChange
                await MainActor.run {
                    // Create a new Project instance with updated data
                    // This will trigger the onChange(of: project) handler
                    self.project = updatedProject
                    viewModel.updateProject(updatedProject)
                    
                    // Provide haptic feedback to indicate successful refresh
                    HapticManager.impact(.light)
                }
            }
        } catch {
            print("❌ Error reloading project from Firestore: \(error.localizedDescription)")
            await MainActor.run {
                HapticManager.notification(.error)
            }
        }
    }
    
    /// Uses structured concurrency for parallel data loading as recommended by Apple
    private func refreshAllData() async {
        guard let projectId = project?.id, let customerId = customerId else {
            return
        }
        
        // Use structured concurrency to load all data in parallel for optimal performance
        // This follows Apple's recommendation for efficient data loading
        // All tasks run concurrently to minimize refresh time
        async let phasesTask = loadPhases()
        async let stateManagerTask = stateManager.loadAllData(projectId: projectId, customerId: customerId)
        async let teamMembersTask = stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
        async let tempApproverTask = fetchTempApproverData()
        async let phaseRequestsTask: Void = {
            if role == .ADMIN {
                await phaseRequestNotificationViewModel.loadPendingRequests(
                    projectId: projectId,
                    customerId: customerId
                )
            }
        }()
        
        // Wait for all async tasks to complete
        // All tasks run in parallel for optimal performance
        _ = await phasesTask
        _ = await stateManagerTask
        _ = await teamMembersTask
        _ = await tempApproverTask
        await phaseRequestsTask
        
        // Load dashboard data after phases are loaded (needs phase data)
        await MainActor.run {
            viewModel.loadDashboardData()
        }
        
        // Ensure state manager is synced with local state after refresh
        await MainActor.run {
            // Sync phase enabled map
            stateManager.phaseEnabledMap = phaseEnabledMap
            // Sync extension map
            stateManager.phaseExtensionMap = phaseExtensionMap
            // Sync anonymous expenses map
            stateManager.phaseAnonymousExpensesMap = phaseAnonymousExpensesMap
            // Recalculate totals after all data is loaded
            stateManager.recalculateProjectTotals()
        }
        
        // Provide haptic feedback when refresh completes
        await MainActor.run {
            HapticManager.impact(.light)
        }
    }
    
    private func loadPhases() async {
        guard let projectId = project?.id else { return }
        guard let customerId = customerId else {
            return
        }
        do {
            let snapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .order(by: "phaseNumber")
                .getDocuments()
            var collected: [PhaseSummary] = []
            for doc in snapshot.documents {
                if let p = try? doc.data(as: Phase.self) {
                    let s = p.startDate.flatMap { phaseDateFormatter.date(from: $0) }
                    let e = p.endDate.flatMap { phaseDateFormatter.date(from: $0) }
                    collected.append(PhaseSummary(id: doc.documentID, name: p.phaseName, start: s, end: e, departments: p.departments))
                    phaseEnabledMap[doc.documentID] = p.isEnabledValue
                }
            }
            await MainActor.run { 
                allPhases = collected
                // Sync with state manager
                stateManager.allPhases = collected
            }
            // Load phase budgets after phases are loaded
            await loadPhaseBudgets()
            // Load department spent amounts per phase
            await loadPhaseDepartmentSpent()
            // Load extension status for phases
            await loadPhaseExtensions()
            // Load anonymous expenses per phase
            await loadPhaseAnonymousExpenses()
        } catch {
            // Error loading phases
        }
    }
    
    private func loadPhaseExtensions() async {
        guard let projectId = project?.id else { return }
        guard let customerId = customerId else {
            return
        }
        
        // Wait for phases to be loaded
        guard !allPhases.isEmpty else {
            return
        }
        
        do {
            var extensionMap: [String: Bool] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
                        
            // Check each phase for accepted extension requests
            for phase in allPhases {
                // Get phase end date from Firebase directly (as String)
                let phaseDoc = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phase.id)
                    .getDocument()
                
                guard let phaseData = phaseDoc.data(),
                      let phaseEndDateStr = phaseData["endDate"] as? String else {
                    print("⚠️ Phase \(phase.id) has no endDate")
                    continue
                }
                                
                // Query requests collection for accepted requests
                let requestsSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phase.id)
                    .collection("requests")
                    .whereField("status", isEqualTo: "ACCEPTED")
                    .getDocuments()
                
                
                // Check if any accepted request's extendedDate matches phase endDate
                var hasExtension = false
                for requestDoc in requestsSnapshot.documents {
                    let requestData = requestDoc.data()
                    if let extendedDate = requestData["extendedDate"] as? String {
                        // Compare extendedDate with phase endDate (exact string match)
                        if extendedDate.trimmingCharacters(in: .whitespacesAndNewlines) == phaseEndDateStr.trimmingCharacters(in: .whitespacesAndNewlines) {
                            hasExtension = true
                            break
                        }
                    }
                }
                
                extensionMap[phase.id] = hasExtension
            }
            
            await MainActor.run {
                phaseExtensionMap = extensionMap
            }
        } catch {
            // Error loading phase extensions
        }
    }
    
    private func loadPhaseAnonymousExpenses() async {
        guard let projectId = project?.id else { return }
        guard let customerId = customerId else {
            return
        }
        
        // Wait for phases to be loaded
        guard !allPhases.isEmpty else {
            return
        }
        
        do {
            // Load all anonymous expenses for this project
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .whereField("isAnonymous", isEqualTo: true)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            // Calculate anonymous expenses per phase
            var anonymousMap: [String: Double] = [:]
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self),
                   let phaseId = expense.phaseId {
                    anonymousMap[phaseId, default: 0] += expense.amount
                }
            }
            
            await MainActor.run {
                phaseAnonymousExpensesMap = anonymousMap
            }
        } catch {
            // Error loading phase anonymous expenses
        }
    }
    
    private func loadPhaseBudgets() async {
        guard let projectId = project?.id else { return }
        guard let customerId = customerId else {
            return
        }
        do {
            // Load all approved expenses for this project
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            // Calculate spent amount per phase
            var phaseSpentMap: [String: Double] = [:]
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self),
                   let phaseId = expense.phaseId {
                    phaseSpentMap[phaseId, default: 0] += expense.amount
                }
            }
            
            // Calculate total budget and create PhaseBudget for each phase
            var budgetMap: [String: PhaseBudget] = [:]
            for phase in allPhases {
                let totalBudget = phase.departments.values.reduce(0, +)
                let spent = phaseSpentMap[phase.id] ?? 0
                budgetMap[phase.id] = PhaseBudget(
                    id: phase.id,
                    totalBudget: totalBudget,
                    spent: spent
                )
            }
            
            await MainActor.run {
                phaseBudgetMap = budgetMap
                // Sync with state manager
                stateManager.phaseBudgetMap = budgetMap
                stateManager.recalculateProjectTotals()
            }
        } catch {
            // Error loading phase budgets
        }
    }
    
    private func loadPhaseDepartmentSpent() async {
        guard let projectId = project?.id else { return }
        guard let customerId = customerId else {
            return
        }
        do {
            // Load all approved expenses for this project (excluding anonymous)
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            // Calculate spent amount per department per phase
            // Structure: [phaseId: [department: spent]]
            var departmentSpentMap: [String: [String: Double]] = [:]
            
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self),
                   let phaseId = expense.phaseId,
                   expense.isAnonymous != true { // Exclude anonymous expenses
                    if departmentSpentMap[phaseId] == nil {
                        departmentSpentMap[phaseId] = [:]
                    }
                    // Expenses use just department name, but we need to match to phaseId_departmentName keys
                    // Try both formats: phaseId_departmentName (new) and just departmentName (old/expense format)
                    let departmentKey = String.departmentKey(phaseId: phaseId, departmentName: expense.department)
                    // Store using the new format key, but also support old format for backward compatibility
                    departmentSpentMap[phaseId]?[departmentKey, default: 0] += expense.amount
                    // Also store with old format for backward compatibility
                    departmentSpentMap[phaseId]?[expense.department, default: 0] += expense.amount
                }
            }
            
            await MainActor.run {
                phaseDepartmentSpentMap = departmentSpentMap
                // Sync with state manager
                stateManager.phaseDepartmentSpentMap = departmentSpentMap
                stateManager.recalculateProjectTotals()
            }
        } catch {
            // Error loading phase department spent
        }
    }

    private func updatePhaseEnabled(phaseId: String, enabled: Bool) {
        guard let projectId = project?.id else { return }
        guard let customerId = customerId else {
            return
        }
        FirebasePathHelper.shared
            .phasesCollection(customerId: customerId, projectId: projectId)
            .document(phaseId)
            .updateData([
                "isEnabled": enabled,
                "updatedAt": Timestamp()
            ]) { error in
                if let _ = error {
                    // Error updating phase enabled status
                }
            }
    }
    
    // MARK: - Start Phase Now
    private func startPhaseNow(_ phase: PhaseSummary) async {
        guard let projectId = project?.id,
              let customerId = customerId else {
            return
        }
        
        do {
            // Format today's date as start date
            let today = Date()
            let startDateStr = phaseDateFormatter.string(from: today)
            
            // Update phase start date to today
            try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
                .updateData([
                    "startDate": startDateStr,
                    "updatedAt": Timestamp()
                ])
            
            // If project status is LOCKED, also update project planned start date
            if let project = project, project.statusType == .LOCKED {
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData([
                        "plannedDate": startDateStr,
                        "updatedAt": Timestamp()
                    ])
                
                // Post notification to refresh project
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            }
            
            // Log timeline change to Firebase changes collection
            guard let currentUserUID = Auth.auth().currentUser?.uid else {
                print("⚠️ Warning: No current user UID found, skipping change log")
                return
            }
            
            let changeLog = PhaseTimelineChange(
                phaseId: phase.id,
                projectId: projectId,
                previousStartDate: phase.start.map { phaseDateFormatter.string(from: $0) },
                previousEndDate: phase.end.map { phaseDateFormatter.string(from: $0) },
                newStartDate: startDateStr,
                newEndDate: phase.end.map { phaseDateFormatter.string(from: $0) },
                changedBy: currentUserUID,
                requestID: nil // Manual change via "Start Now" button
            )
            
            let phaseRef = FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
            
            let changesRef = phaseRef.collection("changes").document()
            try await changesRef.setData(from: changeLog)
            
            print("✅ Logged phase start change: phaseId=\(phase.id), changedBy=\(currentUserUID), newStartDate=\(startDateStr)")
            
            // Reload phases to reflect the change
            await loadPhases()
            
            // Post notification to refresh
            NotificationCenter.default.post(name: NSNotification.Name("PhaseUpdated"), object: nil)
            
            // Provide haptic feedback
            await MainActor.run {
                HapticManager.notification(.success)
            }
        } catch {
            print("Error starting phase: \(error.localizedDescription)")
            await MainActor.run {
                HapticManager.notification(.error)
            }
        }
    }
    
    // MARK: - Complete Phase
    private func completePhase(_ phase: PhaseSummary) async {
        guard let projectId = project?.id,
              let customerId = customerId else {
            return
        }
        
        do {
            // Format today's date as end date
            let today = Date()
            let endDateStr = phaseDateFormatter.string(from: today)
            
            // Update phase end date to today
            try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
                .updateData([
                    "endDate": endDateStr,
                    "updatedAt": Timestamp()
                ])
            
            // Log timeline change to Firebase changes collection
            guard let currentUserUID = Auth.auth().currentUser?.uid else {
                print("⚠️ Warning: No current user UID found, skipping change log")
                return
            }
            
            let changeLog = PhaseTimelineChange(
                phaseId: phase.id,
                projectId: projectId,
                previousStartDate: phase.start.map { phaseDateFormatter.string(from: $0) },
                previousEndDate: phase.end.map { phaseDateFormatter.string(from: $0) },
                newStartDate: phase.start.map { phaseDateFormatter.string(from: $0) },
                newEndDate: endDateStr,
                changedBy: currentUserUID,
                requestID: nil // Manual change via "Complete Phase" button
            )
            
            let phaseRef = FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
            
            let changesRef = phaseRef.collection("changes").document()
            try await changesRef.setData(from: changeLog)
            
            print("✅ Logged phase completion change: phaseId=\(phase.id), changedBy=\(currentUserUID), newEndDate=\(endDateStr)")
            
            // Reload phases to reflect the change
            await loadPhases()
            
            // Post notification to refresh
            NotificationCenter.default.post(name: NSNotification.Name("PhaseUpdated"), object: nil)
            
            // Provide haptic feedback
            await MainActor.run {
                HapticManager.notification(.success)
            }
        } catch {
            print("Error completing phase: \(error.localizedDescription)")
            await MainActor.run {
                HapticManager.notification(.error)
            }
        }
    }
    
    // MARK: - Department Legend Row
    private func departmentLegendRow(budget: DepartmentBudget, index: Int) -> some View {
        // Use max of totalBudget and approvedBudget for calculation to include "Other Expenses"
        let totalBudget = viewModel.departmentBudgets.reduce(0) { $0 + max($1.totalBudget, $1.approvedBudget) }
        let budgetValue = max(budget.totalBudget, budget.approvedBudget)
        let percentage = totalBudget != 0 ? Int((budgetValue / totalBudget) * 100) : 0
        
        return HStack(spacing: DesignSystem.Spacing.medium) {
            // Color indicator with enhanced styling
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            budget.color,
                            budget.color.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 16, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemBackground), lineWidth: 2)
                )
                .shadow(color: budget.color.opacity(0.3), radius: 2, x: 0, y: 1)
            
            // Department info
            VStack(alignment: .leading, spacing: 2) {
                TruncatedTextWithTooltip(
                    budget.department.displayDepartmentName(),
                    font: DesignSystem.Typography.subheadline,
                    fontWeight: .semibold,
                    foregroundColor: .primary,
                    lineLimit: 1
                )
                
                HStack(spacing: 4) {
                    Text("\(budgetValue.formattedCurrency)")
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("•")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(percentage)%")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Percentage indicator
            Text("\(percentage)%")
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.bold)
                .foregroundColor(budget.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(budget.color.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(budget.color.opacity(0.2), lineWidth: 1)
        )
        .animation(
            .easeInOut(duration: 0.6)
            .delay(Double(index) * 0.1),
            value: viewModel.departmentBudgets
        )
    }
    
    // MARK: - Fetch Temporary Approver Data
    private func fetchTempApproverData() async {
        guard let project = project, let tempApproverID = project.tempApproverID else {
            await MainActor.run {
                tempApproverName = nil
                tempApproverPhoneNumber = nil
                tempApproverStatus = nil
                tempApproverEndDate = nil
            }
            return
        }
        
        guard let customerId = customerId else {
            return
        }
        
        do {
            let db = Firestore.firestore()
            
            // Fetch user name from customer-specific users collection
            let userDocument = try await FirebasePathHelper.shared
                .usersCollection(customerId: customerId)
                .document(tempApproverID)
                .getDocument()
            
            if userDocument.exists, let user = try? userDocument.data(as: User.self) {
                let approverName = user.name
                let approverPhoneNumber = user.phoneNumber
                
                // Always use the temp approver's phone number for the query
                // This ensures temp approver details show for all users (admin, approver, etc.)
                let approverPhone = user.phoneNumber
                
                // Fetch latest temp approver record from customer-specific project
                guard let projectId = project.id else { return }
                let tempApproverSnapshot = try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .collection("tempApprover")
                    .whereField("approverId", isEqualTo: approverPhone)
                    .order(by: "updatedAt", descending: true)
                    .limit(to: 1)
                    .getDocuments()
                
                var endDate: Date? = nil
                var status: TempApproverStatus? = nil
                
                if let tempApproverDoc = tempApproverSnapshot.documents.first,
                   let tempApprover = try? tempApproverDoc.data(as: TempApprover.self) {
                    endDate = tempApprover.endDate
                    status = tempApprover.status
                }
                
                await MainActor.run {
                    tempApproverName = approverName
                    tempApproverPhoneNumber = approverPhoneNumber
                    tempApproverEndDate = endDate
                    tempApproverStatus = status
                }
            } else {
                await MainActor.run {
                    tempApproverName = nil
                    tempApproverPhoneNumber = nil
                    tempApproverStatus = nil
                    tempApproverEndDate = nil
                }
            }
        } catch {
            print("Error fetching temp approver data: \(error)")
            await MainActor.run {
                tempApproverName = nil
                tempApproverPhoneNumber = nil
                tempApproverStatus = nil
                tempApproverEndDate = nil
            }
        }
    }

    
    // MARK: - Budget Comparison Chart
    private var budgetComparisonChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Budget vs Spent Analysis")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                ForEach(viewModel.departmentBudgets, id: \.department) { budget in
                    BudgetComparisonRow(budget: budget)
                }
            }
            .padding(DesignSystem.Spacing.medium)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.large)
            .cardStyle(shadow: DesignSystem.Shadow.small)
        }
    }
}

// MARK: - Budget Comparison Row
private struct BudgetComparisonRow: View {
    let budget: DepartmentBudget
    
    private var spentPercentage: Double {
        budget.approvedBudget / budget.totalBudget
    }
    
    private var remainingAmount: Double {
        budget.totalBudget - budget.approvedBudget
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Text(budget.department)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("₹\(Double(budget.approvedBudget).formattedCurrency) / ₹\(Double(budget.totalBudget).formattedCurrency)")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar with animation
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemFill))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(budget.color.gradient)
                        .frame(width: geometry.size.width * spentPercentage, height: 12)
                        .animation(.easeInOut(duration: 1.0), value: spentPercentage)
                }
            }
            .frame(height: 12)
            
            // Percentage indicator
            HStack {
                Text("\(Int(spentPercentage * 100))% utilized")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("₹\(remainingAmount.formattedCurrency) remaining")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(remainingAmount > 0 ? .green : .red)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

// MARK: - Add Department Sheet
private struct AddDepartmentSheet: View {
    let projectId: String
    let phaseId: String
    let phaseName: String
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var departmentName: String = ""
    @State private var budgetText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var departmentNameError: String?
    @State private var existingDepartmentNames: [String] = []
    @FocusState private var focusedField: Field?

    private enum Field { case name, budget }

    private var isFormValid: Bool {
        !departmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        departmentNameError == nil
    }
    
    // MARK: - Indian Number Formatting Helpers
    
    // Helper to remove formatting (commas, spaces, etc.)
    private func removeFormatting(from value: String) -> String {
        return value.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    // Format number according to Indian numbering system (lakhs, crores)
    private func formatIndianNumber(_ number: Double) -> String {
        let integerPart = Int(number)
        let decimalPart = number - Double(integerPart)
        let integerString = String(integerPart)
        let digits = Array(integerString)
        let count = digits.count
        
        if count < 4 {
            var result = integerString
            if decimalPart > 0.0001 {
                let decimalString = String(format: "%.2f", decimalPart)
                if let dotIndex = decimalString.firstIndex(of: ".") {
                    let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                    result += "." + afterDot
                }
            }
            return result
        }
        
        var groups: [String] = []
        var remainingDigits = digits
        
        if remainingDigits.count >= 3 {
            let lastThree = String(remainingDigits.suffix(3))
            groups.append(lastThree)
            remainingDigits = Array(remainingDigits.dropLast(3))
        } else {
            groups.append(String(remainingDigits))
            remainingDigits = []
        }
        
        while remainingDigits.count >= 2 {
            let lastTwo = String(remainingDigits.suffix(2))
            groups.insert(lastTwo, at: 0)
            remainingDigits = Array(remainingDigits.dropLast(2))
        }
        
        if remainingDigits.count == 1 {
            groups.insert(String(remainingDigits[0]), at: 0)
        }
        
        let result = groups.joined(separator: ",")
        var finalResult = result
        if decimalPart > 0.0001 {
            let decimalString = String(format: "%.2f", decimalPart)
            if let dotIndex = decimalString.firstIndex(of: ".") {
                let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                finalResult += "." + afterDot
            }
        }
        
        return finalResult
    }
    
    // Method to format amount as user types
    func formatAmountInput(_ input: String) -> String {
        let cleaned = removeFormatting(from: input)
        guard !cleaned.isEmpty else { return "" }
        guard let number = Double(cleaned) else { return cleaned }
        return formatIndianNumber(number)
    }
    
    // MARK: - Validation Functions
    
    private func validateDepartmentName() {
        let trimmedName = departmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            departmentNameError = nil
            return
        }
        
        // Check for duplicate department names within the same phase (case-insensitive)
        let isDuplicate = existingDepartmentNames.contains { existingName in
            existingName.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
        
        if isDuplicate {
            departmentNameError = "\"\(trimmedName)\" already exists in \"\(phaseName)\". Enter a unique department name."
        } else {
            departmentNameError = nil
        }
    }
    
    private func loadExistingDepartmentNames() {
        Task {
            do {
                guard let customerId = Auth.auth().currentUser?.uid else {
                    return
                }
                
                let phaseDoc = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phaseId)
                    .getDocument()
                
                guard let phaseData = phaseDoc.data(),
                      let departments = phaseData["departments"] as? [String: Any] else {
                    await MainActor.run {
                        existingDepartmentNames = []
                    }
                    return
                }
                
                // Extract department names from keys (remove phaseId_ prefix if present)
                var departmentNames: [String] = []
                for deptKey in departments.keys {
                    let displayName = deptKey.displayDepartmentName()
                    departmentNames.append(displayName)
                }
                
                await MainActor.run {
                    existingDepartmentNames = departmentNames
                }
            } catch {
                await MainActor.run {
                    existingDepartmentNames = []
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a department to \(phaseName)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    TextField("Department name", text: $departmentName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(departmentNameError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                        .onChange(of: departmentName) { _, _ in
                            validateDepartmentName()
                        }
                    
                    if let error = departmentNameError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }

                    HStack {
                        TextField("Budget (₹)", text: Binding(
                            get: { budgetText },
                            set: { newValue in
                                budgetText = formatAmountInput(newValue)
                            }
                        ))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .budget)
                        if let amount = Double(removeFormatting(from: budgetText)) {
                            Text(Int(amount).formattedCurrency)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: { Text("Department Details").textCase(.uppercase) } footer: { Text("Budget is optional and can be 0.") }

                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle("Add Department")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isFormValid || isSaving)
                        .fontWeight(.semibold)
                }
                // Removed custom keyboard toolbar per request
            }
            .onAppear {
                focusedField = .name
                loadExistingDepartmentNames()
            }
        }
    }

    private func save() {
        // Validate department name before saving
        validateDepartmentName()
        
        guard isFormValid else {
            if let error = departmentNameError {
                errorMessage = error
            }
            return
        }
        
        let amount = Double(removeFormatting(from: budgetText)) ?? 0
        isSaving = true
        errorMessage = nil

        // Get customerId from authService
        guard let customerId = Auth.auth().currentUser?.uid else {
            errorMessage = "Customer ID not found. Please log in again."
            isSaving = false
            return
        }

        // Format department key as phaseId_departmentName
        let departmentKey = String.departmentKey(phaseId: phaseId, departmentName: departmentName)
        
        FirebasePathHelper.shared
            .phasesCollection(customerId: customerId, projectId: projectId)
            .document(phaseId)
            .setData([
                "departments": [
                    departmentKey: amount
                ]
            ], merge: true) { error in
                if let error = error {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                } else {
                    // Update project budget after adding department
                    Task {
                        await updateProjectBudget(projectId: projectId, customerId: customerId)
                        await MainActor.run {
                            isSaving = false
                            onSaved()
                            dismiss()
                        }
                    }
                }
            }

    }
    
    // Helper function to update project budget
    private func updateProjectBudget(projectId: String, customerId: String) async {
        do {
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            var totalBudget: Double = 0
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    totalBudget += phase.departments.values.reduce(0, +)
                }
            }
            
            // Update project budget
            try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .updateData([
                    "budget": totalBudget,
                    "updatedAt": Timestamp()
                ])
        } catch {
            print("Error updating project budget: \(error.localizedDescription)")
        }
    }
}

// MARK: - Enhanced Department Budget Card
struct EnhancedDepartmentBudgetCard: View {
    let budget: DepartmentBudget
    let isSelected: Bool
    @ObservedObject var viewModel: ProjectDetailViewModel
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Department name with detail indicator
            HStack {
                Text(budget.department)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.7)
            }
            
            // Budget information
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                // Total budget (only show if there's an allocated budget)
                if budget.totalBudget > 0 {
                    HStack {
                        Text("Budget:")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Double(budget.totalBudget).formattedCurrency)")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                // Spent amount (Approved expenses)
                HStack {
                    Text("Approved:")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("₹\(Int(viewModel.approvedAmount(for: budget.department)))")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(budget.approvedBudget > budget.totalBudget ? .red : .primary)
                    
                }
                
                // Remaining amount (only show if there's an allocated budget)
                if budget.totalBudget > 0 {
                    HStack {
                        Text("Remaining:")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("₹\(Int(viewModel.remainingBudget(for: budget.department, allocatedBudget: budget.totalBudget)))")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(budget.totalBudget - budget.approvedBudget < 0 ? .red : .green)
                    }
                }
                //                else {
                //                    // For "Other Expenses" department, show a note
                //                    HStack {
                //                        Text("Unallocated Expenses")
                //                            .font(DesignSystem.Typography.caption1)
                //                            .foregroundColor(.secondary)
                //
                //                        Spacer()
                //
                //                        Text("No Budget")
                //                            .font(DesignSystem.Typography.subheadline)
                //                            .fontWeight(.semibold)
                //                            .foregroundColor(.orange)
                //                    }
                //                }
            }
            
            // Progress bar (only show if there's an allocated budget)
            if budget.totalBudget > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(budget.color)
                            .frame(width: min(CGFloat(budget.approvedBudget / budget.totalBudget) * geometry.size.width, geometry.size.width), height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.top, 4)
            } else {
                // For "Other Expenses" department, show a different indicator
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        // Full bar for unallocated expenses
                        RoundedRectangle(cornerRadius: 4)
                            .fill(budget.color.opacity(0.6))
                            .frame(width: geometry.size.width, height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func iconForDepartment(_ department: String) -> String {
        switch department.lowercased() {
        case let dept where dept.contains("cast"):
            return "person.2.fill"
        case let dept where dept.contains("location"):
            return "location.fill"
        case let dept where dept.contains("equipment"):
            return "camera.fill"
        case let dept where dept.contains("production"):
            return "film.fill"
        case let dept where dept.contains("marketing"):
            return "megaphone.fill"
        case let dept where dept.contains("design"):
            return "paintbrush.fill"
        case let dept where dept.contains("research"):
            return "magnifyingglass"
        case let dept where dept.contains("website"), let dept where dept.contains("development"):
            return "globe"
        default:
            return "folder.fill"
        }
    }
}

// MARK: - Phase Department Pill
private struct DepartmentPill: View {
    let title: String
    let amount: Double
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(title)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(color)
                    .lineLimit(1)
                Text("\(Int(amount).formattedCurrency)")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// "Other" department card for anonymous expenses
private struct OtherDepartmentCard: View {
    let spent: Double
    let onTap: (() -> Void)?
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Title row
            HStack {
                Text("Other")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Budget/Spent/Remaining rows
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Budget:")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("NA")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Approved:")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(spent).formattedCurrency)")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                HStack {
                    Text("Remaining:")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("NA")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                // Progress bar - show full bar for anonymous expenses
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: geometry.size.width, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(width: 240, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }

    var body: some View {
        if let onTap = onTap {
            Button(action: onTap) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }
}

// Small card used in horizontal scrollers for departments
private struct DepartmentMiniCard: View {
    let title: String
    let amount: Double
    let spent: Double
    let onTap: (() -> Void)?

    private var budget: Double { amount }
    private var remaining: Double { max(budget - spent, 0) }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Title row
            HStack {
                TruncatedTextWithTooltip(
                    title,
                    font: DesignSystem.Typography.headline,
                    foregroundColor: .primary,
                    lineLimit: 1
                )
                Spacer()
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Budget/Spent/Remaining rows
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Budget:")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(budget).formattedCurrency)")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Approved:")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(spent).formattedCurrency)")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                HStack {
                    Text("Remaining:")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(remaining).formattedCurrency)")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(remaining >= 0 ? .green : .red)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor)
                            .frame(width: budget > 0 ? min(CGFloat(spent / budget) * geometry.size.width, geometry.size.width) : 0, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(width: 240, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }

    var body: some View {
        if let onTap = onTap {
            Button(action: onTap) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }
}

// MARK: - All Phases View
private struct AllPhasesView: View {
    let phases: [DashboardView.PhaseSummary]
    let project: Project?
    let role: UserRole?
    let phoneNumber: String
    let onPhaseAdded: (() -> Void)?
    @ObservedObject var stateManager: DashboardStateManager
    
    @State private var showingDepartmentDetail = false
    @State private var selectedDepartment: DepartmentSelection? = nil
    @State private var selectedPhaseId: String? = nil
    @State private var showingAddDepartment = false
    @State private var phaseForDepartmentAdd: DashboardView.PhaseSummary? = nil
    @State private var phaseEnabledMap: [String: Bool] = [:]
    @State private var phaseBudgetMap: [String: DashboardView.PhaseBudget] = [:]
    @State private var phaseExtensionMap: [String: Bool] = [:] // Track if phase has accepted extension
    @State private var phaseAnonymousExpensesMap: [String: Double] = [:] // Track anonymous expenses per phase
    @State private var phaseDepartmentSpentMap: [String: [String: Double]] = [:] // Track spent per department per phase [phaseId: [department: spent]]
    @State private var showingAddPhase = false
    @State private var showingEditPhase = false
    @State private var phaseToEdit: DashboardView.PhaseSummary? = nil
    @State private var showingCompletePhaseConfirmation = false
    @State private var phaseToComplete: DashboardView.PhaseSummary? = nil
    @State private var showingStartNowConfirmation = false
    @State private var phaseToStart: DashboardView.PhaseSummary? = nil
    
    private var phaseDateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }
    
    private var now: Date { Date() }
    
    private func isPhaseInFuture(_ phase: DashboardView.PhaseSummary) -> Bool {
        let current = now
        if let startDate = phase.start {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: current)
            let phaseStart = calendar.startOfDay(for: startDate)
            return phaseStart > today
        }
        return false
    }
    
    private func isPhaseCompleted(_ phase: DashboardView.PhaseSummary) -> Bool {
        let current = now
        if let endDate = phase.end {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: current)
            let phaseEnd = calendar.startOfDay(for: endDate)
            return today > phaseEnd
        }
        return false
    }
    
    private func isPhaseInProgress(_ phase: DashboardView.PhaseSummary) -> Bool {
        let current = now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: current)
        
        switch (phase.start, phase.end) {
        case (nil, nil):
            return true
        case (let s?, nil):
            // only startDate - compare at start of day level
            let phaseStart = calendar.startOfDay(for: s)
            return phaseStart <= today
        case (nil, let e?):
            // only endDate - compare at start of day level
            let phaseEnd = calendar.startOfDay(for: e)
            // Phase is in progress if today is on or before the end date
            return today <= phaseEnd
        case (let s?, let e?):
            // both are non-nil - compare at start of day level
            let phaseStart = calendar.startOfDay(for: s)
            let phaseEnd = calendar.startOfDay(for: e)
            // Phase is in progress if today is between start and end (inclusive)
            return phaseStart <= today && today <= phaseEnd
        }
    }
    
    private func phaseTimelineText(_ phase: DashboardView.PhaseSummary) -> String {
        switch (phase.start, phase.end) {
        case (nil, nil):
            return ""
        case (let s?, nil):
            return "Start: \(phaseDateFormatter.string(from: s))"
        case (nil, let e?):
            return "End: \(phaseDateFormatter.string(from: e))"
        case (let s?, let e?):
            return "\(phaseDateFormatter.string(from: s)) -\n\(phaseDateFormatter.string(from: e))"
        }
    }
    
    private func loadPhaseEnabledStates() {
        guard let projectId = project?.id else { return }
        // Get customerId from parent view or environment
        // For now, we'll need to pass it or get it from authService
        // Since this is inside AllPhasesView, we need to get customerId from parent
        Task {
            do {
                // Try to get customerId from Firebase Auth
                guard let customerId = Auth.auth().currentUser?.uid else {
                    print("❌ Customer ID not found in loadPhaseEnabledStates")
                    return
                }
                
                let snapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                var enabledMap: [String: Bool] = [:]
                for doc in snapshot.documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        enabledMap[doc.documentID] = phase.isEnabledValue
                    }
                }
                
                await MainActor.run {
                    phaseEnabledMap = enabledMap
                }
            } catch {
                // Error loading phase enabled states
            }
        }
    }
    
    private func loadPhaseBudgets() {
        guard let projectId = project?.id else { return }
        Task {
            do {
                // Get customerId from Firebase Auth
                guard let customerId = Auth.auth().currentUser?.uid else {
                    print("❌ Customer ID not found in AllPhasesView.loadPhaseBudgets")
                    return
                }
                
                // Load all approved expenses for this project
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                // Calculate spent amount per phase
                var phaseSpentMap: [String: Double] = [:]
                for expenseDoc in expensesSnapshot.documents {
                    if let expense = try? expenseDoc.data(as: Expense.self),
                       let phaseId = expense.phaseId {
                        phaseSpentMap[phaseId, default: 0] += expense.amount
                    }
                }
                
                // Calculate total budget and create PhaseBudget for each phase
                var budgetMap: [String: DashboardView.PhaseBudget] = [:]
                for phase in phases {
                    let totalBudget = phase.departments.values.reduce(0, +)
                    let spent = phaseSpentMap[phase.id] ?? 0
                    budgetMap[phase.id] = DashboardView.PhaseBudget(
                        id: phase.id,
                        totalBudget: totalBudget,
                        spent: spent
                    )
                }
                
                await MainActor.run {
                    phaseBudgetMap = budgetMap
                }
            } catch {
                // Error loading phase budgets
            }
        }
    }
    
    private func loadPhaseDepartmentSpent() {
        guard let projectId = project?.id else { return }
        Task {
            do {
                // Get customerId from Firebase Auth
                guard let customerId = Auth.auth().currentUser?.uid else {
                    print("❌ Customer ID not found in AllPhasesView.loadPhaseDepartmentSpent")
                    return
                }
                
                // Load all approved expenses for this project (excluding anonymous)
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                // Calculate spent amount per department per phase
                // Structure: [phaseId: [department: spent]]
                var departmentSpentMap: [String: [String: Double]] = [:]
                
                for expenseDoc in expensesSnapshot.documents {
                    if let expense = try? expenseDoc.data(as: Expense.self),
                       let phaseId = expense.phaseId,
                       expense.isAnonymous != true { // Exclude anonymous expenses
                        if departmentSpentMap[phaseId] == nil {
                            departmentSpentMap[phaseId] = [:]
                        }
                        // Expenses use just department name, but we need to match to phaseId_departmentName keys
                        // Try both formats: phaseId_departmentName (new) and just departmentName (old/expense format)
                        let departmentKey = String.departmentKey(phaseId: phaseId, departmentName: expense.department)
                        // Store using the new format key, but also support old format for backward compatibility
                        departmentSpentMap[phaseId]?[departmentKey, default: 0] += expense.amount
                        // Also store with old format for backward compatibility
                        departmentSpentMap[phaseId]?[expense.department, default: 0] += expense.amount
                    }
                }
                
                await MainActor.run {
                    phaseDepartmentSpentMap = departmentSpentMap
                }
            } catch {
                // Error loading phase department spent
            }
        }
    }
    
    private func loadPhaseExtensions() {
        guard let projectId = project?.id else { return }
        Task {
            do {
                // Get customerId from Firebase Auth
                guard let customerId = Auth.auth().currentUser?.uid else {
                    print("❌ Customer ID not found in AllPhasesView.loadPhaseExtensions")
                    return
                }
                
                var extensionMap: [String: Bool] = [:]
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                
                // Check each phase for accepted extension requests
                for phase in phases {
                    // Get phase end date
                    guard let phaseEndDate = phase.end else { continue }
                    
                    // Format phase end date for comparison
                    let phaseEndDateStr = dateFormatter.string(from: phaseEndDate)
                    
                    // Query requests collection for accepted requests
                    let requestsSnapshot = try await FirebasePathHelper.shared
                        .phasesCollection(customerId: customerId, projectId: projectId)
                        .document(phase.id)
                        .collection("requests")
                        .whereField("status", isEqualTo: "ACCEPTED")
                        .getDocuments()
                    
                    // Check if any accepted request's extendedDate matches phase endDate
                    var hasExtension = false
                    for requestDoc in requestsSnapshot.documents {
                        let requestData = requestDoc.data()
                        if let extendedDate = requestData["extendedDate"] as? String {
                            // Compare extendedDate with phase endDate
                            if extendedDate == phaseEndDateStr {
                                hasExtension = true
                                break
                            }
                        }
                    }
                    
                    extensionMap[phase.id] = hasExtension
                }
                
                await MainActor.run {
                    phaseExtensionMap = extensionMap
                }
            } catch {
                // Error loading phase extensions
            }
        }
    }
    
    private func loadPhaseAnonymousExpenses() {
        guard let projectId = project?.id else { return }
        Task {
            do {
                // Get customerId from Firebase Auth
                guard let customerId = Auth.auth().currentUser?.uid else {
                    print("❌ Customer ID not found in AllPhasesView.loadPhaseAnonymousExpenses")
                    return
                }
                
                // Load all anonymous expenses for this project
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("isAnonymous", isEqualTo: true)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                // Calculate anonymous expenses per phase
                var anonymousMap: [String: Double] = [:]
                for expenseDoc in expensesSnapshot.documents {
                    if let expense = try? expenseDoc.data(as: Expense.self),
                       let phaseId = expense.phaseId {
                        anonymousMap[phaseId, default: 0] += expense.amount
                    }
                }
                
                await MainActor.run {
                    phaseAnonymousExpensesMap = anonymousMap
                }
            } catch {
                // Error loading phase anonymous expenses
            }
        }
    }
    
    // MARK: - Start Phase Now in AllPhasesView
    private func startPhaseNowInAllPhasesView(phase: DashboardView.PhaseSummary, projectId: String, customerId: String) async {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            // Format today's date as start date
            let today = Date()
            let startDateStr = dateFormatter.string(from: today)
            
            // Update phase start date to today
            try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
                .updateData([
                    "startDate": startDateStr,
                    "updatedAt": Timestamp()
                ])
            
            // If project status is LOCKED, also update project planned start date
            if let project = project, project.statusType == .LOCKED {
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData([
                        "plannedDate": startDateStr,
                        "updatedAt": Timestamp()
                    ])
                
                // Post notification to refresh project
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            }
            
            // Log timeline change to Firebase changes collection
            guard let currentUserUID = Auth.auth().currentUser?.uid else {
                print("⚠️ Warning: No current user UID found, skipping change log")
                return
            }
            
            let changeLog = PhaseTimelineChange(
                phaseId: phase.id,
                projectId: projectId,
                previousStartDate: phase.start.map { dateFormatter.string(from: $0) },
                previousEndDate: phase.end.map { dateFormatter.string(from: $0) },
                newStartDate: startDateStr,
                newEndDate: phase.end.map { dateFormatter.string(from: $0) },
                changedBy: currentUserUID,
                requestID: nil // Manual change via "Start Now" button
            )
            
            let phaseRef = FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
            
            let changesRef = phaseRef.collection("changes").document()
            try await changesRef.setData(from: changeLog)
            
            print("✅ Logged phase start change (AllPhasesView): phaseId=\(phase.id), changedBy=\(currentUserUID), newStartDate=\(startDateStr)")
            
            // Reload phases
            loadPhaseEnabledStates()
            loadPhaseBudgets()
            loadPhaseDepartmentSpent()
            loadPhaseExtensions()
            loadPhaseAnonymousExpenses()
            
            // Post notification to refresh
            NotificationCenter.default.post(name: NSNotification.Name("PhaseUpdated"), object: nil)
            
            // Call parent callback to reload phases
            onPhaseAdded?()
            
            // Provide haptic feedback
            await MainActor.run {
                HapticManager.notification(.success)
            }
        } catch {
            print("Error starting phase: \(error.localizedDescription)")
            await MainActor.run {
                HapticManager.notification(.error)
            }
        }
    }
    
    // MARK: - Complete Phase in AllPhasesView
    private func completePhaseInAllPhasesView(phase: DashboardView.PhaseSummary, projectId: String, customerId: String) async {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            // Format today's date as end date
            let today = Date()
            let endDateStr = dateFormatter.string(from: today)
            
            // Update phase end date to today
            try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
                .updateData([
                    "endDate": endDateStr,
                    "updatedAt": Timestamp()
                ])
            
            // Log timeline change to Firebase changes collection
            guard let currentUserUID = Auth.auth().currentUser?.uid else {
                print("⚠️ Warning: No current user UID found, skipping change log")
                return
            }
            
            let changeLog = PhaseTimelineChange(
                phaseId: phase.id,
                projectId: projectId,
                previousStartDate: phase.start.map { dateFormatter.string(from: $0) },
                previousEndDate: phase.end.map { dateFormatter.string(from: $0) },
                newStartDate: phase.start.map { dateFormatter.string(from: $0) },
                newEndDate: endDateStr,
                changedBy: currentUserUID,
                requestID: nil // Manual change via "Complete Phase" button
            )
            
            let phaseRef = FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
            
            let changesRef = phaseRef.collection("changes").document()
            try await changesRef.setData(from: changeLog)
            
            print("✅ Logged phase completion change (AllPhasesView): phaseId=\(phase.id), changedBy=\(currentUserUID), newEndDate=\(endDateStr)")
            
            // Reload phases
            loadPhaseEnabledStates()
            loadPhaseBudgets()
            loadPhaseDepartmentSpent()
            loadPhaseExtensions()
            loadPhaseAnonymousExpenses()
            
            // Post notification to refresh
            NotificationCenter.default.post(name: NSNotification.Name("PhaseUpdated"), object: nil)
            
            // Call parent callback to reload phases
            onPhaseAdded?()
            
            // Provide haptic feedback
            await MainActor.run {
                HapticManager.notification(.success)
            }
        } catch {
            print("Error completing phase: \(error.localizedDescription)")
            await MainActor.run {
                HapticManager.notification(.error)
            }
        }
    }
    
    // MARK: - Phase Row View
    private func phaseRowView(phase: DashboardView.PhaseSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Phase Header with date, In Progress badge, and + icon
            phaseHeaderView(phase: phase)
            
            // Phase Budget Summary
            if let phaseBudget = phaseBudgetMap[phase.id] {
                phaseBudgetSummaryView(phaseBudget: phaseBudget)
            }
            
            // Departments scroller
            phaseDepartmentsScroller(phase: phase)
        }
    }
    
    // MARK: - Phase Header View
    private func phaseHeaderView(phase: DashboardView.PhaseSummary) -> some View {
        VStack{
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.small) {
                HStack(spacing: 8) {
                    VStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                TruncatedTextWithTooltip(
                                    phase.name,
                                    font: DesignSystem.Typography.headline,
                                    foregroundColor: .primary,
                                    lineLimit: 1
                                )

                                if phaseTimelineText(phase) != "" {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .accessibilityHidden(true)
                                        
                                        Text(phaseTimelineText(phase))
                                            .font(DesignSystem.Typography.caption1)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)   // 👈 allows line breaks
                                            .lineLimit(nil)                     // 👈 no limit on number of lines
                                            .fixedSize(horizontal: false, vertical: true) // 👈 prevent truncation
                                    }

                                }
                            }
                            
                            // Hide Edit Phase button when project is archived
                            if role == .ADMIN && project?.statusType != .ARCHIVE {
                                Button {
                                    HapticManager.selection()
                                    phaseToEdit = phase
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.accentColor)
                                        .accessibilityLabel("Edit phase")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Spacer()
                
                phaseBadgesAndControls(phase: phase)
            }
            if let phaseBudget = phaseBudgetMap[phase.id] {
                phaseTotalBudgetView(phaseBudget: phaseBudget)
            }
        }
    }
    
    // MARK: - Phase Total Budget View
    private func phaseTotalBudgetView(phaseBudget: DashboardView.PhaseBudget) -> some View {
        HStack {
            Text("Total")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.15))
                .foregroundColor(.purple)
                .cornerRadius(8)

            Spacer(minLength: 8)

            Text(Int(phaseBudget.totalBudget).formattedCurrency)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.purple)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Phase Badges and Controls
    private func phaseBadgesAndControls(phase: DashboardView.PhaseSummary) -> some View {
        HStack {
            VStack(spacing: 4) {
                // Show "Completed" badge if phase is completed
                if isPhaseCompleted(phase) {
                    Text("Completed")
                        .font(DesignSystem.Typography.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityLabel("Phase status: Completed")
                }
                // Show "In Progress" badge if phase is in progress AND enabled
                else if isPhaseInProgress(phase) && (phaseEnabledMap[phase.id] ?? true) {
                    Text("Active")
                        .font(DesignSystem.Typography.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityLabel("Phase status: In Progress")
                }
                // Show "Planned" badge if phase is in the future
                else if isPhaseInFuture(phase) {
                    Text("Planned")
                        .font(DesignSystem.Typography.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityLabel("Phase status: Planned")
                }
                
                // Extension Badge - Show if phase has accepted extension
                if phaseExtensionMap[phase.id] == true {
                    HStack(spacing: 4) {
                        Text("Extended")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .scaleEffect(0.8)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                    .accessibilityLabel("Phase extended via accepted request")
                }
            }
            Spacer()
            
            VStack{
                
                HStack{
                    Spacer()
            // 3-dot menu for Complete Phase (available for all roles, only for active phases, hidden when archived)
            if isPhaseInProgress(phase) && (phaseEnabledMap[phase.id] ?? true) && project?.statusType != .ARCHIVE {
                Menu {
                    Button(role: .destructive) {
                        HapticManager.selection()
                        phaseToComplete = phase
                        showingCompletePhaseConfirmation = true
                    } label: {
                        Label("Complete Phase", systemImage: "checkmark.circle.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, role == .ADMIN ? 4 : 0)
                .padding(.vertical, 2)
            }
            
            // 3-dot menu for Start Now (for future phases, available for all roles, hidden when archived)
            if isPhaseInFuture(phase) && project?.statusType != .ARCHIVE {
                Menu {
                    Button {
                        HapticManager.selection()
                        phaseToStart = phase
                        showingStartNowConfirmation = true
                    } label: {
                        Label("Start Now", systemImage: "play.circle.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, role == .ADMIN ? 4 : 0)
                .padding(.vertical, 2)
            }
                }
                
                if role == .ADMIN && !isPhaseCompleted(phase) {
                    HStack{
                    // Enable toggle (not shown for completed phases or archived projects)
                    if project?.statusType != .ARCHIVE {
                        Toggle("", isOn: Binding(
                            get: { phaseEnabledMap[phase.id] ?? false },
                            set: { newValue in
                                phaseEnabledMap[phase.id] = newValue
                                if let projectId = project?.id,
                                   let customerId = Auth.auth().currentUser?.uid {
                                    FirebasePathHelper.shared
                                        .phasesCollection(customerId: customerId, projectId: projectId)
                                        .document(phase.id)
                                        .updateData([
                                            "isEnabled": newValue,
                                            "updatedAt": Timestamp()
                                        ])
                                }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        .scaleEffect(0.85)
                    }
                    Spacer()
                    // Hide Add Department button when project is archived
                    if project?.statusType != .ARCHIVE {
                        Button {
                            HapticManager.selection()
                            phaseForDepartmentAdd = phase
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.accentColor)
                                .accessibilityLabel("Add department to this phase")
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 6)
                        .padding(.vertical, 2)
                    }
                }
            }
            }
        }
    }
    
    // MARK: - Phase Budget Summary View
    private func phaseBudgetSummaryView(phaseBudget: DashboardView.PhaseBudget) -> some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Approved Amount
            VStack(alignment: .center, spacing: 4) {
                Text("Approved")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
                Text(Int(phaseBudget.spent).formattedCurrency)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Remaining Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text("Remaining")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
                Text(Int(phaseBudget.remaining).formattedCurrency)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(phaseBudget.remaining >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color(.tertiarySystemFill).opacity(0.5))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
    
    // MARK: - Phase Departments Scroller
    private func phaseDepartmentsScroller(phase: DashboardView.PhaseSummary) -> some View {
        ZStack(alignment: .leading) {
            // Card background for the horizontal scroller
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray5), lineWidth: 0.5)
                )
            // Horizontal scroller
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    ForEach(phase.departments.sorted(by: { $0.key < $1.key }), id: \.key) { deptKey, amount in
                        // Strip phaseId_ prefix for display
                        let displayName = deptKey.displayDepartmentName()
                        DepartmentMiniCard(
                            title: displayName,
                            amount: amount,
                            spent: phaseDepartmentSpentMap[phase.id]?[deptKey] ?? 0,
                            onTap: {
                                // Use the display name (without phaseId prefix) for selection
                                selectedDepartment = DepartmentSelection(name: displayName, phaseId: phase.id)
                                // Small delay to ensure state is set before showing sheet
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showingDepartmentDetail = true
                                }
                            }
                        )
                    }
                    
                    // Add "Other" department card for anonymous expenses
                    if let anonymousSpent = phaseAnonymousExpensesMap[phase.id], anonymousSpent > 0 {
                        OtherDepartmentCard(
                            spent: anonymousSpent,
                            onTap: {
                                selectedDepartment = DepartmentSelection(name: "Other", phaseId: phase.id)
                                showingDepartmentDetail = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.visible)
            .scrollIndicatorsFlash(onAppear: false)
            // Scroll hint (left chevron) to indicate horizontal scroll
            HStack { 
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(.leading, 6)
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }
    
    var body: some View {
        List {
            ForEach(phases) { phase in
                Section {
                    phaseRowView(phase: phase)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .listSectionSpacing(.custom(8))
        .navigationTitle("All Phases")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if role == .ADMIN && project?.statusType != .ARCHIVE {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.selection()
                        showingAddPhase = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .onAppear {
            loadPhaseEnabledStates()
            loadPhaseBudgets()
            loadPhaseDepartmentSpent()
            loadPhaseExtensions()
            loadPhaseAnonymousExpenses()
        }
//        .sheet(item: $selectedDepartment) { department in
//            if let project = project,
//               let projectId = project.id,
//               !projectId.isEmpty {
//                DepartmentBudgetDetailView(
//                    department: department,
//                    projectId: projectId,
//                    role: role,
//                    phoneNumber: phoneNumber
//                )
//                .presentationDetents([.large])
//            }
//        }
        .sheet(isPresented: $showingAddPhase) {
            if let projectId = project?.id {
                AddPhaseSheet(
                    projectId: projectId,
                    existingPhaseCount: phases.count,
                    onSaved: {
                        // Call parent callback to reload phases
                        onPhaseAdded?()
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .sheet(item: $selectedDepartment) { selection in
            if let project = project,
               let projectId = project.id,
               !projectId.isEmpty {
                DepartmentBudgetDetailView(
                    department: selection.name,
                    projectId: projectId,
                    role: role,
                    phoneNumber: phoneNumber,
                    phaseId: selection.phaseId,
                    projectStatus: project.statusType,
                    stateManager: stateManager
                )
                .presentationDetents([.large])
            }
        }
        .sheet(item: $phaseForDepartmentAdd) { phase in
            if let projectId = project?.id {
                AddDepartmentSheet(
                    projectId: projectId,
                    phaseId: phase.id,
                    phaseName: phase.name,
                    onSaved: {
                        HapticManager.impact(.light)
                        // Optional: reload budgets when department is added
                        loadPhaseBudgets()
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .sheet(item: $phaseToEdit) { phase in
            EditPhaseSheet(
                projectId: project?.id ?? "",
                phaseId: phase.id,
                currentPhaseName: phase.name,
                currentStartDate: phase.start,
                currentEndDate: phase.end,
                onSaved: { onPhaseAdded?() }
            )
            .presentationDetents([.medium])
        }
        .alert("Complete Phase", isPresented: $showingCompletePhaseConfirmation) {
            Button("Cancel", role: .cancel) {
                phaseToComplete = nil
            }
            Button("Confirm", role: .destructive) {
                if let phase = phaseToComplete,
                   let projectId = project?.id,
                   let customerId = Auth.auth().currentUser?.uid {
                    Task {
                        await completePhaseInAllPhasesView(phase: phase, projectId: projectId, customerId: customerId)
                    }
                }
                phaseToComplete = nil
            }
        } message: {
            if let phase = phaseToComplete {
                Text("From tomorrow, this stage will be closed. Users cannot add any expense to this phase. The phase end date will be set to today (\(phaseDateFormatter.string(from: Date()))).")
            }
        }
        .alert("Start Phase Now", isPresented: $showingStartNowConfirmation) {
            Button("Cancel", role: .cancel) {
                phaseToStart = nil
            }
            Button("Confirm") {
                if let phase = phaseToStart,
                   let projectId = project?.id,
                   let customerId = Auth.auth().currentUser?.uid {
                    Task {
                        await startPhaseNowInAllPhasesView(phase: phase, projectId: projectId, customerId: customerId)
                    }
                }
                phaseToStart = nil
            }
        } message: {
            if let phase = phaseToStart {
                let message: String
                if project?.statusType == .LOCKED {
                    message = "The phase start date will be set to today (\(phaseDateFormatter.string(from: Date()))). The project planned start date will also be updated to today since the project is locked."
                } else {
                    message = "The phase start date will be set to today (\(phaseDateFormatter.string(from: Date())))."
                }
                return Text(message)
            }
            return Text("")
        }
//        .sheet(isPresented: $showingDepartmentDetail) {
//            if let department = selectedDepartment, let project = project, let projectId = project.id, !projectId.isEmpty {
//                DepartmentBudgetDetailView(
//                    department: department,
//                    projectId: projectId,
//                    role: role,
//                    phoneNumber: phoneNumber,
//                    phaseId: selectedPhaseId
//                )
//                .presentationDetents([.large])
//            }
//        }
    }
}

// MARK: - Project Stats Card
struct ProjectStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(color)
                    .symbolRenderingMode(.hierarchical)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle(shadow: DesignSystem.Shadow.small)
    }
}

// MARK: - Suspended Project Stats Card
struct SuspendedProjectStatsCard: View {
    let suspendedDate: String?
    let suspensionReason: String?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }
    
    private var displayDate: String? {
        guard let suspendedDate = suspendedDate else { return nil }
        // If it's already in the correct format, return as is
        if let _ = dateFormatter.date(from: suspendedDate) {
            return suspendedDate
        }
        // Otherwise try to parse and format
        return suspendedDate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: Icon and Status
            HStack(spacing: 6) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .symbolRenderingMode(.hierarchical)
                
                Spacer()
                
                // Status badge
                Text("SUSPENDED")
                    .font(.system(size: 10))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(4)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text("Project Status")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                
                // Suspended date
                if let date = displayDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("Since: \(date)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Suspension reason - using TruncatedSuspensionReasonView for better handling
                if let reason = suspensionReason, !reason.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                            .padding(.top, 1)
                        
                        TruncatedSuspensionReasonView(reason: reason)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle(shadow: DesignSystem.Shadow.small)
    }
}

// MARK: - Temp Approver Stats Card
struct TempApproverStatsCard: View {
    let approverName: String
    let phoneNumber: String
    let status: TempApproverStatus?
    let endDate: Date?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
    
    private var statusColor: Color {
        switch status {
        case .accepted, .active:
            return .green
        case .pending:
            return .orange
        case .rejected:
            return .red
        case .expired:
            return .gray
        default:
            return .orange
        }
    }
    
    private var statusText: String {
        switch status {
        case .accepted:
            return "Accepted"
        case .pending:
            return "Pending"
        case .rejected:
            return "Rejected"
        case .active:
            return "Active"
        case .expired:
            return "Expired"
        default:
            return "Pending"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: Icon and Status
            HStack(spacing: 6) {
                Image(systemName: "person.badge.clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(statusColor)
                    .symbolRenderingMode(.hierarchical)
                
                Spacer()
                
                // Status badge
                Text(statusText)
                    .font(.system(size: 10))
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(4)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text("Temp Approver")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(approverName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(phoneNumber)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let endDate = endDate, status == .accepted || status == .active {
                    Text("Until: \(endDate, formatter: dateFormatter)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle(shadow: DesignSystem.Shadow.small)
    }
    
    // MARK: - Action Button Helper
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
            HapticManager.selection()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(color.gradient)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
        }
        .frame(width: 180)
    }
}

// MARK: - Action Menu Button
struct ActionMenuButton: View {
    let icon: String
    let title: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isDisabled ? Color.gray.gradient : color.gradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: (isDisabled ? Color.gray : color).opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.hierarchical)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDisabled ? .secondary : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .frame(width: 200)
    }
}

// MARK: - Total Budget Card
struct TotalBudgetCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var stateManager: DashboardStateManager
    
    // Use state manager values for immediate updates, fallback to viewModel
    private var totalBudget: Double {
        stateManager.totalProjectBudget > 0 ? stateManager.totalProjectBudget : viewModel.departmentBudgets.reduce(0) { $0 + $1.totalBudget }
    }
    
    private var remainingBudget: Double {
        let totalSpent = stateManager.totalProjectSpent > 0 ? stateManager.totalProjectSpent : viewModel.totalApprovedExpenses
        return totalBudget - totalSpent
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                
                Text("Total Budget")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                
                Text(totalBudget.formattedCurrency)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: false)
                
                
                // Remaining amount
                Text("Remaining: \(remainingBudget.formattedCurrency)")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(remainingBudget >= 0 ? .green : .red)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: false)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle(shadow: DesignSystem.Shadow.small)
    }
}

// MARK: - Project Dates Card
struct ProjectDatesCard: View {
    let project: Project
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }
    
    private var displayDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }
    
    private var plannedDate: Date? {
        guard let plannedDateStr = project.plannedDate else { return nil }
        return dateFormatter.date(from: plannedDateStr)
    }
    
    private var handoverDate: Date? {
        guard let handoverDateStr = project.handoverDate else { return nil }
        return dateFormatter.date(from: handoverDateStr)
    }
    
    private var initialHandOverDate: Date? {
        guard let initialHandOverDateStr = project.initialHandOverDate else { return nil }
        return dateFormatter.date(from: initialHandOverDateStr)
    }
    
    private var maintenanceDate: Date? {
        guard let maintenanceDateStr = project.maintenanceDate else { return nil }
        return dateFormatter.date(from: maintenanceDateStr)
    }
    
    private var daysExtended: Int? {
        guard let handover = handoverDate,
              let initial = initialHandOverDate else { return nil }
        let calendar = Calendar.current
        let handoverStart = calendar.startOfDay(for: handover)
        let initialStart = calendar.startOfDay(for: initial)
        let days = calendar.dateComponents([.day], from: initialStart, to: handoverStart).day
        return days != nil && days! > 0 ? days : nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Planned Date
            if let planned = plannedDate {
                DateRow(
                    label: "Planned",
                    date: planned,
                    icon: "calendar.badge.clock",
                    iconColor: .blue
                )
            }
            
            // Handover Date with extension indicator inline
            if let handover = handoverDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .frame(width: 14)
                    
                    Text("Handover")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    // Days Extended Badge - inline
                    if let days = daysExtended {
                        Text("\(days) days extended")
                            .font(DesignSystem.Typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    Text(displayDateFormatter.string(from: handover))
                        .font(DesignSystem.Typography.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                }
            }
            
            // Maintenance Date
            if let maintenance = maintenanceDate {
                DateRow(
                    label: "Maintenance",
                    date: maintenance,
                    icon: "wrench.and.screwdriver.fill",
                    iconColor: .purple
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle(shadow: DesignSystem.Shadow.small)
    }
    
    private struct DateRow: View {
        let label: String
        let date: Date
        let icon: String
        let iconColor: Color
        
        private var displayDateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM yyyy"
            return formatter
        }
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(iconColor)
                    .frame(width: 14)
                
                Text(label)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(displayDateFormatter.string(from: date))
                    .font(DesignSystem.Typography.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Anonymous Expenses Detail View
struct AnonymousExpensesDetailView: View {
    let project: Project
    @StateObject private var viewModel = AnonymousExpensesViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Anonymous Expenses")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Expenses from deleted departments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignSystem.Spacing.large)
                .padding(.top, DesignSystem.Spacing.large)
                
                // Content
                if viewModel.anonymousExpenses.isEmpty {
                    // Empty state
                    VStack(spacing: DesignSystem.Spacing.medium) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("No Anonymous Expenses")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("All expenses are properly categorized")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // Expenses list
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.medium) {
                            ForEach(viewModel.anonymousExpenses, id: \.id) { expense in
                                AnonymousExpenseCard(expense: expense)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.vertical, DesignSystem.Spacing.large)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            viewModel.loadAnonymousExpenses(for: project)
        }
    }
}

// MARK: - Anonymous Expenses ViewModel
@MainActor
class AnonymousExpensesViewModel: ObservableObject {
    @Published var anonymousExpenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    func loadAnonymousExpenses(for project: Project) {
        guard let projectId = project.id else { return }
        
        isLoading = true
        
        Task {
            do {
                // Get customerId from Firebase Auth
                guard let customerId = Auth.auth().currentUser?.uid else {
                    await MainActor.run {
                        self.errorMessage = "Customer ID not found. Please log in again."
                        self.isLoading = false
                    }
                    return
                }
                
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("isAnonymous", isEqualTo: true)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                var expenses: [Expense] = []
                for expenseDoc in expensesSnapshot.documents {
                    if let expense = try? expenseDoc.data(as: Expense.self) {
                        expenses.append(expense)
                    }
                }
                
                await MainActor.run {
                    self.anonymousExpenses = expenses
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load anonymous expenses: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Anonymous Expense Card
struct AnonymousExpenseCard: View {
    let expense: Expense
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Header with original department
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.originalDepartment ?? "Unknown Department")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Originally: \(expense.originalDepartment ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(expense.amountFormatted)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // Department deletion info
            if let deletedAt = expense.departmentDeletedAt {
                HStack {
                    Image(systemName: "calendar.badge.minus")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Department deleted on: \(deletedAt.dateValue(), formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Expense details
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Text(expense.categoriesString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(expense.modeOfPayment.rawValue)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - Add Phase Sheet
private struct AddPhaseSheet: View {
    let projectId: String
    let existingPhaseCount: Int
    let onSaved: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var phaseName: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(86400 * 30)
    @State private var departments: [AddPhaseDepartmentItem] = [AddPhaseDepartmentItem()]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var nextPhaseNumber: Int = 1
    @State private var existingPhaseNames: [String] = []
    @State private var phaseNameError: String?
    @FocusState private var focusedField: Field?
    
    // Date confirmation alert states
    @State private var showDateConfirmation = false
    @State private var dateConfirmationType: DateConfirmationType = .handoverAndMaintenance
    @State private var pendingEndDate: Date?
    
    private enum Field { case phaseName, departmentName, departmentBudget }
    
    private enum DateConfirmationType {
        case handoverAndMaintenance
        case handoverOnly
    }
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }
    
    // MARK: - Indian Number Formatting Helpers
    
    // Helper to remove formatting (commas, spaces, etc.)
    private func removeFormatting(from value: String) -> String {
        return value.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    // Format number according to Indian numbering system (lakhs, crores)
    // Indian numbering: from RIGHT, first 3 digits, then groups of 2
    // Examples: 1,000; 10,000; 1,00,000 (lakh); 10,00,000; 1,00,00,000 (crore)
    private func formatIndianNumber(_ number: Double) -> String {
        // Handle decimal part
        let integerPart = Int(number)
        let decimalPart = number - Double(integerPart)
        
        // Convert integer to string
        let integerString = String(integerPart)
        let digits = Array(integerString)
        let count = digits.count
        
        // For numbers < 1000, no formatting needed
        if count < 4 {
            var result = integerString
            // Add decimal part if exists
            if decimalPart > 0.0001 {
                let decimalString = String(format: "%.2f", decimalPart)
                if let dotIndex = decimalString.firstIndex(of: ".") {
                    let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                    result += "." + afterDot
                }
            }
            return result
        }
        
        // Process from RIGHT to LEFT
        // Indian numbering: last 3 digits, then groups of 2, then remaining
        // Examples: 1,000; 10,000; 1,00,000; 10,00,000; 1,00,00,000
        var groups: [String] = []
        var remainingDigits = digits
        
        // Step 1: Take last 3 digits from right (ones, tens, hundreds)
        if remainingDigits.count >= 3 {
            let lastThree = String(remainingDigits.suffix(3))
            groups.append(lastThree) // Add to end (will be last group)
            remainingDigits = Array(remainingDigits.dropLast(3))
        } else {
            // Less than 3 digits total, just add them
            groups.append(String(remainingDigits))
            remainingDigits = []
        }
        
        // Step 2: Take groups of 2 digits from right (thousands, ten thousands, lakhs, etc.)
        while remainingDigits.count >= 2 {
            let lastTwo = String(remainingDigits.suffix(2))
            groups.insert(lastTwo, at: 0) // Insert at beginning (will be before last 3)
            remainingDigits = Array(remainingDigits.dropLast(2))
        }
        
        // Step 3: If one digit remains, add it at the beginning
        if remainingDigits.count == 1 {
            groups.insert(String(remainingDigits[0]), at: 0)
        }
        
        // Join with commas (groups are already in correct order: left to right)
        let result = groups.joined(separator: ",")
        
        // Add decimal part if exists
        var finalResult = result
        if decimalPart > 0.0001 {
            let decimalString = String(format: "%.2f", decimalPart)
            if let dotIndex = decimalString.firstIndex(of: ".") {
                let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                finalResult += "." + afterDot
            }
        }
        
        return finalResult
    }
    
    // Method to format amount as user types
    func formatAmountInput(_ input: String) -> String {
        // Remove any existing formatting
        let cleaned = removeFormatting(from: input)
        
        // If empty, return empty
        guard !cleaned.isEmpty else { return "" }
        
        // Convert to number
        guard let number = Double(cleaned) else { return cleaned }
        
        // Format according to Indian numbering system
        return formatIndianNumber(number)
    }
    
    private var isFormValid: Bool {
        let trimmedName = phaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidDepartments = !departments.isEmpty &&
        departments.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let noDuplicateDepartments = !hasDuplicateDepartmentNames()
        
        return !trimmedName.isEmpty &&
        phaseNameError == nil &&
        endDate > startDate &&
        hasValidDepartments &&
        noDuplicateDepartments
    }
    
    // Check for duplicate department names within the same phase
    private func hasDuplicateDepartmentNames() -> Bool {
        let trimmedNames = departments.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Check for case-insensitive duplicates
        let lowercasedNames = trimmedNames.map { $0.lowercased() }
        let uniqueNames = Set(lowercasedNames)
        
        return lowercasedNames.count != uniqueNames.count
    }
    
    // Get duplicate department names for error display
    private func getDuplicateDepartmentNames() -> [String] {
        var nameCounts: [String: Int] = [:]
        var duplicates: [String] = []
        
        for dept in departments {
            let trimmedName = dept.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                let lowercased = trimmedName.lowercased()
                nameCounts[lowercased, default: 0] += 1
                if nameCounts[lowercased] == 2 {
                    // First time we see a duplicate
                    duplicates.append(trimmedName)
                }
            }
        }
        
        return duplicates
    }
    
    // Check if a specific department name is a duplicate
    private func isDepartmentNameDuplicate(_ name: String, excludingId: UUID? = nil) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return false
        }
        
        let lowercased = trimmedName.lowercased()
        let count = departments.filter { dept in
            if let excludingId = excludingId, dept.id == excludingId {
                return false
            }
            return dept.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lowercased
        }.count
        
        // If count > 0, there's at least one other department with the same name (excluding current)
        return count > 0
    }
    
    private func validatePhaseName() {
        let trimmedName = phaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            phaseNameError = "Phase name is required"
            return
        }
        
        // Check for duplicate phase names (case-insensitive)
        let isDuplicate = existingPhaseNames.contains { existingName in
            existingName.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
        
        if isDuplicate {
            phaseNameError = "\"\(trimmedName)\" already exists in this project. Enter a unique phase name."
        } else {
            phaseNameError = nil
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Enter phase name", text: $phaseName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .phaseName)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(phaseNameError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                        .onChange(of: phaseName) { _, _ in
                            validatePhaseName()
                        }
                    
                    if let error = phaseNameError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Phase Name")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    if endDate <= startDate {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("End date must be after start date")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Timeline")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    ForEach($departments) { $dept in
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Department")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    TextField("e.g., Marketing", text: $dept.name)
                                        .font(.body)
                                        .textFieldStyle(.plain)
                                        .focused($focusedField, equals: .departmentName)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(isDepartmentNameDuplicate(dept.name, excludingId: dept.id) ? Color.red : Color.clear, lineWidth: 1)
                                        )
                                        .onChange(of: dept.name) { _, _ in
                                            // Trigger validation check
                                        }
                                    
                                    if isDepartmentNameDuplicate(dept.name, excludingId: dept.id) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                            Text("\"\(dept.name.trimmingCharacters(in: .whitespacesAndNewlines))\" already exists in \"\(phaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "this phase" : phaseName.trimmingCharacters(in: .whitespacesAndNewlines))\". Enter a unique department name.")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("Budget")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    HStack(spacing: 4) {
                                        Text("₹")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                        TextField("0", text: Binding(
                                            get: { dept.amount },
                                            set: { newValue in
                                                // Format the input according to Indian numbering system
                                                dept.amount = formatAmountInput(newValue)
                                            }
                                        ))
                                            .keyboardType(.decimalPad)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .multilineTextAlignment(.trailing)
                                            .textFieldStyle(.plain)
                                            .frame(width: 80)
                                            .focused($focusedField, equals: .departmentBudget)
                                    }
                                    .onSubmit {
                                        if dept.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            dept.amount = "0"
                                        }
                                    }
                                }
                            }
                            
                            if dept.id != departments.last?.id {
                                Divider()
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button(action: {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            departments.append(AddPhaseDepartmentItem())
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("Add Department")
                                .font(.body)
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Departments")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } footer: {
                    if hasDuplicateDepartmentNames() {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            Text("Department names must be unique within this phase. Enter unique department names.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("At least one department with a name is required. Budget can be 0. Department names must be unique within this phase.")
                            .font(.caption)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Phase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePhase()
                    }
                    .disabled(!isFormValid || isSaving)
                    .fontWeight(.semibold)
                    .foregroundColor(isFormValid && !isSaving ? .blue : .gray)
                }
            }
            .onAppear {
                focusedField = .phaseName
                loadNextPhaseNumber()
                loadExistingPhaseNames()
            }
            .alert("Update Project Dates", isPresented: $showDateConfirmation) {
                Button("Cancel", role: .cancel) {
                    showDateConfirmation = false
                    pendingEndDate = nil
                }
                Button("Confirm") {
                    handleDateConfirmation()
                }
            } message: {
                let dateStr = pendingEndDate != nil ? dateFormatter.string(from: pendingEndDate!) : ""
                if dateConfirmationType == .handoverAndMaintenance {
                    Text("The selected end date (\(dateStr)) is greater than the current maintenance date. Handover date and maintenance date will be set to \(dateStr).")
                } else {
                    Text("The selected end date (\(dateStr)) is greater than the current handover date. Handover date will be set to \(dateStr).")
                }
            }
        }
    }
    
    private func loadNextPhaseNumber() {
        Task {
            do {
                // Get customerId from Firebase Auth
                guard let customerId = Auth.auth().currentUser?.uid else {
                    print("❌ Customer ID not found in loadNextPhaseNumber")
                    await MainActor.run {
                        nextPhaseNumber = existingPhaseCount + 1
                    }
                    return
                }
                
                let snapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .order(by: "phaseNumber", descending: true)
                    .limit(to: 1)
                    .getDocuments()
                
                if let lastPhaseDoc = snapshot.documents.first,
                   let lastPhase = try? lastPhaseDoc.data(as: Phase.self) {
                    await MainActor.run {
                        nextPhaseNumber = lastPhase.phaseNumber + 1
                    }
                } else {
                    await MainActor.run {
                        nextPhaseNumber = 1
                    }
                }
            } catch {
                // Fallback to count-based calculation
                await MainActor.run {
                    nextPhaseNumber = existingPhaseCount + 1
                }
            }
        }
    }
    
    private func loadExistingPhaseNames() {
        Task {
            do {
                // Get customerId from Firebase Auth
                guard let customerId = Auth.auth().currentUser?.uid else {
                    print("❌ Customer ID not found in loadExistingPhaseNames")
                    return
                }
                
                let snapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                var phaseNames: [String] = []
                for doc in snapshot.documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        phaseNames.append(phase.phaseName)
                    }
                }
                
                await MainActor.run {
                    existingPhaseNames = phaseNames
                }
            } catch {
                // Error loading existing phase names
            }
        }
    }
    
    private func savePhase() {
        // Validate phase name before saving
        validatePhaseName()
        
        // Check for duplicate department names
        if hasDuplicateDepartmentNames() {
            let duplicates = getDuplicateDepartmentNames()
            let phaseNameDisplay = phaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "this phase" : "\"\(phaseName.trimmingCharacters(in: .whitespacesAndNewlines))\""
            if let firstDuplicate = duplicates.first {
                errorMessage = "\"\(firstDuplicate)\" already exists in \(phaseNameDisplay). Enter a unique department name."
            } else {
                errorMessage = "Department names must be unique within this phase. Enter unique department names."
            }
            return
        }
        
        guard isFormValid else {
            if phaseNameError != nil {
                errorMessage = phaseNameError
            } else if hasDuplicateDepartmentNames() {
                let duplicates = getDuplicateDepartmentNames()
                let phaseNameDisplay = phaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "this phase" : "\"\(phaseName.trimmingCharacters(in: .whitespacesAndNewlines))\""
                if let firstDuplicate = duplicates.first {
                    errorMessage = "\"\(firstDuplicate)\" already exists in \(phaseNameDisplay). Enter a unique department name."
                } else {
                    errorMessage = "Department names must be unique within this phase. Enter unique department names."
                }
            }
            return
        }
        
        // Check dates before saving
        checkDatesAndConfirm()
    }
    
    private func checkDatesAndConfirm() {
        Task {
            do {
                guard let customerId = Auth.auth().currentUser?.uid else {
                    await MainActor.run {
                        errorMessage = "Customer ID not found. Please log in again."
                    }
                    return
                }
                
                // Fetch project to get current handover and maintenance dates
                let projectDoc = try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .getDocument()
                
                guard projectDoc.exists,
                      let project = try? projectDoc.data(as: Project.self) else {
                    // If project not found, proceed with normal save
                    await proceedWithSave()
                    return
                }
                
                let calendar = Calendar.current
                let selectedEndDate = calendar.startOfDay(for: endDate)
                
                // Parse current dates
                var currentHandoverDate: Date?
                var currentMaintenanceDate: Date?
                
                if let handoverDateStr = project.handoverDate,
                   let handoverDate = dateFormatter.date(from: handoverDateStr) {
                    currentHandoverDate = calendar.startOfDay(for: handoverDate)
                }
                
                if let maintenanceDateStr = project.maintenanceDate,
                   let maintenanceDate = dateFormatter.date(from: maintenanceDateStr) {
                    currentMaintenanceDate = calendar.startOfDay(for: maintenanceDate)
                }
                
                // Check conditions
                // Note: Handover date should always be <= maintenance date
                // So if selected end date > maintenance date, we must update both dates
                if let maintenanceDate = currentMaintenanceDate, selectedEndDate > maintenanceDate {
                    // Selected end date > maintenance date: Update both handover and maintenance
                    // (handover must be <= maintenance, so both need to be updated)
                    await MainActor.run {
                        dateConfirmationType = .handoverAndMaintenance
                        pendingEndDate = endDate
                        showDateConfirmation = true
                    }
                } else if let handoverDate = currentHandoverDate,
                          selectedEndDate > handoverDate,
                          (currentMaintenanceDate == nil || selectedEndDate <= currentMaintenanceDate!) {
                    // Selected end date > handover date and <= maintenance date: Update only handover
                    // (maintenance date remains unchanged since selected date <= maintenance)
                    await MainActor.run {
                        dateConfirmationType = .handoverOnly
                        pendingEndDate = endDate
                        showDateConfirmation = true
                    }
                } else {
                    // No date updates needed, proceed with normal save
                    await proceedWithSave()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to check dates: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func proceedWithSave(shouldUpdateHandover: Bool = false, shouldUpdateMaintenance: Bool = false) {
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                // Get customerId from Firebase Auth
                guard let customerId = Auth.auth().currentUser?.uid else {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = "Customer ID not found. Please log in again."
                    }
                    return
                }
                
                let phaseRef = FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document()
                
                // Use the calculated next phase number
                let phaseNumber = nextPhaseNumber
                
                // Format dates
                let startDateStr = dateFormatter.string(from: startDate)
                let endDateStr = dateFormatter.string(from: endDate)
                
                // Update project dates if needed (before creating phase)
                if shouldUpdateHandover || shouldUpdateMaintenance {
                    await updateProjectDates(
                        projectId: projectId,
                        customerId: customerId,
                        newDate: endDate,
                        updateHandover: shouldUpdateHandover,
                        updateMaintenance: shouldUpdateMaintenance
                    )
                }
                
                // Create departments dictionary with phaseId_departmentName format
                let phaseId = phaseRef.documentID
                let departmentsDict = Dictionary(uniqueKeysWithValues: departments.map { dept in
                    let departmentKey = String.departmentKey(phaseId: phaseId, departmentName: dept.name)
                    return (departmentKey, Double(removeFormatting(from: dept.amount)) ?? 0)
                })
                
                let phaseData = Phase(
                    id: phaseId,
                    phaseName: phaseName.trimmingCharacters(in: .whitespacesAndNewlines),
                    phaseNumber: phaseNumber,
                    startDate: startDateStr,
                    endDate: endDateStr,
                    departments: departmentsDict,
                    categories: [],
                    isEnabled: true,
                    createdAt: Timestamp(),
                    updatedAt: Timestamp()
                )
                
                try await phaseRef.setData(from: phaseData)
                
                // Update project budget after adding phase
                await updateProjectBudget(projectId: projectId, customerId: customerId)
                
                // Update handover date after adding phase (this will handle the logic internally)
                await updateHandoverDate(projectId: projectId, customerId: customerId)
                
                await MainActor.run {
                    isSaving = false
                    onSaved()
                    dismiss()
                }
                
                // Post notification to refresh phases
                NotificationCenter.default.post(name: NSNotification.Name("PhaseUpdated"), object: nil)
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save phase: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Helper function to update project budget
    private func updateProjectBudget(projectId: String, customerId: String) async {
        do {
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            var totalBudget: Double = 0
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    totalBudget += phase.departments.values.reduce(0, +)
                }
            }
            
            // Update project budget
            try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .updateData([
                    "budget": totalBudget,
                    "updatedAt": Timestamp()
                ])
        } catch {
            print("Error updating project budget: \(error.localizedDescription)")
        }
    }
    
    // Helper function to update handover date (highest end date among all phases)
    private func updateHandoverDate(projectId: String, customerId: String) async {
        do {
            // First, get the project to check status and current handover dates
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .getDocument()
            
            guard projectDoc.exists,
                  let project = try? projectDoc.data(as: Project.self) else {
                print("Error: Project not found")
                return
            }
            
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            var highestEndDate: Date? = nil
            
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self),
                   let endDateStr = phase.endDate,
                   let endDate = dateFormatter.date(from: endDateStr) {
                    if highestEndDate == nil || endDate > highestEndDate! {
                        highestEndDate = endDate
                    }
                }
            }
            
            // Update handover date if we found at least one phase with an end date
            if let highestDate = highestEndDate {
                let calendar = Calendar.current
                let newHandoverDate = calendar.startOfDay(for: highestDate)
                
                // Get current handover date for comparison
                var currentHandoverDate: Date? = nil
                if let handoverDateStr = project.handoverDate,
                   let handoverDate = dateFormatter.date(from: handoverDateStr) {
                    currentHandoverDate = calendar.startOfDay(for: handoverDate)
                }
                
                // Only update if new date is greater than current handover date
                if let currentDate = currentHandoverDate, newHandoverDate > currentDate {
                    let handoverDateStr = dateFormatter.string(from: highestDate)
                    var updateData: [String: Any] = [
                        "handoverDate": handoverDateStr,
                        "updatedAt": Timestamp()
                    ]
                    
                    // Check project status - if LOCKED or IN_REVIEW, update both fields
                    let projectStatus = project.statusType
                    if projectStatus == .LOCKED || projectStatus == .IN_REVIEW {
                        updateData["initialHandOverDate"] = handoverDateStr
                    }
                    
                    try await FirebasePathHelper.shared
                        .projectDocument(customerId: customerId, projectId: projectId)
                        .updateData(updateData)
                } else if currentHandoverDate == nil {
                    // If no current handover date exists, set both
                    let handoverDateStr = dateFormatter.string(from: highestDate)
                    var updateData: [String: Any] = [
                        "handoverDate": handoverDateStr,
                        "updatedAt": Timestamp()
                    ]
                    
                    // Check project status - if LOCKED or IN_REVIEW, update both fields
                    let projectStatus = project.statusType
                    if projectStatus == .LOCKED || projectStatus == .IN_REVIEW {
                        updateData["initialHandOverDate"] = handoverDateStr
                    } else {
                        // For other statuses, set initialHandOverDate only if it doesn't exist
                        if project.initialHandOverDate == nil {
                            updateData["initialHandOverDate"] = handoverDateStr
                        }
                    }
                    
                    try await FirebasePathHelper.shared
                        .projectDocument(customerId: customerId, projectId: projectId)
                        .updateData(updateData)
                }
            }
        } catch {
            print("Error updating handover date: \(error.localizedDescription)")
        }
    }
    
    // Helper function to update project dates directly
    private func updateProjectDates(projectId: String, customerId: String, newDate: Date, updateHandover: Bool, updateMaintenance: Bool) async {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            let newDateStr = dateFormatter.string(from: newDate)
            
            // Fetch project to check status
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .getDocument()
            
            guard projectDoc.exists,
                  let project = try? projectDoc.data(as: Project.self) else {
                print("Error: Project not found")
                return
            }
            
            var updateData: [String: Any] = [
                "updatedAt": Timestamp()
            ]
            
            if updateHandover {
                updateData["handoverDate"] = newDateStr
                
                // Check project status - if LOCKED or IN_REVIEW, update both fields
                let projectStatus = project.statusType
                if projectStatus == .LOCKED || projectStatus == .IN_REVIEW {
                    updateData["initialHandOverDate"] = newDateStr
                }
            }
            
            if updateMaintenance {
                updateData["maintenanceDate"] = newDateStr
            }
            
            try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .updateData(updateData)
        } catch {
            print("Error updating project dates: \(error.localizedDescription)")
        }
    }
    
    // Handle confirmation from alert
    private func handleDateConfirmation() {
        guard let pendingDate = pendingEndDate else { return }
        
        // Update endDate to pending date
        endDate = pendingDate
        
        // Determine which dates to update
        let shouldUpdateHandover = dateConfirmationType == .handoverOnly || dateConfirmationType == .handoverAndMaintenance
        let shouldUpdateMaintenance = dateConfirmationType == .handoverAndMaintenance
        
        // Proceed with save
        proceedWithSave(shouldUpdateHandover: shouldUpdateHandover, shouldUpdateMaintenance: shouldUpdateMaintenance)
        
        // Reset confirmation state
        showDateConfirmation = false
        pendingEndDate = nil
    }
}

// MARK: - Department Item for Add Phase Sheet
private struct AddPhaseDepartmentItem: Identifiable {
    let id = UUID()
    var name: String = ""
    var amount: String = "0"
}

// MARK: - Edit Phase Sheet
private struct EditPhaseSheet: View {
    let projectId: String
    let phaseId: String
    let currentPhaseName: String
    let currentStartDate: Date?
    let currentEndDate: Date?
    let onSaved: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var phaseName: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(86400 * 30)
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var existingPhaseNames: [String] = []
    @State private var phaseNameError: String?
    @FocusState private var focusedField: Field?
    
    // Date confirmation alert states
    @State private var showDateConfirmation = false
    @State private var dateConfirmationType: DateConfirmationType = .handoverAndMaintenance
    @State private var pendingEndDate: Date?
    
    private enum Field { case phaseName }
    
    private enum DateConfirmationType {
        case handoverAndMaintenance
        case handoverOnly
    }
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }
    
    private var isFormValid: Bool {
        let trimmedName = phaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty &&
        phaseNameError == nil &&
        endDate > startDate
    }
    
    private func validatePhaseName() {
        let trimmedName = phaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            phaseNameError = "Phase name is required"
            return
        }
        
        // Check for duplicate phase names (case-insensitive), excluding current phase
        let isDuplicate = existingPhaseNames.contains { existingName in
            // Exclude the current phase name from duplicate check
            existingName != currentPhaseName &&
            existingName.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
        
        if isDuplicate {
            phaseNameError = "Phase name must be unique"
        } else {
            phaseNameError = nil
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Enter phase name", text: $phaseName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .phaseName)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(phaseNameError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                        .onChange(of: phaseName) { _, _ in
                            validatePhaseName()
                        }
                    
                    if let error = phaseNameError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Phase Name")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    if endDate <= startDate {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("End date must be after start date")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Timeline")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let error = errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit Phase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePhase()
                    }
                    .disabled(!isFormValid || isSaving)
                    .fontWeight(.semibold)
                    .foregroundColor(isFormValid && !isSaving ? .blue : .gray)
                }
            }
            .onAppear {
                // Initialize with current values
                phaseName = currentPhaseName
                if let start = currentStartDate {
                    startDate = start
                }
                if let end = currentEndDate {
                    endDate = end
                } else if let start = currentStartDate {
                    // If no end date, set it to 30 days after start
                    endDate = Calendar.current.date(byAdding: .day, value: 30, to: start) ?? Date().addingTimeInterval(86400 * 30)
                }
                focusedField = .phaseName
                loadExistingPhaseNames()
            }
            .alert("Update Project Dates", isPresented: $showDateConfirmation) {
                Button("Cancel", role: .cancel) {
                    showDateConfirmation = false
                    pendingEndDate = nil
                }
                Button("Confirm") {
                    handleDateConfirmation()
                }
            } message: {
                let dateStr = pendingEndDate != nil ? dateFormatter.string(from: pendingEndDate!) : ""
                if dateConfirmationType == .handoverAndMaintenance {
                    Text("The selected end date (\(dateStr)) is greater than the current maintenance date. Handover date and maintenance date will be set to \(dateStr).")
                } else {
                    Text("The selected end date (\(dateStr)) is greater than the current handover date. Handover date will be set to \(dateStr).")
                }
            }
        }
    }
    
    private func loadExistingPhaseNames() {
        Task {
            do {
                // Get customerId from authService
                guard let customerId = authService.currentCustomerId else {
                    print("❌ Customer ID not found in loadExistingPhaseNames")
                    return
                }
                
                let snapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                var phaseNames: [String] = []
                for doc in snapshot.documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        phaseNames.append(phase.phaseName)
                    }
                }
                
                await MainActor.run {
                    existingPhaseNames = phaseNames
                }
            } catch {
                // Error loading existing phase names
            }
        }
    }
    
    private func savePhase() {
        // Validate phase name before saving
        validatePhaseName()
        
        guard isFormValid else {
            if phaseNameError != nil {
                errorMessage = phaseNameError
            }
            return
        }
        
        // Check if end date changed, if so check dates before saving
        let endDateChanged = currentEndDate == nil || 
                            (currentEndDate != nil && !Calendar.current.isDate(endDate, inSameDayAs: currentEndDate!))
        
        if endDateChanged {
            checkDatesAndConfirm()
        } else {
            // No date change, proceed with normal save
            proceedWithSave()
        }
    }
    
    private func checkDatesAndConfirm() {
        Task {
            do {
                guard let customerId = authService.currentCustomerId else {
                    await MainActor.run {
                        errorMessage = "Customer ID not found. Please log in again."
                    }
                    return
                }
                
                // Fetch project to get current handover and maintenance dates
                let projectDoc = try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .getDocument()
                
                guard projectDoc.exists,
                      let project = try? projectDoc.data(as: Project.self) else {
                    // If project not found, proceed with normal save
                    await proceedWithSave()
                    return
                }
                
                let calendar = Calendar.current
                let selectedEndDate = calendar.startOfDay(for: endDate)
                
                // Parse current dates
                var currentHandoverDate: Date?
                var currentMaintenanceDate: Date?
                
                if let handoverDateStr = project.handoverDate,
                   let handoverDate = dateFormatter.date(from: handoverDateStr) {
                    currentHandoverDate = calendar.startOfDay(for: handoverDate)
                }
                
                if let maintenanceDateStr = project.maintenanceDate,
                   let maintenanceDate = dateFormatter.date(from: maintenanceDateStr) {
                    currentMaintenanceDate = calendar.startOfDay(for: maintenanceDate)
                }
                
                // Check conditions
                // Note: Handover date should always be <= maintenance date
                // So if selected end date > maintenance date, we must update both dates
                if let maintenanceDate = currentMaintenanceDate, selectedEndDate > maintenanceDate {
                    // Selected end date > maintenance date: Update both handover and maintenance
                    // (handover must be <= maintenance, so both need to be updated)
                    await MainActor.run {
                        dateConfirmationType = .handoverAndMaintenance
                        pendingEndDate = endDate
                        showDateConfirmation = true
                    }
                } else if let handoverDate = currentHandoverDate,
                          selectedEndDate > handoverDate,
                          (currentMaintenanceDate == nil || selectedEndDate <= currentMaintenanceDate!) {
                    // Selected end date > handover date and <= maintenance date: Update only handover
                    // (maintenance date remains unchanged since selected date <= maintenance)
                    await MainActor.run {
                        dateConfirmationType = .handoverOnly
                        pendingEndDate = endDate
                        showDateConfirmation = true
                    }
                } else {
                    // No date updates needed, proceed with normal save
                    await proceedWithSave()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to check dates: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func proceedWithSave(shouldUpdateHandover: Bool = false, shouldUpdateMaintenance: Bool = false) {
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                // Get customerId and current user UID
                guard let customerId = authService.currentCustomerId,
                      let currentUserUID = Auth.auth().currentUser?.uid else {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = "Customer ID not found. Please log in again."
                    }
                    return
                }
                
                let phaseRef = FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phaseId)
                
                // Format new dates
                let startDateStr = dateFormatter.string(from: startDate)
                let endDateStr = dateFormatter.string(from: endDate)
                
                // Format previous dates for comparison
                let previousStartDateStr: String? = currentStartDate != nil ? dateFormatter.string(from: currentStartDate!) : nil
                let previousEndDateStr: String? = currentEndDate != nil ? dateFormatter.string(from: currentEndDate!) : nil
                
                // Check if timeline (start or end date) has changed
                let startDateChanged = previousStartDateStr != startDateStr
                let endDateChanged = previousEndDateStr != endDateStr
                
                // Update project dates if needed (before updating phase)
                if shouldUpdateHandover || shouldUpdateMaintenance {
                    await updateProjectDates(
                        projectId: projectId,
                        customerId: customerId,
                        newDate: endDate,
                        updateHandover: shouldUpdateHandover,
                        updateMaintenance: shouldUpdateMaintenance
                    )
                }
                
                // Update phase data
                try await phaseRef.updateData([
                    "phaseName": phaseName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "startDate": startDateStr,
                    "endDate": endDateStr,
                    "updatedAt": Timestamp()
                ])
                
                // Log timeline change if dates were modified
                if startDateChanged || endDateChanged {
                    let changeLog = PhaseTimelineChange(
                        phaseId: phaseId,
                        projectId: projectId,
                        previousStartDate: previousStartDateStr,
                        previousEndDate: previousEndDateStr,
                        newStartDate: startDateStr,
                        newEndDate: endDateStr,
                        changedBy: currentUserUID
                    )
                    
                    // Save change log to phases/{phaseId}/changes subcollection
                    let changesRef = phaseRef.collection("changes").document()
                    try await changesRef.setData(from: changeLog)
                }
                
                // Note: Project budget doesn't change when editing phase name/dates, only when departments change
                
                // Update handover date after phase timeline is edited (this will handle the logic internally)
                await updateHandoverDate(projectId: projectId, customerId: customerId)
                
                await MainActor.run {
                    isSaving = false
                    onSaved()
                    dismiss()
                }
                
                // Post notification to refresh phases
                NotificationCenter.default.post(name: NSNotification.Name("PhaseUpdated"), object: nil)
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to update phase: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Helper function to update project budget
    private func updateProjectBudget(projectId: String, customerId: String) async {
        do {
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            var totalBudget: Double = 0
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    totalBudget += phase.departments.values.reduce(0, +)
                }
            }
            
            // Update project budget
            try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .updateData([
                    "budget": totalBudget,
                    "updatedAt": Timestamp()
                ])
        } catch {
            print("Error updating project budget: \(error.localizedDescription)")
        }
    }
    
    // Helper function to update handover date (highest end date among all phases)
    private func updateHandoverDate(projectId: String, customerId: String) async {
        do {
            // First, get the project to check status and current handover dates
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .getDocument()
            
            guard projectDoc.exists,
                  let project = try? projectDoc.data(as: Project.self) else {
                print("Error: Project not found")
                return
            }
            
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            var highestEndDate: Date? = nil
            
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self),
                   let endDateStr = phase.endDate,
                   let endDate = dateFormatter.date(from: endDateStr) {
                    if highestEndDate == nil || endDate > highestEndDate! {
                        highestEndDate = endDate
                    }
                }
            }
            
            // Update handover date if we found at least one phase with an end date
            if let highestDate = highestEndDate {
                let calendar = Calendar.current
                let newHandoverDate = calendar.startOfDay(for: highestDate)
                
                // Get current handover date for comparison
                var currentHandoverDate: Date? = nil
                if let handoverDateStr = project.handoverDate,
                   let handoverDate = dateFormatter.date(from: handoverDateStr) {
                    currentHandoverDate = calendar.startOfDay(for: handoverDate)
                }
                
                // Only update if new date is greater than current handover date
                if let currentDate = currentHandoverDate, newHandoverDate > currentDate {
                    let handoverDateStr = dateFormatter.string(from: highestDate)
                    var updateData: [String: Any] = [
                        "handoverDate": handoverDateStr,
                        "updatedAt": Timestamp()
                    ]
                    
                    // Check project status - if LOCKED or IN_REVIEW, update both fields
                    let projectStatus = project.statusType
                    if projectStatus == .LOCKED || projectStatus == .IN_REVIEW {
                        updateData["initialHandOverDate"] = handoverDateStr
                    }
                    
                    try await FirebasePathHelper.shared
                        .projectDocument(customerId: customerId, projectId: projectId)
                        .updateData(updateData)
                } else if currentHandoverDate == nil {
                    // If no current handover date exists, set both
                    let handoverDateStr = dateFormatter.string(from: highestDate)
                    var updateData: [String: Any] = [
                        "handoverDate": handoverDateStr,
                        "updatedAt": Timestamp()
                    ]
                    
                    // Check project status - if LOCKED or IN_REVIEW, update both fields
                    let projectStatus = project.statusType
                    if projectStatus == .LOCKED || projectStatus == .IN_REVIEW {
                        updateData["initialHandOverDate"] = handoverDateStr
                    } else {
                        // For other statuses, set initialHandOverDate only if it doesn't exist
                        if project.initialHandOverDate == nil {
                            updateData["initialHandOverDate"] = handoverDateStr
                        }
                    }
                    
                    try await FirebasePathHelper.shared
                        .projectDocument(customerId: customerId, projectId: projectId)
                        .updateData(updateData)
                }
            }
        } catch {
            print("Error updating handover date: \(error.localizedDescription)")
        }
    }
    
    // Helper function to update project dates directly
    private func updateProjectDates(projectId: String, customerId: String, newDate: Date, updateHandover: Bool, updateMaintenance: Bool) async {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            let newDateStr = dateFormatter.string(from: newDate)
            
            // Fetch project to check status
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .getDocument()
            
            guard projectDoc.exists,
                  let project = try? projectDoc.data(as: Project.self) else {
                print("Error: Project not found")
                return
            }
            
            var updateData: [String: Any] = [
                "updatedAt": Timestamp()
            ]
            
            if updateHandover {
                updateData["handoverDate"] = newDateStr
                
                // Check project status - if LOCKED or IN_REVIEW, update both fields
                let projectStatus = project.statusType
                if projectStatus == .LOCKED || projectStatus == .IN_REVIEW {
                    updateData["initialHandOverDate"] = newDateStr
                }
            }
            
            if updateMaintenance {
                updateData["maintenanceDate"] = newDateStr
            }
            
            try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .updateData(updateData)
        } catch {
            print("Error updating project dates: \(error.localizedDescription)")
        }
    }
    
    // Handle confirmation from alert
    private func handleDateConfirmation() {
        guard let pendingDate = pendingEndDate else { return }
        
        // Update endDate to pending date
        endDate = pendingDate
        
        // Determine which dates to update
        let shouldUpdateHandover = dateConfirmationType == .handoverOnly || dateConfirmationType == .handoverAndMaintenance
        let shouldUpdateMaintenance = dateConfirmationType == .handoverAndMaintenance
        
        // Proceed with save
        proceedWithSave(shouldUpdateHandover: shouldUpdateHandover, shouldUpdateMaintenance: shouldUpdateMaintenance)
        
        // Reset confirmation state
        showDateConfirmation = false
        pendingEndDate = nil
    }
}

// MARK: - Section Header Component
private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .sectionHeaderStyle()
    }
}

#Preview {
    DashboardView(project: Project.sampleData.first, phoneNumber: "1234567890")
}
