//
//  ProjectDetailView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//


// ProjectDetailView.swift
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ProjectDetailView: View {
    // The view takes a single project object as input.
    var project: Project
    @StateObject private var notificationViewModel = NotificationViewModel()
    @ObservedObject var stateManager: DashboardStateManager
    @State private var showingAddExpense = false
    @State private var showingChats = false
    @State private var showingNotifications = false
    @State private var isTeamMembersDropdownVisible = false
    @State private var hasVisiblePhase = false
    @ObservedObject private var viewModel: ProjectDetailViewModel
    let role: UserRole?
    let phoneNumber: String
    let customerId: String?
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var authService: FirebaseAuthService


    init(project: Project, role: UserRole? = nil, phoneNumber: String = "", customerId: String? = nil, stateManager: DashboardStateManager? = nil){
        self.project = project
        self.role = role
        self.phoneNumber = phoneNumber
        self.customerId = customerId
        self._viewModel = ObservedObject(wrappedValue: ProjectDetailViewModel(project: project, CurrentUserPhone: phoneNumber, customerId: customerId))
        // Use provided state manager or create a new one
        if let stateManager = stateManager {
            self._stateManager = ObservedObject(wrappedValue: stateManager)
        } else {
            self._stateManager = ObservedObject(wrappedValue: DashboardStateManager())
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    // MARK: - Main Header Card
                    ProjectHeaderView(project: project)
                        .cardStyle()
                        .padding(.horizontal, DesignSystem.Spacing.medium)

                    // MARK: - Key Info Card
                    KeyInformationView(
                        project: project,
                        viewModel: viewModel,
                        isTeamMembersDropdownVisible: $isTeamMembersDropdownVisible
                    )
                    .cardStyle()
                    .padding(.horizontal, DesignSystem.Spacing.medium)

                    // MARK: - Phase Budget Breakdown
                    PhaseBreakdownView(
                        project: project,
                        viewModel: viewModel,
                        hasVisiblePhase: $hasVisiblePhase
                    )
    //                    .cardStyle()
    //                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    
                    // MARK: - Expense Section
                    ExpenseListView(project: project, currentUserPhone : phoneNumber)
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                    
                    // Bottom padding for floating button
                    Color.clear
                        .frame(height: 80)
                }
                .padding(.top, DesignSystem.Spacing.small)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .onPreferenceChange(PhaseVisibilityPreferenceKey.self) { frames in
                checkPhaseVisibility(frames: frames)
            }
            .overlay(alignment: .topTrailing) {
                // Sticky "View All Phases" button on the right - only when phases are 50%+ visible
                if hasVisiblePhase && viewModel.phases.count > 1 {
                    ViewAllPhasesButton(
                        viewModel: viewModel,
                        projectId: project.id ?? ""
                    )
                    .padding(.trailing, DesignSystem.Spacing.medium)
                    .padding(.top, DesignSystem.Spacing.medium)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .coordinateSpace(name: "scroll")
            
            // Full-screen dropdown overlay - appears above everything
            if isTeamMembersDropdownVisible {
                TeamMembersDropdownOverlay(
                    teamMembers: project.teamMembers,
                    isVisible: $isTeamMembersDropdownVisible
                )
                .zIndex(10000)
            }
        }
        .navigationTitle("Project Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    HapticManager.selection()
                    showingNotifications = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.title3)
                            .foregroundColor(.primary)
                        
                        if notificationViewModel.hasNotifications {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                                .offset(x: 8, y: -8)
                        }
                    }
                }

                Button {
                    HapticManager.impact(.light)
                    showingChats = true
                } label: {
                    Image(systemName: "message.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            addExpenseButton
        }
        .onAppear {
            viewModel.loadPhases()
            viewModel.fetchApprovedExpenses()
            
            // Load state manager data
            if let projectId = project.id, let customerId = customerId {
                Task {
                    await stateManager.loadAllData(projectId: projectId, customerId: customerId)
                    await stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                }
            }
            
            // Load phase extensions
            Task {
                await viewModel.loadPhaseExtensions()
            }
            
            // Load notifications
            Task {
                if let projectId = project.id {
                    await notificationViewModel.fetchProjectNotifications(
                        projectId: projectId,
                        currentUserPhone: phoneNumber,
                        currentUserRole: role ?? .USER
                    )
                }
            }
            
            // Reset visibility when view appears
            hasVisiblePhase = false
        }
        .overlay {
            if showingNotifications {
                NotificationPopupView(
                    notificationViewModel: notificationViewModel,
                    project: project,
                    role: role,
                    phoneNumber: phoneNumber,
                    isPresented: $showingNotifications
                )
            }
        }
        .refreshable {
            viewModel.loadPhases()
            viewModel.fetchApprovedExpenses()
            Task {
                await viewModel.loadPhaseExtensions()
                // Refresh state manager data
                if let projectId = project.id, let customerId = customerId {
                    await stateManager.loadAllData(projectId: projectId, customerId: customerId)
                    await stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProjectUpdated"))) { _ in
            // Reload state manager when project is updated
            if let projectId = project.id, let customerId = customerId {
                Task {
                    await stateManager.loadAllData(projectId: projectId, customerId: customerId)
                    await stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                }
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
    }
    
    private func checkPhaseVisibility(frames: [CGRect]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        let screenHeight = window.bounds.height
        let safeAreaTop = window.safeAreaInsets.top
        let safeAreaBottom = window.safeAreaInsets.bottom
        
        // Visible area accounts for navigation bar (~100pt) and bottom button (~100pt)
        let visibleAreaTop: CGFloat = safeAreaTop + 100
        let visibleAreaBottom: CGFloat = screenHeight - safeAreaBottom - 100
        
        var hasVisible = false
        
        for frame in frames {
            let cardTop = frame.minY
            let cardBottom = frame.maxY
            let cardHeight = frame.height
            
            // Skip if card is completely outside visible area
            if cardBottom < visibleAreaTop || cardTop > visibleAreaBottom {
                continue
            }
            
            // Calculate visible portion of the card
            let visibleTop = max(cardTop, visibleAreaTop)
            let visibleBottom = min(cardBottom, visibleAreaBottom)
            let visibleHeight = max(0, visibleBottom - visibleTop)
            
            // Check if at least 50% of the card is visible
            let visibilityPercentage = cardHeight > 0 ? visibleHeight / cardHeight : 0
            
            if visibilityPercentage >= 0.5 {
                hasVisible = true
                break
            }
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            hasVisiblePhase = hasVisible
        }
    }
    
    /// A prominent button at the bottom of the screen.
    private var addExpenseButton: some View {
        Button(action: {
            HapticManager.impact(.medium)
            showingAddExpense = true
        }) {
            Label("Add New Expense", systemImage: "plus")
                .font(DesignSystem.Typography.headline)
        }
        .primaryButton()
        .padding(DesignSystem.Spacing.medium)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge)
        )
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(project: project)
        }
        .sheet(isPresented: $showingChats) {
            if role == .ADMIN {
                ChatsView(
                    project: project,
                    currentUserRole: .ADMIN
                )
                .presentationDetents([.large])
                .environmentObject(navigationManager)
            } else {
                ChatsView(
                    project: project,
                    currentUserPhone: phoneNumber,
                    currentUserRole: role ?? .USER
                )
                .presentationDetents([.large])
                .environmentObject(navigationManager)
            }
        }
    }
}

// MARK: - Reusable Subviews

private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .sectionHeaderStyle()
    }
}

