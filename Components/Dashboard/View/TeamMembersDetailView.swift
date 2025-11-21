//
//  TeamMembersDetailView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/1/25.
//

import SwiftUI
import FirebaseFirestore

struct TeamMembersDetailView: View {
    let project: Project
    let role: UserRole?
    @ObservedObject var stateManager: DashboardStateManager
    @StateObject private var viewModel = TeamMembersDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedMember: User?
    @State private var showingMemberExpenses = false
    @State private var memberToDelete: User?
    @State private var showingDeleteAlert = false
    @State private var showingAddUser = false
    @State private var isDeleting = false
    
    // Use state manager's team members if available, otherwise fall back to viewModel
    private var currentTeamMembers: [User] {
        stateManager.teamMembers.isEmpty ? viewModel.teamMembers : stateManager.teamMembers
    }
    
    private var filteredMembers: [User] {
        var members = currentTeamMembers
        
        // Filter by search text
        if !searchText.isEmpty {
            members = members.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText) ||
                user.phoneNumber.contains(searchText) ||
                user.email?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return members
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search
                searchView
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if currentTeamMembers.isEmpty {
                    emptyView
                } else {
                    membersListView
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Load from state manager if available, otherwise load from Firebase
            if stateManager.teamMembers.isEmpty {
                viewModel.loadTeamMembers(for: project)
            }
            // Sync viewModel with stateManager
            if !stateManager.teamMembers.isEmpty {
                viewModel.updateTeamMembers(stateManager.teamMembers)
            }
        }
        .sheet(isPresented: $showingMemberExpenses) {
            if let member = selectedMember {
                MemberExpensesView(member: member, project: project)
                    .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingAddUser) {
            AddTeamMemberView(project: project, stateManager: stateManager) {
                viewModel.loadTeamMembers(for: project)
            }
            .presentationDetents([.large])
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProjectUpdated"))) { _ in
            // Reload team members when project is updated
            Task {
                if let projectId = project.id,
                   let customerId = try? await FirebasePathHelper.shared.fetchEffectiveUserID() {
                    await stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                    viewModel.updateTeamMembers(stateManager.teamMembers)
                }
            }
        }
        .alert("Remove Team Member", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                memberToDelete = nil
            }
            Button("Remove", role: .destructive) {
                if let member = memberToDelete {
                    Task {
                        await deleteMember(member)
                    }
                }
            }
        } message: {
            if let member = memberToDelete {
                Text("Are you sure you want to remove \(member.name) from this project? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                        .font(.title2)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("TEAM MEMBERS")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\(currentTeamMembers.count) members")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    // Add User Button (only for admin)
                    if role == .ADMIN {
                        Button(action: {
                            HapticManager.selection()
                            showingAddUser = true
                        }) {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                    }
                    
                    // Refresh Button
                    Button(action: {
                        HapticManager.selection()
                        Task {
                            if let projectId = project.id,
                               let customerId = try? await FirebasePathHelper.shared.fetchEffectiveUserID() {
                                await stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                            }
                            viewModel.refreshData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Search View
    private var searchView: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search members...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text("Loading team members...")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.top)
            
            Spacer()
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Team Members")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.top)
            
            Text("Team members will appear here once they are added to the project.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Members List View
    private var membersListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMembers) { member in
                    TeamMemberRowView(
                        member: member,
                        isAdmin: role == .ADMIN,
                        onTap: {
                            selectedMember = member
                            showingMemberExpenses = true
                            HapticManager.selection()
                        },
                        onDelete: {
                            memberToDelete = member
                            showingDeleteAlert = true
                            HapticManager.selection()
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Delete Member
    private func deleteMember(_ member: User) async {
        isDeleting = true
        
        do {
            let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
            guard let projectId = project.id else {
                await MainActor.run {
                    isDeleting = false
                    memberToDelete = nil
                }
                return
            }
            
            // Get member identifier (phone number for regular users, email for admin)
            let memberId = member.role == .ADMIN ? (member.email ?? "") : member.phoneNumber
            
                // Remove member immediately from state manager (before Firebase update)
                stateManager.removeTeamMember(memberId: memberId)
                
                // Remove member from project's teamMembers array
                let projectRef = FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                
                // Get current team members
                let projectDoc = try await projectRef.getDocument()
                if let data = projectDoc.data(),
                   var teamMembers = data["teamMembers"] as? [String] {
                    // Remove the member from the array
                    teamMembers.removeAll { $0 == memberId }
                    
                    // Update the project
                    try await projectRef.updateData([
                        "teamMembers": teamMembers
                    ])
                    
                    // Update state manager with final list
                    await MainActor.run {
                        stateManager.updateTeamMembers(stateManager.teamMembers, memberIds: teamMembers)
                        viewModel.updateTeamMembers(stateManager.teamMembers)
                        isDeleting = false
                        memberToDelete = nil
                        HapticManager.notification(.success)
                        // Notify that project was updated
                        NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
                    }
                }
        } catch {
            print("❌ Error deleting team member: \(error)")
            await MainActor.run {
                isDeleting = false
                memberToDelete = nil
                HapticManager.notification(.error)
            }
        }
    }
}

// MARK: - Team Member Row View
struct TeamMemberRowView: View {
    let member: User
    let isAdmin: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Content area (tappable)
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(member.role.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Text(member.name.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(member.role.color)
                    }
                    
                    // Member Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "phone.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(member.phoneNumber.isEmpty ? (member.email ?? "") : member.phoneNumber)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        
                        if let email = member.email, !email.isEmpty, !member.phoneNumber.isEmpty {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                        
                        // Status indicator
                        HStack {
                            Circle()
                                .fill(member.role.color)
                                .frame(width: 8, height: 8)
                            
                            Text(member.role.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            // Delete button (only for admin) - separate from content area
            if isAdmin {
                Button(action: {
                    HapticManager.selection()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}


// MARK: - Team Members Detail ViewModel
class TeamMembersDetailViewModel: ObservableObject {
    @Published var teamMembers: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadTeamMembers(for project: Project) {
        currentProject = project
        isLoading = true
        errorMessage = nil
        
        Task {
            let db = Firestore.firestore()
            var loadedMembers: [User] = []
            
            // Load team members in parallel
            await withTaskGroup(of: User?.self) { group in
                for memberId in project.teamMembers {
                    group.addTask {
                        await self.fetchUserDetails(userId: memberId, db: db)
                    }
                }
                
                for await member in group {
                    if let member = member {
                        loadedMembers.append(member)
                    }
                }
            }
            
            // Sort members by role (Admin first, then by name)
            loadedMembers.sort { first, second in
                if first.role == .ADMIN && second.role != .ADMIN {
                    return true
                } else if first.role != .ADMIN && second.role == .ADMIN {
                    return false
                } else {
                    return first.name < second.name
                }
            }
            
            await MainActor.run {
                self.teamMembers = loadedMembers
                self.isLoading = false
            }
        }
    }
    
    private func fetchUserDetails(userId: String, db: Firestore) async -> User? {
        do {
            let document = try await db
                .collection("users")
                .document(userId)
                .getDocument()
            
            if document.exists {
                return try document.data(as: User.self)
            }
            return nil
        } catch {
            print("Error fetching user \(userId): \(error)")
            return nil
        }
    }
    
    func refreshData() {
        // This would be called from the refresh button
        // For now, we'll just reload the data
        if let project = currentProject {
            loadTeamMembers(for: project)
        }
    }
    
    func updateTeamMembers(_ members: [User]) {
        self.teamMembers = members
    }
    
    private var currentProject: Project?
    
    func setProject(_ project: Project) {
        self.currentProject = project
    }
}

// MARK: - UserRole Extension
extension UserRole {
    var color: Color {
        switch self {
        case .ADMIN:
            return .red
        case .APPROVER:
            return .orange
        case .USER:
            return .blue
        case .HEAD:
            return .green
        }
    }
}

// MARK: - Member Expenses View
struct MemberExpensesView: View {
    let member: User
    let project: Project
    @StateObject private var viewModel = MemberExpensesViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: ExpenseFilter = .all
    @State private var sortOption: SortOption = .dateDescending
    @State private var showingDateRangePicker = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isDateRangeActive = false
    @State private var searchText = ""
    @State private var selectedExpense: Expense?
    @State private var showingExpenseDetail = false
    
    enum ExpenseFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case approved = "Approved"
        case rejected = "Rejected"
    }
    
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        // Status filter
        switch selectedFilter {
        case .pending:
            expenses = expenses.filter { $0.status == .pending }
        case .approved:
            expenses = expenses.filter { $0.status == .approved }
        case .rejected:
            expenses = expenses.filter { $0.status == .rejected }
        case .all:
            break
        }
        
        // Date range filter
        if isDateRangeActive {
            expenses = expenses.filter { exp in
                let d = exp.createdAt.dateValue()
                return d >= startDate && d <= endDate
            }
        }
        
        // Search filter - search across multiple fields
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            expenses = expenses.filter { expense in
                // Search in description
                expense.description.lowercased().contains(searchLower) ||
                // Search in department
                expense.department.lowercased().contains(searchLower) ||
                // Search in categories
                expense.categoriesString.lowercased().contains(searchLower) ||
                // Search in payment mode
                expense.modeOfPayment.rawValue.lowercased().contains(searchLower) ||
                // Search in status
                expense.status.rawValue.lowercased().contains(searchLower) ||
                // Search in amount (numeric search)
                String(format: "%.0f", expense.amount).contains(searchText) ||
                expense.amountFormatted.lowercased().contains(searchLower) ||
                // Search in date
                expense.date.contains(searchText) ||
                expense.dateFormatted.lowercased().contains(searchLower)
            }
        }
        
        // Sort
        switch sortOption {
        case .dateDescending:
            expenses = expenses.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
        case .dateAscending:
            expenses = expenses.sorted { $0.createdAt.dateValue() < $1.createdAt.dateValue() }
        case .amountDescending:
            expenses = expenses.sorted { $0.amount > $1.amount }
        case .amountAscending:
            expenses = expenses.sorted { $0.amount < $1.amount }
        case .status:
            expenses = expenses.sorted { $0.status.rawValue < $1.status.rawValue }
        }
        
        return expenses
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Unified Filter & Sort
                unifiedFilterMenu
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.expenses.isEmpty {
                    emptyView
                } else if filteredExpenses.isEmpty {
                    emptyFilterView
                } else {
                    expensesListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search expenses by amount, description, department...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // MARK: - Status Picker
                        Section("Status") {
                            Picker("Status", selection: $selectedFilter) {
                                ForEach(ExpenseFilter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue.capitalized)
                                        .tag(filter)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // MARK: - Sort Picker
                        Section("Sort by") {
                            Picker("Sort by", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Label(option.rawValue, systemImage: option.icon)
                                        .tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // MARK: - Date Range (only the picker button)
                        Section("Date Range") {
                            Button {
                                showingDateRangePicker = true
                            } label: {
                                Label("Set Date Range…", systemImage: "calendar.badge.plus")
                            }
                        }
                        
                        // MARK: - Clear Filters
                        if selectedFilter != .all || sortOption != .dateDescending || isDateRangeActive || !searchText.isEmpty {
                            Section {
                                Button("Clear All Filters", role: .destructive) {
                                    selectedFilter = .all
                                    sortOption = .dateDescending
                                    isDateRangeActive = false
                                    searchText = ""
                                }
                            }
                        }
                        
                    } label: {
                        Label("Filter & Sort", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(member.role.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }


        }
        .onAppear {
            // Use phone number instead of ID since submittedBy stores phone number
            viewModel.loadExpenses(for: project, memberPhoneNumber: member.phoneNumber)
        }
        .sheet(isPresented: $showingDateRangePicker) {
            AppleDateRangePickerSheet(
                startDate: $startDate,
                endDate: $endDate,
                isActive: $isDateRangeActive
            )
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(member.role.color.opacity(0.2))
                    .frame(width: 70, height: 70)
                
                Text(member.name.prefix(1).uppercased())
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(member.role.color)
            }
            
            // Name
            Text(member.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Summary Stats
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(viewModel.totalExpenses)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text(viewModel.totalAmount)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Total Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [
                    member.role.color.opacity(0.1),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Unified Filter Menu
    private var unifiedFilterMenu: some View {
        VStack {
//            Menu {
//                // Status Picker
//                Picker("Status", selection: $selectedFilter) {
//                    ForEach(ExpenseFilter.allCases, id: \.self) { filter in
//                        Text(filter.rawValue).tag(filter)
//                    }
//                }
//                .pickerStyle(.menu)
//
//                // Sort Picker
//                Picker("Sort by", selection: $sortOption) {
//                    ForEach(SortOption.allCases, id: \.self) { option in
//                        Label(option.rawValue, systemImage: option.icon).tag(option)
//                    }
//                }
//                .pickerStyle(.menu)
//
//                // Date Range
//                Toggle(isOn: $isDateRangeActive) {
//                    Label("Enable Date Range", systemImage: "calendar")
//                }
//                Button { showingDateRangePicker = true } label: {
//                    Label("Set Date Range…", systemImage: "calendar.badge.plus")
//                }
//
//                // Clear
//                if selectedFilter != .all || isDateRangeActive || sortOption != .dateDescending {
//                    Button("Clear All Filters", role: .destructive) {
//                        selectedFilter = .all
//                        isDateRangeActive = false
//                        sortOption = .dateDescending
//                    }
//                }
//            } label: {
//                Label("Filter & Sort", systemImage: "line.3.horizontal.decrease.circle")
//                    .font(.subheadline)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(member.role.color.opacity(0.12))
//                    .clipShape(RoundedRectangle(cornerRadius: 12))
//            }

            // Totals Summary
            memberTotalsSummary
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
            // Date range now uses native Apple sheet
    }

    private var memberTotalsSummary: some View {
        let approved = viewModel.expenses.filter { $0.status == .approved }.reduce(0.0) { $0 + $1.amount }
        let pending = viewModel.expenses.filter { $0.status == .pending }.reduce(0.0) { $0 + $1.amount }
        let rejected = viewModel.expenses.filter { $0.status == .rejected }.reduce(0.0) { $0 + $1.amount }
        return HStack(spacing: 8) {
            amountBadge(title: "Approved", amount: approved, color: .green)
            Spacer()
            amountBadge(title: "Pending", amount: pending, color: .orange)
            Spacer()
            amountBadge(title: "Rejected", amount: rejected, color: .red)
        }
        .padding(.horizontal, 20)
    }

    private func amountBadge(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            Text(Int(amount).formattedCurrency)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(member.role.color)
            Text("Loading expenses...")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.top)
            Spacer()
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("No Expenses")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top)
            Text("\(member.name) hasn't submitted any expenses yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }
    
    // MARK: - Empty Filter View
    private var emptyFilterView: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Spacer()
            
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            if !searchText.isEmpty {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("No expenses match \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("No \(selectedFilter.rawValue) Expenses")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("No expenses match the selected filter.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Expenses List View
    private var expensesListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredExpenses, id: \.id) { expense in
                    MemberExpenseRowView(
                        expense: expense,
                        onTap: {
                            selectedExpense = expense
                            showingExpenseDetail = true
                        }
                    )
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingExpenseDetail) {
            if let expense = selectedExpense {
                if expense.status == .pending {
                    ExpenseDetailView(expense: expense, role: nil)
                } else {
                    ExpenseDetailReadOnlyView(expense: expense)
                }
            }
        }
    }
}

// MARK: - Member Expenses View Model
@MainActor
class MemberExpensesViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    var totalExpenses: Int {
        expenses.count
    }
    
    var totalAmount: String {
        let total = expenses.reduce(0) { $0 + $1.amount }
        return "\(Int(total).formattedCurrency)"
    }
    
    var customerID: String {
        get async throws {
            try await FirebasePathHelper.shared.fetchEffectiveUserID()
        }
    }
    
    func loadExpenses(for project: Project, memberPhoneNumber: String) {
        guard let projectId = project.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get customer ID
                let customerId = try await customerID
                
                // Build query using FirebasePathHelper
                // Note: submittedBy stores phone number, not user ID
                let snapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("submittedBy", isEqualTo: memberPhoneNumber)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                print("🔍 [MemberExpenses] Found \(snapshot.documents.count) expense documents for member phone: \(memberPhoneNumber)")
                
                var loadedExpenses: [Expense] = []
                for document in snapshot.documents {
                    do {
                        var expense = try document.data(as: Expense.self)
                        expense.id = document.documentID
                        loadedExpenses.append(expense)
                    } catch {
                        print("❌ Error decoding expense document \(document.documentID): \(error)")
                    }
                }
                
                print("✅ [MemberExpenses] Successfully loaded \(loadedExpenses.count) expenses for member phone: \(memberPhoneNumber)")
                
                await MainActor.run {
                    self.expenses = loadedExpenses
                    self.isLoading = false
                }
            } catch {
                print("❌ [MemberExpenses] Error loading expenses: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load expenses: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Member Expense Row View
struct MemberExpenseRowView: View {
    let expense: Expense
    let onTap: () -> Void
    @State private var showingFileViewer = false
    @State private var showingPaymentProofViewer = false
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Status Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(expense.status.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Text(expense.amountFormatted)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                // Description
                TruncatedTextWithTooltip(
                    expense.description,
                    font: .body,
                    foregroundColor: .primary,
                    lineLimit: 1,
                    truncationLength: 30
                )
                
                // Details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(expense.department)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(expense.createdAt.dateValue().formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: expense.modeOfPayment == .cash ? "dollarsign.circle.fill" : "creditcard.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(expense.modeOfPayment.rawValue)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        // Receipt icon
                        if let attachmentURL = expense.attachmentURL, !attachmentURL.isEmpty {
                            FileIconView(
                                fileName: expense.attachmentName,
                                fileURL: attachmentURL,
                                onTap: {
                                    showingFileViewer = true
                                }, isReciept: true
                            )
                            .padding(.leading, 4)
                        }
                        
                        // Payment proof icon
                        if let paymentProofURL = expense.paymentProofURL, !paymentProofURL.isEmpty {
                            FileIconView(
                                fileName: expense.paymentProofName,
                                fileURL: paymentProofURL,
                                onTap: {
                                    showingPaymentProofViewer = true
                                }, isReciept: false
                            )
                            .padding(.leading, 4)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingFileViewer) {
            if let urlString = expense.attachmentURL,
               let url = URL(string: urlString) {
                FileViewerSheet(fileURL: url, fileName: expense.attachmentName)
            }
        }
        .sheet(isPresented: $showingPaymentProofViewer) {
            if let urlString = expense.paymentProofURL,
               let url = URL(string: urlString) {
                FileViewerSheet(fileURL: url, fileName: expense.paymentProofName)
            }
        }
    }
    
    private var statusColor: Color {
        switch expense.status {
        case .approved:
            return .green
        case .rejected:
            return .red
        case .pending:
            return .orange
        }
    }
}

// MARK: - Apple Date Range Picker Sheet
struct AppleDateRangePickerSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isActive: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Select Date Range")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Choose start and end dates to filter expenses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Date Pickers using Apple's native style
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Date")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        DatePicker(
                            "Start Date",
                            selection: $startDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("End Date")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        DatePicker(
                            "End Date",
                            selection: $endDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    }
                }
                .padding(.horizontal, 20)
                
                // Validation Message
                if endDate < startDate {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("End date must be after start date")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        isActive = true
                        dismiss()
                    }) {
                        Text("Apply Filter")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(endDate < startDate ? Color.gray : Color.blue)
                            )
                    }
                    .disabled(endDate < startDate)
                    
                    Button(action: {
                        isActive = false
                        dismiss()
                    }) {
                        Text("Clear Filter")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}
