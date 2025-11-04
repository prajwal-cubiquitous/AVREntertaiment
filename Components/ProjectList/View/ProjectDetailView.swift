//
//  ProjectDetailView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//


// ProjectDetailView.swift
import SwiftUI
import FirebaseFirestore

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
    @EnvironmentObject var navigationManager: NavigationManager


    init(project: Project, role: UserRole? = nil, phoneNumber: String = ""){
        self.project = project
        self.role = role
        self.phoneNumber = phoneNumber
        self._viewModel = ObservedObject(wrappedValue: ProjectDetailViewModel(project: project,CurrentUserPhone :phoneNumber))
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
                VStack(spacing: DesignSystem.Spacing.medium) {
                    ForEach(Array(viewModel.currentPhases.enumerated()), id: \.element.id) { index, phase in
                        CurrentPhaseView(phase: phase)
                        
                        if index < viewModel.currentPhases.count - 1 {
                            Divider()
                        }
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
                expiredPhases: viewModel.expiredPhases
            )
        }
    }
}

private struct CurrentPhaseView: View {
    let phase: ProjectDetailViewModel.PhaseInfo
    
    @State private var isExpanded = false
    
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
                        
                        // In Progress Tag
                        Text("In Progress")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(8)
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
                
                Circle()
                    .fill(progressColor)
                    .frame(width: 10, height: 10)
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
            
            // Department Breakdown
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
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        ForEach(Array(phase.departments.enumerated()), id: \.element.id) { index, department in
                            DepartmentRowView(department: department)
                            
                            if index < phase.departments.count - 1 {
                                Divider()
                            }
                        }
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
                            ProjectDetailPhaseCardView(phase: phase, isInProgress: true)
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
                            ProjectDetailPhaseCardView(phase: phase, isInProgress: false)
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
    @State private var isExpanded = false
    
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
                        
                        // Status Badge
                        Text(isInProgress ? "In Progress" : "Completed")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isInProgress ? Color.blue : Color.gray)
                            .cornerRadius(8)
                    }
                    
                    if let dateRangeText = dateRangeText {
                        Text(dateRangeText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                // Status Indicator
                Circle()
                    .fill(progressColor)
                    .frame(width: 10, height: 10)
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
            
            // Department Breakdown - Expandable
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
                    VStack(spacing: DesignSystem.Spacing.small) {
                        ForEach(phase.departments) { department in
                            DepartmentRowView(department: department)
                            
                            if department.id != phase.departments.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.small)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small)
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