private struct KeyInformationView: View {
    let project: Project
    var viewModel: ProjectDetailViewModel
    @Binding var isTeamMembersDropdownVisible: Bool
    
    var totalApprovedAmount: Double {
        viewModel.approvedExpensesByDepartment.values.reduce(0, +)
    }
    
    var totalRemainingBudget: Double {
        project.budget - totalApprovedAmount
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                SectionHeader(title: "Key Information")
                
                VStack(spacing: DesignSystem.Spacing.medium) {
                    InfoRowDetial(
                        icon: "indianrupeesign.circle.fill",
                        label: "Total Budget",
                        value: project.budgetFormatted,
                        iconColor: .green
                    )
                    
                    Divider()
                    
                    InfoRowDetial(
                        icon: "checkmark.circle.fill",
                        label: "Approved Expenses",
                        value: formatCurrency(totalApprovedAmount),
                        iconColor: .blue
                    )
                    
                    Divider()
                    
                    InfoRowDetial(
                        icon: "minus.circle.fill",
                        label: "Remaining Budget",
                        value: formatCurrency(totalRemainingBudget),
                        iconColor: totalRemainingBudget >= 0 ? .orange : .red
                    )
                    
                    Divider()
                    
                    // Team Members - Tappable with dropdown
                    TeamMembersRow(
                        teamMembers: project.teamMembers,
                        isDropdownVisible: $isTeamMembersDropdownVisible
                    )
                }
            }
            .padding(DesignSystem.Spacing.medium)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0.00"
    }
}

private struct PhaseBreakdownView: View {
    let project: Project
    @ObservedObject var viewModel: ProjectDetailViewModel
    @Binding var hasVisiblePhase: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading phases...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.medium)
            } else if !viewModel.currentPhases.isEmpty {
                VStack() {
                    ForEach(Array(viewModel.currentPhases.enumerated()), id: \.element.id) { index, phase in
                        CurrentPhaseView(
                            phase: phase,
                            projectId: project.id ?? "",
                            phaseExtensionMap: viewModel.phaseExtensionMap,
                            hasVisiblePhase: $hasVisiblePhase
                        )
                        .padding(DesignSystem.Spacing.medium)
                        .cardStyle()
                        .background(PhaseVisibilityPreferenceView())
                    }
                }
            } else {
                EmptyStateRow(
                    icon: "calendar.badge.clock",
                    text: "No active phase at the moment"
                )
                .padding(DesignSystem.Spacing.medium)
                .cardStyle()
            }
        }
        .padding(DesignSystem.Spacing.medium)
    }
}

// MARK: - Sticky View All Phases Button
private struct ViewAllPhasesButton: View {
    @ObservedObject var viewModel: ProjectDetailViewModel
    let projectId: String
    @State private var showingAllPhases = false
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            showingAllPhases = true
        }) {
            Text("View All Phases")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.black) // darker text for contrast on white background
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                .background(Color.white.opacity(0.5)) // 👈 semi-transparent white
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

        }
        .sheet(isPresented: $showingAllPhases) {
            AllPhasesSheetView(
                currentPhases: viewModel.currentPhases,
                expiredPhases: viewModel.expiredPhases,
                projectId: projectId,
                phaseExtensionMap: viewModel.phaseExtensionMap
            )
        }
    }
}

// MARK: - Phase Visibility Preference Key
private struct PhaseVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - ScrollView Frame Preference Key
private struct ScrollViewFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Phase Visibility Preference View
private struct PhaseVisibilityPreferenceView: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: PhaseVisibilityPreferenceKey.self,
                    value: [geometry.frame(in: .global)]
                )
        }
    }
}

private struct CurrentPhaseView: View {
    let phase: ProjectDetailViewModel.PhaseInfo
    let projectId: String
    let phaseExtensionMap: [String: Bool]
    @Binding var hasVisiblePhase: Bool
    
