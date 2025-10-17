//
//  DashboardView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import SwiftUI
import FirebaseFirestore

struct DashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DashboardViewModel
    @State private var showingNotifications = false
    @State private var showingPendingApprovals = false
    @State private var selectedDepartment: String? = nil
    @State private var showingReportSheet = false
    @State private var showingActionMenu = false
    @State private var showingAddExpense = false
    @State private var showingAnalytics = false
    @State private var showingDelegate = false
    @State private var showingChats = false
    @State private var showingDepartmentDetail = false
    @State private var selectedDepartmentForDetail: String? = nil
    @State private var showingTeamMembersDetail = false
    @State private var showingAnonymousExpensesDetail = false
    @StateObject private var ProjectDetialViewModel : ProjectDetailViewModel
    let role: UserRole?
    let phoneNumber: String
    
    // Accept a single project as parameter
    var project: Project?
    
    // Permanent approver
    
    @State private var permanentApproverName: String?
    
    // Temporary Approver Properties
    @State private var tempApproverName: String?
    @State private var tempApproverEndDate: Date?
    
    // Date formatter for temp approver end date
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
    
    init(project: Project? = nil, role: UserRole? = nil, phoneNumber: String = "") {
        self.project = project
        self.role = role
        self.phoneNumber = phoneNumber
        self._viewModel = StateObject(wrappedValue: DashboardViewModel(project: project, phoneNumber: phoneNumber))
        self._ProjectDetialViewModel = StateObject(wrappedValue: ProjectDetailViewModel(project: project ?? Project.sampleData[0], CurrentUserPhone: phoneNumber))
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
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.large) {
                        // Project Overview Section
                        if let project = project {
                            projectOverviewSection
                        }
                        
                        // Department Budget Cards - Enhanced
                        departmentBudgetSection
                        
                        // Enhanced Charts Section
                        chartsSection
                        
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.bottom, DesignSystem.Spacing.extraLarge)
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
                                    
                                    ActionMenuButton(icon: "plus.circle.fill", title: "Add Expense", color: Color.green) {
                                        showingAddExpense = true
                                        showingActionMenu = false
                                        HapticManager.selection()
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

                // Notification popup overlay
                if showingNotifications {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                showingNotifications = false
                            }
                        }
                    
                    // Responsive notification popup
                    VStack {
                        HStack {
                            Spacer()
                            
                            if let project = project{
                                NotificationsView(showingPendingApprovals: $showingPendingApprovals, project: project, role: role, phoneNumber: phoneNumber)
                                    .frame(
                                        width: min(320, geometry.size.width - 32),
                                        height: min(450, geometry.size.height * 0.6)
                                    )
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                                    .padding(.trailing, 16)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                                        removal: .scale(scale: 0.95).combined(with: .opacity)
                                    ))
                                    .onTapGesture { }  // Prevent tap from dismissing
                            }
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
                    Text(project?.name ?? "Project Dashboard")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(project?.statusType.rawValue ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    // Edit Button
                    if let project = project, role == .ADMIN{
                        NavigationLink(destination: AdminProjectDetailView(project: project)) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Notification Button
                    Button {
                        HapticManager.impact(.light)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingNotifications.toggle()
                        }
                    } label: {
                        ZStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.primary)
                            
                            if viewModel.pendingNotifications > 0 {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Text("\(viewModel.pendingNotifications)")
                                            .font(.system(size: 10))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 10, y: -10)
                            }
                        }
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
            if let department = selectedDepartmentForDetail, let project = project {
                DepartmentBudgetDetailView(
                    department: department,
                    projectId: project.id ?? "",
                    role: role,
                    phoneNumber: phoneNumber
                )
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingTeamMembersDetail) {
            if let project = project {
                TeamMembersDetailView(project: project)
                    .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingAnonymousExpensesDetail) {
            if let project = project {
                AnonymousExpensesDetailView(project: project)
                    .presentationDetents([.large])
            }
        }
        .onAppear {
            if let projectId = project?.id{
                viewModel.loadDashboardData()
            }
            Task {
                await fetchTempApproverData()
            }
        }
        .onChange(of: project) { _ in
            viewModel.updateProject(project)
            Task {
                await fetchTempApproverData()
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.medium) {
                if let tempApproverName = tempApproverName, let tempApproverEndDate = tempApproverEndDate {
                    TempApproverStatsCard(
                        approverName: tempApproverName,
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
                
                TotalBudgetCard(viewModel: viewModel)
                
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
                            Text("\(project?.teamMembers.count ?? 0)")
                                .font(DesignSystem.Typography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                            
                            Text("Team Members")
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
                
                ProjectStatsCard(
                    title: "Departments",
                    value: "\(project?.departments.count ?? 0)",
                    icon: "folder.fill",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Enhanced Department Budget Section
    private var departmentBudgetSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Department Budgets")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Across All Projects")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(8)
            }
            
            if viewModel.departmentBudgets.isEmpty {
                // Empty state for departments
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("No Department Data")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text("Department budgets will appear here once projects with department breakdowns are added.")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.large)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(DesignSystem.CornerRadius.medium)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.medium) {
                    ForEach(viewModel.departmentBudgets, id: \.department) { budget in
                        EnhancedDepartmentBudgetCard(
                            budget: budget,
                            isSelected: selectedDepartment == budget.department,
                            viewModel: ProjectDetialViewModel
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedDepartment = selectedDepartment == budget.department ? nil : budget.department
                            }
                            HapticManager.selection()
                        }
                        .onLongPressGesture {
                            if budget.department == "Other Expenses" {
                                // Show anonymous expenses detail
                                showingAnonymousExpensesDetail = true
                            } else {
                                selectedDepartmentForDetail = budget.department
                                showingDepartmentDetail = true
                            }
                            HapticManager.impact(.medium)
                        }
                    }
                }
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
                    .background(Color(.tertiarySystemFill))
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
    
    // MARK: - Department Legend Row
    private func departmentLegendRow(budget: DepartmentBudget, index: Int) -> some View {
        // Use max of totalBudget and approvedBudget for calculation to include "Other Expenses"
        let totalBudget = viewModel.departmentBudgets.reduce(0) { $0 + max($1.totalBudget, $1.approvedBudget) }
        let budgetValue = max(budget.totalBudget, budget.approvedBudget)
        let percentage = Int((budgetValue / totalBudget) * 100)
        
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
                Text(budget.department)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
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
            tempApproverName = nil
            tempApproverEndDate = nil
            return
        }
        
        do {
            let db = Firestore.firestore()
            
            // Fetch user name from users collection
            let userDocument = try await db
                .collection(FirebaseCollections.users)
                .document(tempApproverID)
                .getDocument()
            
            if userDocument.exists, let user = try? userDocument.data(as: User.self) {
                tempApproverName = user.name
                
                // Always use the temp approver's phone number for the query
                // This ensures temp approver details show for all users (admin, approver, etc.)
                let approverPhone = user.phoneNumber
                
                // Fetch temp approver end date from subcollection
                let tempApproverSnapshot = try await db
                    .collection("projects_ios")
                    .document(project.id ?? "")
                    .collection("tempApprover")
                    .whereField("approverId", isEqualTo: approverPhone)
                    .whereField("status", isEqualTo: "active")
                    .whereField("endDate", isGreaterThanOrEqualTo: Timestamp(date: Date()))
                    .whereField("startDate", isLessThanOrEqualTo: Timestamp(date: Date()))
                    .limit(to: 1)
                    .getDocuments()
                
                if let tempApproverDoc = tempApproverSnapshot.documents.first,
                   let tempApprover = try? tempApproverDoc.data(as: TempApprover.self) {
                    tempApproverEndDate = tempApprover.endDate
                } else {
                    tempApproverEndDate = nil
                }
            } else {
                tempApproverName = nil
                tempApproverEndDate = nil
            }
        } catch {
            print("Error fetching temp approver data: \(error)")
            tempApproverName = nil
            tempApproverEndDate = nil
        }
    }
    
//    private func fetchApproverData() async {
//        guard let project = project else {
//            return
//        }
//        
//        do {
//            let db = Firestore.firestore()
//            
//            // Fetch user name from users collection
//            let userDocument = try await db
//                .collection(FirebaseCollections.users)
//                .document(project.managerId)
//                .getDocument()
//            
//            if userDocument.exists, let user = try? userDocument.data(as: User.self) {
//                tempApproverName = user.name
//                
//                // Fetch temp approver end date from subcollection
//                let tempApproverSnapshot = try await db
//                    .collection("projects_ios")
//                    .document(project.id ?? "")
//                    .collection("tempApprover")
//                    .whereField("approverId", isEqualTo: user.phoneNumber)
//                    .limit(to: 1)
//                    .getDocuments()
//                
//                if let tempApproverDoc = tempApproverSnapshot.documents.first,
//                   let tempApprover = try? tempApproverDoc.data(as: TempApprover.self) {
//                    tempApproverEndDate = tempApprover.endDate
//                } else {
//                    tempApproverEndDate = nil
//                }
//            } else {
//                tempApproverName = nil
//                tempApproverEndDate = nil
//            }
//        } catch {
//            print("Error fetching temp approver data: \(error)")
//            tempApproverName = nil
//            tempApproverEndDate = nil
//        }
//    }
    
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
                
                Text("₹\(budget.approvedBudget.formattedCurrency) / ₹\(budget.totalBudget.formattedCurrency)")
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
                        
                        Text("\(budget.totalBudget.formattedCurrency)")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                // Spent amount (Approved expenses)
                HStack {
                    Text("Spent:")
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

// MARK: - Temp Approver Stats Card
struct TempApproverStatsCard: View {
    let approverName: String
    let endDate: Date
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: "person.badge.clock.fill")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(.orange)
                    .symbolRenderingMode(.hierarchical)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Temp Approver")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                
                Text(approverName)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("Until: \(endDate, formatter: dateFormatter)")
                    .font(DesignSystem.Typography.caption2)
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.gradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.hierarchical)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
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
        }
        .buttonStyle(.plain)
        .frame(width: 200)
    }
}

// MARK: - Total Budget Card
struct TotalBudgetCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
//            HStack {
//                Image(systemName: "indianrupeesign.circle.fill")
//                    .font(DesignSystem.Typography.title3)
//                    .foregroundColor(.orange)
//                    .symbolRenderingMode(.hierarchical)
//                
//                Spacer()
//            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.totalProjectBudgetFormatted)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                
                Text("Total Budget")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                
                // Remaining amount
                Text("Remaining: \(viewModel.remainingBudget.formattedCurrency)")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(viewModel.remainingBudget >= 0 ? .green : .red)
                    .fontWeight(.medium)
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
                let expensesSnapshot = try await db.collection("projects_ios")
                    .document(projectId)
                    .collection("expenses")
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

#Preview {
    DashboardView(project: Project.sampleData.first, phoneNumber: "1234567890")
} 
