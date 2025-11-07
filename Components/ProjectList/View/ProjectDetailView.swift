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
    @State private var showingAddExpense = false
    @State private var showingChats = false
    @State private var showingNotifications = false
    @ObservedObject private var viewModel: ProjectDetailViewModel
    let role: UserRole?
    let phoneNumber: String
    let customerId: String?
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var authService: FirebaseAuthService


    init(project: Project, role: UserRole? = nil, phoneNumber: String = "", customerId: String? = nil){
        self.project = project
        self.role = role
        self.phoneNumber = phoneNumber
        self.customerId = customerId
        self._viewModel = ObservedObject(wrappedValue: ProjectDetailViewModel(project: project, CurrentUserPhone: phoneNumber, customerId: customerId))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                // MARK: - Main Header Card
                ProjectHeaderView(project: project)
                    .cardStyle()
                    .padding(.horizontal, DesignSystem.Spacing.medium)

                // MARK: - Key Info Card
                KeyInformationView(project: project, viewModel: viewModel)
                    .cardStyle()
                    .padding(.horizontal, DesignSystem.Spacing.medium)

                // MARK: - Team Members Card
                TeamMembersView(teamMembers: project.teamMembers)
                    .cardStyle()
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                
                // MARK: - Phase Budget Breakdown
                PhaseBreakdownView(project: project, viewModel: viewModel)
                    .cardStyle()
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                
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
            }
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
    
    var totalApprovedAmount: Double {
        viewModel.approvedExpensesByDepartment.values.reduce(0, +)
    }
    
    var totalRemainingBudget: Double {
        project.budget - totalApprovedAmount
    }
    
    var body: some View {
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
                
                InfoRowDetial(
                    icon: "calendar.circle.fill",
                    label: "Project Timeline",
                    value: project.dateRangeFormatted,
                    iconColor: .purple
                )
                
                Divider()
                
                InfoRowDetial(
                    icon: "person.crop.circle.badge.checkmark",
                    label: "Project Manager",
                    value: project.managerIds.first ?? "",
                    iconColor: .indigo
                )
                
                Divider()
                
                InfoRowDetial(
                    icon: "person.2.circle.fill",
                    label: "Team Size",
                    value: "\(project.teamMembers.count) members",
                    iconColor: .mint
                )
            }
            
        }
        .padding(DesignSystem.Spacing.medium)
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
    @State private var showingAllPhases = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                SectionHeader(title: "Phase Budget Breakdown")
                Spacer()
                if viewModel.phases.count > 1 {
                    Button(action: {
                        showingAllPhases = true
                    }) {
                        Text("View All Phases")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            
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
                VStack(spacing: DesignSystem.Spacing.jumbo) {
                    ForEach(Array(viewModel.currentPhases.enumerated()), id: \.element.id) { index, phase in
                        CurrentPhaseView(
                            phase: phase,
                            projectId: project.id ?? "",
                            phaseExtensionMap: viewModel.phaseExtensionMap
                        )
                    }
                }
            } else {
                EmptyStateRow(
                    icon: "calendar.badge.clock",
                    text: "No active phase at the moment"
                )
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .sheet(isPresented: $showingAllPhases) {
            AllPhasesSheetView(
                currentPhases: viewModel.currentPhases,
                expiredPhases: viewModel.expiredPhases,
                projectId: project.id ?? "",
                phaseExtensionMap: viewModel.phaseExtensionMap
            )
        }
    }
}

private struct CurrentPhaseView: View {
    let phase: ProjectDetailViewModel.PhaseInfo
    let projectId: String
    let phaseExtensionMap: [String: Bool]
    
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
                        Text(phase.phaseName)
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
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
                            Text("In Progress")
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
                    phaseName: phase.phaseName
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
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL BUDGET")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
                        Text(formatCurrency(phase.totalBudget))
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
                        
                        Text(formatCurrency(phase.approvedAmount))
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
                        
                        Text(formatCurrency(phase.remainingAmount))
                            .font(DesignSystem.Typography.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(phase.remainingAmount >= 0 ? .green : .red)
                    }
                }
                
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
                Text(department.name)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
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
            List {
                // Current Phases Section
                if !currentPhases.isEmpty {
                    Section {
                        ForEach(currentPhases) { phase in
                            ProjectDetailPhaseCardView(
                                phase: phase,
                                isInProgress: true,
                                projectId: projectId,
                                phaseExtensionMap: phaseExtensionMap
                            )
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Current Phases")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Expired Phases Section
                if !expiredPhases.isEmpty {
                    Section {
                        ForEach(expiredPhases) { phase in
                            ProjectDetailPhaseCardView(
                                phase: phase,
                                isInProgress: false,
                                projectId: projectId,
                                phaseExtensionMap: phaseExtensionMap
                            )
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Completed Phases")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Empty State
                if allPhases.isEmpty {
                    Section {
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
                    }
                }
            }
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
                        Text(phase.phaseName)
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
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
                    phaseName: phase.phaseName
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
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL BUDGET")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(formatCurrency(phase.totalBudget))
                        .font(DesignSystem.Typography.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .center, spacing: 4) {
                    Text("APPROVED")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(formatCurrency(phase.approvedAmount))
                        .font(DesignSystem.Typography.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("REMAINING")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(formatCurrency(phase.remainingAmount))
                        .font(DesignSystem.Typography.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(phase.remainingAmount >= 0 ? .green : .red)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
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
                Text(department.name)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
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
                Text(name)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                    Text(project.name)
                        .font(DesignSystem.Typography.largeTitle)
                        .foregroundColor(.primary)
                    
                    Text("Tracura")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusViewDetial(status: project.statusType)
            }
            
            if !project.description.isEmpty {
                Text(project.description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignSystem.Spacing.medium)
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

private struct TeamMembersView: View {
    let teamMembers: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            SectionHeader(title: "Team Members")
            
            if teamMembers.isEmpty {
                EmptyStateRow(
                    icon: "person.2.badge.plus",
                    text: "No team members assigned"
                )
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.small) {
                    ForEach(teamMembers, id: \.self) { memberId in
                        TeamMemberRow(memberId: memberId)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
    }
}

private struct TeamMemberRow: View {
    let memberId: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.blue)
                .font(DesignSystem.Typography.title3)
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(memberId)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(.primary)
                
                Text("Team Member")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Color.secondary.opacity(0.6))
                .font(DesignSystem.Typography.caption1)
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
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
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var viewModel = PhaseRequestViewModel()
    @State private var description: String = ""
    @State private var extensionDate: Date = Date()
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }
    
    private var isFormValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        extensionDate > Date()
    }
    
    private var minimumDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
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