    @State private var isExpanded = false // Default to expanded
    @State private var showingRequestForm = false
    @State private var showingRequestStatus = false
    @State private var hasUserRequests = false
    @StateObject private var requestStatusViewModel = UserPhaseRequestStatusViewModel()
    @EnvironmentObject var authService: FirebaseAuthService
    
    // Helper to check if phase is in progress
    private func isPhaseInProgress(_ phase: ProjectDetailViewModel.PhaseInfo) -> Bool {
        let current = Date()
        switch (phase.startDate, phase.endDate) {
        case (nil, nil):
            return true // Always visible if no dates
        case (let s?, nil):
            return s <= current // Visible if start date passed
        case (nil, let e?):
            return current <= e // Visible if before end date
        case (let s?, let e?):
            return s <= current && current <= e // Visible if in range
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0.00"
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }
    
    private var dateRangeText: String? {
        guard let startDate = phase.startDate, let endDate = phase.endDate else {
            return nil
        }
        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)
        return "Start: \(startStr) • End: \(endStr)"
    }
    
    private var daysRemaining: Int? {
        guard let endDate = phase.endDate else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
        return days
    }
    
    private var daysRemainingColor: Color {
        guard let days = daysRemaining else { return .secondary }
        if days < 0 {
            return .red // Overdue
        } else if days <= 7 {
            return .red // Critical (less than 7 days)
        } else if days <= 14 {
            return .orange // Warning (7-14 days)
        } else {
            return .green // Good (more than 14 days)
        }
    }
    
    var progressColor: Color {
        if phase.spentPercentage > 1.0 {
            return .red
        } else if phase.spentPercentage > 0.8 {
            return .orange
        } else {
            return .blue
        }
    }
    
    private func checkUserRequests() async {
        guard var currentUserUID = Auth.auth().currentUser?.phoneNumber,
              let customerId = authService.currentCustomerId else {
            hasUserRequests = false
            return
        }
        
        if currentUserUID.hasPrefix("+91") {
            currentUserUID = currentUserUID.replacingOccurrences(of: "+91", with: "")
        }
        
        do {
            let requestsSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
                .collection("requests")
                .whereField("userID", isEqualTo: currentUserUID)
                .getDocuments()
            
            await MainActor.run {
                hasUserRequests = !requestsSnapshot.documents.isEmpty
            }
        } catch {
            print("Error checking user requests: \(error)")
            await MainActor.run {
                hasUserRequests = false
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Phase Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        TruncatedTextWithTooltip(
                            phase.phaseName,
                            font: DesignSystem.Typography.title3,
                            fontWeight: .semibold,
                            foregroundColor: .primary,
                            lineLimit: 1
                        )
                        
                        // Extension Badge - Show if phase has accepted extension
                        if phaseExtensionMap[phase.id] == true {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.caption2)
                                Text("Extended")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                            .accessibilityLabel("Phase extended via accepted request")
                        }
                        
                        // In Progress Tag - only show if phase is enabled and in progress
                        if phase.isEnabled && isPhaseInProgress(phase) {
                            Text("Active")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    
                    if let dateRangeText = dateRangeText {
                        Text(dateRangeText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Days Remaining
                    if let days = daysRemaining {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(daysRemainingColor)
                            Text(days >= 0 ? "\(days) days remaining" : "\(abs(days)) days overdue")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(daysRemainingColor)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(progressColor)
                        .frame(width: 10, height: 10)
                    
                    // 3-dots Menu (horizontal ellipsis)
                    Menu {
                        if hasUserRequests {
                            Button {
                                HapticManager.selection()
                                showingRequestStatus = true
                            } label: {
                                Label("See Request Status", systemImage: "info.circle")
                            }
                        }
                        
                        Button(role: .destructive) {
                            HapticManager.selection()
                            showingRequestForm = true
                        } label: {
                            Label("Request Override", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                    }
                }
            }
            .sheet(isPresented: $showingRequestForm) {
                PhaseRequestFormView(
                    projectId: projectId,
                    phaseId: phase.id,
                    phaseName: phase.phaseName,
                    phaseEndDate: phase.endDate
                )
            }
            .sheet(isPresented: $showingRequestStatus) {
                UserPhaseRequestStatusView(
                    phaseId: phase.id,
                    phaseName: phase.phaseName,
                    projectId: projectId,
                    customerId: authService.currentCustomerId
                )
                .presentationDetents([.medium])
            }
            .onAppear {
                Task {
                    await checkUserRequests()
                }
            }
            .onChange(of: phase.id) { _ in
                Task {
                    await checkUserRequests()
                }
            }
            
            Divider()
            
            // Phase Budget Summary
            VStack(spacing: DesignSystem.Spacing.small) {
                VStack(spacing: 12) {
                    // Total Budget - Centered
                    VStack(spacing: 4) {
                        Text("TOTAL BUDGET")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(formatCurrency(phase.totalBudget))
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Divider line (optional)
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Approved and Remaining - Left and Right
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("APPROVED")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                            
                            Text(formatCurrency(phase.approvedAmount))
                                .font(DesignSystem.Typography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("REMAINING")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                            
                            Text(formatCurrency(phase.remainingAmount))
                                .font(DesignSystem.Typography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(phase.remainingAmount >= 0 ? .green : .red)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)

                
                // Progress bar
                ProgressView(value: min(phase.spentPercentage, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                    .scaleEffect(y: 0.8)
                
                // Percentage text
                HStack {
                    Text("\(Int(phase.spentPercentage * 100))% utilized")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if phase.spentPercentage > 1.0 {
                        Text("Over budget!")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Department Breakdown - Expandable with horizontal scrolling
            if !phase.departments.isEmpty {
                Divider()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("Departments")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("(\(phase.departments.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.medium) {
                            ForEach(phase.departments) { department in
                                HorizontalDepartmentCard(department: department)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.small)
                    }
                    .padding(.top, DesignSystem.Spacing.small)
                }
            }
        }
    }
}

private struct DepartmentRowView: View {
    let department: ProjectDetailViewModel.DepartmentInfo
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0.00"
    }
    
    var progressColor: Color {
        if department.spentPercentage > 1.0 {
            return .red
        } else if department.spentPercentage > 0.8 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            HStack {
                TruncatedTextWithTooltip(
                    department.name,
                    font: DesignSystem.Typography.callout,
                    fontWeight: .medium,
                    foregroundColor: .primary,
                    lineLimit: 1
                )
                
                Spacer()
                
                Circle()
                    .fill(progressColor)
                    .frame(width: 6, height: 6)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ALLOCATED")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(formatCurrency(department.allocatedBudget))
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("APPROVED")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(formatCurrency(department.approvedAmount))
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("REMAINING")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(formatCurrency(department.remainingAmount))
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.semibold)
                        .foregroundColor(department.remainingAmount >= 0 ? .green : .red)
                }
            }
            
            ProgressView(value: min(department.spentPercentage, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .scaleEffect(y: 0.6)
            
            Text("\(Int(department.spentPercentage * 100))% utilized")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}

private struct AllPhasesSheetView: View {
    let currentPhases: [ProjectDetailViewModel.PhaseInfo]
    let expiredPhases: [ProjectDetailViewModel.PhaseInfo]
    let projectId: String
    let phaseExtensionMap: [String: Bool]
    @Environment(\.dismiss) private var dismiss
    
    private var allPhases: [ProjectDetailViewModel.PhaseInfo] {
        // Combine current and expired phases, sorted by phase number
        (currentPhases + expiredPhases).sorted { $0.phaseNumber < $1.phaseNumber }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.jumbo) {
                    // Current Phases Section
                    if !currentPhases.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("Current Phases")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            
                            VStack(spacing: DesignSystem.Spacing.jumbo) {
                                ForEach(currentPhases) { phase in
                                    ProjectDetailPhaseCardView(
                                        phase: phase,
                                        isInProgress: true,
                                        projectId: projectId,
                                        phaseExtensionMap: phaseExtensionMap
                                    )
                                    .padding(DesignSystem.Spacing.medium)
                                    .cardStyle()
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                        }
                    }
                    
                    // Expired Phases Section
                    if !expiredPhases.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("Completed Phases")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            
                            VStack(spacing: DesignSystem.Spacing.jumbo) {
                                ForEach(expiredPhases) { phase in
                                    ProjectDetailPhaseCardView(
                                        phase: phase,
                                        isInProgress: false,
                                        projectId: projectId,
                                        phaseExtensionMap: phaseExtensionMap
                                    )
                                    .padding(DesignSystem.Spacing.medium)
                                    .cardStyle()
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                        }
                    }
                    
                    // Empty State
                    if allPhases.isEmpty {
                        VStack(spacing: DesignSystem.Spacing.small) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                                .padding(.top, DesignSystem.Spacing.large)
                            
                            Text("No Phases Available")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.top, DesignSystem.Spacing.small)
                            
                            Text("There are no current or completed phases to display.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignSystem.Spacing.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.large)
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                    }
                }
                .padding(.top, DesignSystem.Spacing.medium)
                .padding(.bottom, DesignSystem.Spacing.large)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("All Phases")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct ProjectDetailPhaseCardView: View {
    let phase: ProjectDetailViewModel.PhaseInfo
    let isInProgress: Bool
    let projectId: String
    let phaseExtensionMap: [String: Bool]
    @State private var isExpanded = false // Default to expanded
    @State private var showingRequestForm = false
    @State private var showingRequestStatus = false
    @State private var hasUserRequests = false
    @EnvironmentObject var authService: FirebaseAuthService
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0.00"
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }
    
    private var dateRangeText: String? {
        guard let startDate = phase.startDate, let endDate = phase.endDate else {
            return nil
        }
        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)
        return "Start: \(startStr) • End: \(endStr)"
    }
    
    var progressColor: Color {
        if phase.spentPercentage > 1.0 {
            return .red
        } else if phase.spentPercentage > 0.8 {
            return .orange
        } else {
            return .blue
        }
    }
    
    private func checkUserRequests() async {
        guard var currentUserUID = Auth.auth().currentUser?.phoneNumber,
              let customerId = authService.currentCustomerId else {
            hasUserRequests = false
            return
        }
        
        if currentUserUID.hasPrefix("+91") {
            currentUserUID = currentUserUID.replacingOccurrences(of: "+91", with: "")
        }
        
        do {
            let requestsSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phase.id)
                .collection("requests")
                .whereField("userID", isEqualTo: currentUserUID)
                .getDocuments()
            
            await MainActor.run {
                hasUserRequests = !requestsSnapshot.documents.isEmpty
            }
        } catch {
            print("Error checking user requests: \(error)")
            await MainActor.run {
                hasUserRequests = false
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Phase Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TruncatedTextWithTooltip(
                            phase.phaseName,
                            font: DesignSystem.Typography.title3,
                            fontWeight: .semibold,
                            foregroundColor: .primary,
                            lineLimit: 1
                        )
                        
                        // Extension Badge - Show if phase has accepted extension
                        if phaseExtensionMap[phase.id] == true {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.caption2)
                                Text("Extended")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                            .accessibilityLabel("Phase extended via accepted request")
                        }
                        
                        // Status Badge - removed "In Progress", only show "Completed" for expired phases
                        if !isInProgress {
                            Text("Completed")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray)
                                .cornerRadius(8)
                        }
                    }
                    
                    if let dateRangeText = dateRangeText {
                        Text(dateRangeText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Status Indicator
                    Circle()
                        .fill(progressColor)
                        .frame(width: 10, height: 10)
                    
                    // 3-dots Menu (horizontal ellipsis)
                    Menu {
                        if hasUserRequests {
                            Button {
                                HapticManager.selection()
                                showingRequestStatus = true
                            } label: {
                                Label("See Request Status", systemImage: "info.circle")
                            }
                        }
                        
                        Button(role: .destructive) {
                            HapticManager.selection()
                            showingRequestForm = true
                        } label: {
                            Label("Request Override", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                    }
                }
            }
            .sheet(isPresented: $showingRequestForm) {
                PhaseRequestFormView(
                    projectId: projectId,
                    phaseId: phase.id,
                    phaseName: phase.phaseName,
                    phaseEndDate: phase.endDate
                )
            }
            .sheet(isPresented: $showingRequestStatus) {
                UserPhaseRequestStatusView(
                    phaseId: phase.id,
                    phaseName: phase.phaseName,
                    projectId: projectId,
                    customerId: authService.currentCustomerId
                )
                .presentationDetents([.medium])
            }
            .onAppear {
                Task {
                    await checkUserRequests()
                }
            }
            .onChange(of: phase.id) { _ in
                Task {
                    await checkUserRequests()
                }
            }
            
            Divider()
                .padding(.vertical, DesignSystem.Spacing.extraSmall)
            
            // Budget Summary - Compact
            VStack(spacing: 12) {
                // Total Budget - Centered
                VStack(spacing: 4) {
                    Text("TOTAL BUDGET")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(formatCurrency(phase.totalBudget))
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Divider line (optional)
                Divider()
                    .padding(.horizontal, 16)
                
                // Approved and Remaining - Left and Right
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("APPROVED")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(formatCurrency(phase.approvedAmount))
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("REMAINING")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(formatCurrency(phase.remainingAmount))
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(phase.remainingAmount >= 0 ? .green : .red)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)

            
            // Progress Bar
            ProgressView(value: min(phase.spentPercentage, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .scaleEffect(y: 0.8)
                .padding(.top, 4)
            
            // Utilization Text
            HStack {
                Text("\(Int(phase.spentPercentage * 100))% utilized")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if phase.spentPercentage > 1.0 {
                    Text("Over budget!")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            }
            
            // Department Breakdown - Expandable with horizontal scrolling
            if !phase.departments.isEmpty {
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("Departments")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("(\(phase.departments.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.medium) {
                            ForEach(phase.departments) { department in
                                HorizontalDepartmentCard(department: department)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.small)
                    }
                    .padding(.top, DesignSystem.Spacing.small)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small)
    }
}

// MARK: - Horizontal Department Card for All Phases View
private struct HorizontalDepartmentCard: View {
    let department: ProjectDetailViewModel.DepartmentInfo
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0.00"
    }
    
    var progressColor: Color {
        if department.spentPercentage > 1.0 {
            return .red
        } else if department.spentPercentage > 0.8 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Department Name and Status Indicator
            HStack {
                TruncatedTextWithTooltip(
                    department.name,
                    font: DesignSystem.Typography.callout,
                    fontWeight: .semibold,
                    foregroundColor: .primary,
                    lineLimit: 1
                )
                
                Spacer()
                
                Circle()
                    .fill(progressColor)
                    .frame(width: 8, height: 8)
            }
            
            // Budget Information - Compact Layout
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                // Allocated Budget
                HStack {
                    Text("Allocated:")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(department.allocatedBudget))
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                // Approved Amount
                HStack {
                    Text("Approved:")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(department.approvedAmount))
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                // Remaining Budget
                HStack {
                    Text("Remaining:")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(department.remainingAmount))
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.semibold)
                        .foregroundColor(department.remainingAmount >= 0 ? .green : .red)
                }
            }
            
            // Progress Bar
            ProgressView(value: min(department.spentPercentage, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .scaleEffect(y: 0.8)
            
            // Utilization Percentage
            HStack {
                Text("\(Int(department.spentPercentage * 100))% utilized")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if department.spentPercentage > 1.0 {
                    Text("Over budget!")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(width: 280)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

private struct EnhancedDepartmentRow: View {
    let name: String
    let allocatedBudget: Double
    let approvedAmount: Double
    let remainingBudget: Double
    let spentPercentage: Double
    
    var formattedAllocatedBudget: String {
        formatCurrency(allocatedBudget)
    }
    
    var formattedApprovedAmount: String {
        formatCurrency(approvedAmount)
    }
    
    var formattedRemainingBudget: String {
        formatCurrency(remainingBudget)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0.00"
    }
    
    var progressColor: Color {
        if spentPercentage > 1.0 {
            return .red
        } else if spentPercentage > 0.8 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            // Department Name and Status
            HStack {
                TruncatedTextWithTooltip(
                    name,
                    font: DesignSystem.Typography.callout,
                    fontWeight: .semibold,
                    foregroundColor: .primary,
                    lineLimit: 1
                )
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(progressColor)
                    .frame(width: 8, height: 8)
            }
            
            // Budget Information
            VStack(spacing: DesignSystem.Spacing.extraSmall) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ALLOCATED")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(formattedAllocatedBudget)
                            .font(DesignSystem.Typography.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text("APPROVED")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(formattedApprovedAmount)
                            .font(DesignSystem.Typography.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("REMAINING")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(formattedRemainingBudget)
                            .font(DesignSystem.Typography.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(remainingBudget >= 0 ? .green : .red)
                    }
                }
                
                // Progress bar
                ProgressView(value: min(spentPercentage, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                    .scaleEffect(y: 0.8)
                
                // Percentage text
                HStack {
                    Text("\(Int(spentPercentage * 100))% utilized")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if spentPercentage > 1.0 {
                        Text("Over budget!")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}

private struct EmptyStateRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(DesignSystem.Typography.title3)
                .symbolRenderingMode(.hierarchical)
            
            Text(text)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.small)
    }
}

private struct ProjectHeaderView: View {
    let project: Project
    @State private var managerName: String?
    @State private var managerPhone: String?
    @State private var isLoadingManager = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                    TruncatedTextWithTooltip(
                        project.name,
                        font: DesignSystem.Typography.largeTitle,
                        foregroundColor: .primary,
                        lineLimit: 2
                    )
                    
//                    // Description
//                    if !project.description.isEmpty {
//                        Text(project.description)
//                            .font(DesignSystem.Typography.body)
//                            .foregroundColor(.secondary)
//                            .fixedSize(horizontal: false, vertical: true)
//                            .padding(.top, DesignSystem.Spacing.extraSmall)
//                    }
                    
                    // Location and Client
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        if !project.location.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(project.location)
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !project.client.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(project.client)
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.extraSmall)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small) {
                    StatusViewDetial(status: project.statusType)
                    
                    Spacer()
                    // Project Manager Section
                    if let managerId = project.managerIds.first {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Project Manager")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            if isLoadingManager {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let name = managerName {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(name)
                                        .font(DesignSystem.Typography.callout)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    if let phone = managerPhone {
                                        Text(phone)
                                            .font(DesignSystem.Typography.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                Text("Not found")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.extraSmall)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .onAppear {
            if let managerId = project.managerIds.first {
                Task {
                    await fetchManagerDetails(managerId: managerId)
                }
            }
        }
    }
    
    private func fetchManagerDetails(managerId: String) async {
        await MainActor.run {
            isLoadingManager = true
        }
        
        do {
            let db = Firestore.firestore()
            var cleanManagerId = managerId.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove +91 prefix if present
            if cleanManagerId.hasPrefix("+91") {
                cleanManagerId = String(cleanManagerId.dropFirst(3))
            }
            
            // Try to fetch user document using phone number as document ID
            let userDoc = try await db.collection("users").document(cleanManagerId).getDocument()
            
            if userDoc.exists {
                if let userData = try? userDoc.data(as: User.self) {
                    await MainActor.run {
                        self.managerName = userData.name
                        self.managerPhone = userData.phoneNumber
                        self.isLoadingManager = false
                    }
                    return
                }
                
                // Fallback: try to get name and phoneNumber from document data directly
                let data = userDoc.data()
                if let name = data?["name"] as? String {
                    let phone = data?["phoneNumber"] as? String ?? cleanManagerId
                    await MainActor.run {
                        self.managerName = name
                        self.managerPhone = phone
                        self.isLoadingManager = false
                    }
                    return
                }
            }
            
            // If not found, try querying by phoneNumber field
            let querySnapshot = try await db.collection("users")
                .whereField("phoneNumber", isEqualTo: cleanManagerId)
                .limit(to: 1)
                .getDocuments()
            
            if let firstDoc = querySnapshot.documents.first {
                if let userData = try? firstDoc.data(as: User.self) {
                    await MainActor.run {
                        self.managerName = userData.name
                        self.managerPhone = userData.phoneNumber
                        self.isLoadingManager = false
                    }
                    return
                }
                
                // Fallback: access raw data
                let data = firstDoc.data()
                if let name = data["name"] as? String {
                    let phone = data["phoneNumber"] as? String ?? cleanManagerId
                    await MainActor.run {
                        self.managerName = name
                        self.managerPhone = phone
                        self.isLoadingManager = false
                    }
                    return
                }
            }
            
            // If still not found, use managerId as fallback
            await MainActor.run {
                self.managerName = nil
                self.managerPhone = cleanManagerId
                self.isLoadingManager = false
            }
        } catch {
            print("Error fetching manager details: \(error)")
            await MainActor.run {
                self.isLoadingManager = false
            }
        }
    }
}

private struct InfoRowDetial: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(label)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(value)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}

// MARK: - Team Members Row with Floating Dropdown
private struct TeamMembersRow: View {
    let teamMembers: [String]
    @Binding var isDropdownVisible: Bool
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isDropdownVisible.toggle()
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: "person.2.circle.fill")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(.mint)
                    .frame(width: 28, height: 28)
                    .symbolRenderingMode(.hierarchical)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                    Text("Team Members")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text("\(teamMembers.count) \(teamMembers.count == 1 ? "member" : "members")")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: isDropdownVisible ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, DesignSystem.Spacing.extraSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Team Member Detail Model
private struct TeamMemberDetail: Identifiable {
    let id = UUID()
    let phoneNumber: String
    let name: String?
}

// MARK: - Team Members Dropdown Overlay
private struct TeamMembersDropdownOverlay: View {
    let teamMembers: [String]
    @Binding var isVisible: Bool
    @State private var teamMemberDetails: [TeamMemberDetail] = []
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Background overlay to dismiss on tap outside
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    HapticManager.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isVisible = false
                    }
                }
            
            // Dropdown card - positioned in center
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Team Members")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isVisible = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(DesignSystem.Spacing.medium)
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                // Content
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(DesignSystem.Spacing.large)
                        Spacer()
                    }
                } else if teamMemberDetails.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No team members")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.large)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(teamMemberDetails) { detail in
                                TeamMemberDropdownRow(detail: detail)
                                
                                if detail.id != teamMemberDetails.last?.id {
                                    Divider()
                                        .padding(.leading, DesignSystem.Spacing.medium + 28 + DesignSystem.Spacing.medium)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: min(400, CGFloat(teamMemberDetails.count) * 70))
                }
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(DesignSystem.CornerRadius.large)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .frame(width: UIScreen.main.bounds.width - (DesignSystem.Spacing.medium * 4))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onAppear {
            if teamMemberDetails.isEmpty {
                Task {
                    await loadTeamMemberDetails()
                }
            }
        }
    }
    
    private func loadTeamMemberDetails() async {
        await MainActor.run {
            isLoading = true
        }
        
        var details: [TeamMemberDetail] = []
        let db = Firestore.firestore()
        
        for memberId in teamMembers {
            var cleanMemberId = memberId.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove +91 prefix if present
            if cleanMemberId.hasPrefix("+91") {
                cleanMemberId = String(cleanMemberId.dropFirst(3))
            }
            
            do {
                // Try to fetch user document using phone number as document ID
                let userDoc = try await db.collection("users").document(cleanMemberId).getDocument()
                
                if userDoc.exists {
                    if let userData = try? userDoc.data(as: User.self) {
                        details.append(TeamMemberDetail(
                            phoneNumber: userData.phoneNumber,
                            name: userData.name
                        ))
                        continue
                    }
                    
                    // Fallback: try to get name from document data directly
                    let data = userDoc.data()
                    if let name = data?["name"] as? String {
                        let phone = data?["phoneNumber"] as? String ?? cleanMemberId
                        details.append(TeamMemberDetail(
                            phoneNumber: phone,
                            name: name
                        ))
                        continue
                    }
                }
                
                // If not found, try querying by phoneNumber field
                let querySnapshot = try await db.collection("users")
                    .whereField("phoneNumber", isEqualTo: cleanMemberId)
                    .limit(to: 1)
                    .getDocuments()
                
                if let firstDoc = querySnapshot.documents.first {
                    if let userData = try? firstDoc.data(as: User.self) {
                        details.append(TeamMemberDetail(
                            phoneNumber: userData.phoneNumber,
                            name: userData.name
                        ))
                        continue
                    }
                    
                    let data = firstDoc.data()
                    if let name = data["name"] as? String {
                        let phone = data["phoneNumber"] as? String ?? cleanMemberId
                        details.append(TeamMemberDetail(
                            phoneNumber: phone,
                            name: name
                        ))
                        continue
                    }
                }
                
                // If still not found, use memberId as fallback
                details.append(TeamMemberDetail(
                    phoneNumber: cleanMemberId,
                    name: nil
                ))
            } catch {
                print("Error fetching team member details: \(error)")
                details.append(TeamMemberDetail(
                    phoneNumber: cleanMemberId,
                    name: nil
                ))
            }
        }
        
        await MainActor.run {
            self.teamMemberDetails = details
            self.isLoading = false
        }
    }
}

// MARK: - Team Member Dropdown Row
private struct TeamMemberDropdownRow: View {
    let detail: TeamMemberDetail
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "person.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                if let name = detail.name, !name.isEmpty {
                    Text(name)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Text(detail.phoneNumber)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.medium)
        .contentShape(Rectangle())
    }
}



// You would also need the StatusView from our previous conversations
// Here it is for completeness:
private struct StatusViewDetial: View {
    let status: ProjectStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(status.color).frame(width: 8, height: 8)
            Text(status.rawValue.capitalized)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(status.color.opacity(0.15))
        .foregroundColor(status.color.darker(by: 10))
        .clipShape(Capsule())
    }
}

// MARK: - Phase Request Form View
private struct PhaseRequestFormView: View {
    let projectId: String
    let phaseId: String
    let phaseName: String
    let phaseEndDate: Date?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var viewModel = PhaseRequestViewModel()
    @State private var description: String = ""
    @State private var extensionDate: Date
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(projectId: String, phaseId: String, phaseName: String, phaseEndDate: Date?) {
        self.projectId = projectId
        self.phaseId = phaseId
        self.phaseName = phaseName
        self.phaseEndDate = phaseEndDate
        
        // Initialize extensionDate to phaseEndDate + 1 day if available, otherwise Date() + 1 day
        if let endDate = phaseEndDate,
           let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: endDate) {
            _extensionDate = State(initialValue: nextDay)
        } else if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            _extensionDate = State(initialValue: nextDay)
        } else {
            _extensionDate = State(initialValue: Date())
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }
    
    private var isFormValid: Bool {
        let comparisonDate = phaseEndDate ?? Date()
        return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        extensionDate > comparisonDate
    }
    
    private var minimumDate: Date {
        if let endDate = phaseEndDate,
           let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: endDate) {
            return nextDay
        }
        return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
    
    private var dateRange: PartialRangeFrom<Date> {
        minimumDate...
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phase")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(phaseName)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Phase Information")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                            )
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Request Details")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } footer: {
                    Text("Please provide a detailed reason for requesting a phase extension.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extend Phase To")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                        
                        DatePicker(
                            "Select extension date",
                            selection: $extensionDate,
                            in: dateRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("The phase will be extended to this date if approved")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Extension Date")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    submitButtonView
                }
            }
            .navigationTitle("Request Override")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Request", isPresented: $showAlert) {
                Button("OK") {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var submitButtonView: some View {
        Button(action: {
            submitRequest()
        }) {
            HStack {
                Spacer()
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Send Request")
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
        }
        .disabled(!isFormValid || isSubmitting)
        .frame(maxWidth: .infinity)
        .background(buttonBackgroundColor)
        .cornerRadius(10)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }
    
    private var buttonBackgroundColor: Color {
        isFormValid ? Color.red : Color.gray
    }
    
    private func submitRequest() {
        guard isFormValid else { return }
        
        isSubmitting = true
        HapticManager.impact(.medium)
        
        Task {
            do {
                let formattedDate = dateFormatter.string(from: extensionDate)
                
                // Get customerId from authService
                guard let customerId = authService.currentCustomerId else {
                    await MainActor.run {
                        isSubmitting = false
                        alertMessage = "Customer ID not found. Please log in again."
                        showAlert = true
                    }
                    return
                }
                
                try await viewModel.submitRequest(
                    projectId: projectId,
                    phaseId: phaseId,
                    phaseName: phaseName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    extensionDate: formattedDate,
                    customerId: customerId
                )
                
                await MainActor.run {
                    isSubmitting = false
                    alertMessage = "Request submitted successfully!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    alertMessage = "Failed to submit request: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Phase Request ViewModel
@MainActor
class PhaseRequestViewModel: ObservableObject {
    private let db = Firestore.firestore()
    
    func submitRequest(
        projectId: String,
        phaseId: String,
        phaseName: String,
        description: String,
        extensionDate: String,
        customerId: String
    ) async throws {
        // Get current user UID (userID) and phone number
        guard let currentUserUID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        guard var currentUserPhone = Auth.auth().currentUser?.phoneNumber else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        if currentUserPhone.hasPrefix("+91") {
            currentUserPhone = currentUserPhone.replacingOccurrences(of: "+91", with: "")
        }
        
        // Store request in phases/{phaseId}/requests subcollection
        let requestRef = FirebasePathHelper.shared
            .phasesCollection(customerId: customerId, projectId: projectId)
            .document(phaseId)
            .collection("requests")
            .document()
        
        let requestData: [String: Any] = [
            "id": requestRef.documentID,
            "reason": description, // Reason for the request
            "extendedDate": extensionDate, // Extended date (dd/MM/yyyy format)
            "status": PhaseRequest.RequestStatus.pending.rawValue, // pending, accepted, rejected
            "userID": currentUserPhone, // User UID who requested
            "createdAt": Timestamp() // Timestamp when request was created
        ]
        
        try await requestRef.setData(requestData)
        
        // Post notification to refresh if needed
        NotificationCenter.default.post(name: NSNotification.Name("PhaseRequestSubmitted"), object: nil)
    }
}

// MARK: - User Phase Request Status ViewModel
@MainActor
class UserPhaseRequestStatusViewModel: ObservableObject {
    @Published var userRequests: [UserPhaseRequestStatus] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadUserRequests(phaseId: String, projectId: String, customerId: String?) async {
        guard let customerId = customerId,
              var currentUserUID = Auth.auth().currentUser?.phoneNumber else {
            errorMessage = "User not logged in"
            return
        }
        
        if currentUserUID.hasPrefix("+91") {
            currentUserUID = currentUserUID.replacingOccurrences(of: "+91", with: "")
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let requestsSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phaseId)
                .collection("requests")
                .whereField("userID", isEqualTo: currentUserUID)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            var requests: [UserPhaseRequestStatus] = []
            
            for requestDoc in requestsSnapshot.documents {
                let requestData = requestDoc.data()
                let requestId = requestDoc.documentID
                
                if let reason = requestData["reason"] as? String,
                   let status = requestData["status"] as? String,
                   let extendedDate = requestData["extendedDate"] as? String,
                   let createdAt = requestData["createdAt"] as? Timestamp {
                    
                    let requestStatus = UserPhaseRequestStatus(
                        id: requestId,
                        reason: reason,
                        status: status,
                        extendedDate: extendedDate,
                        createdAt: createdAt
                    )
                    requests.append(requestStatus)
                }
            }
            
            self.userRequests = requests
            self.isLoading = false
            
        } catch {
            self.errorMessage = "Failed to load requests: \(error.localizedDescription)"
            self.isLoading = false
            print("Error loading user requests: \(error)")
        }
    }
}

// MARK: - User Phase Request Status Model
struct UserPhaseRequestStatus: Identifiable {
    let id: String
    let reason: String
    let status: String // "PENDING", "APPROVED", "REJECTED"
    let extendedDate: String
    let createdAt: Timestamp
    
    var statusColor: Color {
        switch status {
        case "PENDING": return .orange
        case "APPROVED": return .green
        case "REJECTED": return .red
        default: return .gray
        }
    }
    
    var statusIcon: String {
        switch status {
        case "PENDING": return "clock.fill"
        case "APPROVED": return "checkmark.circle.fill"
        case "REJECTED": return "xmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
}

// MARK: - User Phase Request Status View
struct UserPhaseRequestStatusView: View {
    let phaseId: String
    let phaseName: String
    let projectId: String
    let customerId: String?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UserPhaseRequestStatusViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading requests...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.userRequests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Requests Found")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("You haven't submitted any requests for this phase yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            HStack {
                                Text("Total Requests")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(viewModel.userRequests.count)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        } header: {
                            Text("Request Summary")
                                .textCase(.none)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Section {
                            ForEach(viewModel.userRequests) { request in
                                RequestStatusRow(request: request)
                            }
                        } header: {
                            Text("Request Details")
                                .textCase(.none)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Request Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadUserRequests(
                    phaseId: phaseId,
                    projectId: projectId,
                    customerId: customerId
                )
            }
        }
    }
}

// MARK: - Request Status Row
private struct RequestStatusRow: View {
    let request: UserPhaseRequestStatus
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status Badge
            HStack {
                Image(systemName: request.statusIcon)
                    .foregroundColor(request.statusColor)
                    .font(.caption)
                
                Text(request.status)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(request.statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(request.statusColor.opacity(0.15))
                    .cornerRadius(8)
                
                Spacer()
                
                Text(dateFormatter.string(from: request.createdAt.dateValue()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Reason
            VStack(alignment: .leading, spacing: 4) {
                Text("Reason")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                Text(request.reason)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Extension Date
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Text("Extend to: \(request.extendedDate)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview Provider

struct ProjectDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Wrap in a NavigationView to see the title and layout correctly
        NavigationView {
            // Use the first item from our sample data for the preview
            ProjectDetailView(project: Project.sampleData[0], role: .ADMIN, phoneNumber: "1234567890")
        }
    }
}
