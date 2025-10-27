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
    @StateObject private var viewModel = TeamMembersDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedMember: User?
    @State private var showingMemberExpenses = false
    private var filteredMembers: [User] {
        var members = viewModel.teamMembers
        
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
                } else if viewModel.teamMembers.isEmpty {
                    emptyView
                } else {
                    membersListView
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadTeamMembers(for: project)
        }
        .sheet(isPresented: $showingMemberExpenses) {
            if let member = selectedMember {
                MemberExpensesView(member: member, project: project)
                    .presentationDetents([.large])
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
                    
                    Text("\(viewModel.teamMembers.count) members")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: { viewModel.refreshData() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                        .font(.title2)
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
                    TeamMemberRowView(member: member) {
                        selectedMember = member
                        showingMemberExpenses = true
                        HapticManager.selection()
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Team Member Row View
struct TeamMemberRowView: View {
    let member: User
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
                    
                    Text(member.phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                if let email = member.email, !email.isEmpty {
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
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                    
                    Text("Team Member")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Team Members Detail ViewModel
class TeamMembersDetailViewModel: ObservableObject {
    @Published var teamMembers: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadTeamMembers(for project: Project) {
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
                .collection("users_ios")
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
        if let project = project {
            loadTeamMembers(for: project)
        }
    }
    
    private var project: Project?
    
    func setProject(_ project: Project) {
        self.project = project
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
    
    enum ExpenseFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case approved = "Approved"
        case rejected = "Rejected"
    }
    
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
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
        
        return expenses
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Filter Buttons
                filterButtonsView
                
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadExpenses(for: project, memberId: member.id ?? "")
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
    
    // MARK: - Filter Buttons View
    private var filterButtonsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ExpenseFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        HapticManager.selection()
                    }) {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filter
                                    ? member.role.color
                                    : Color(.systemGray6)
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
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
        VStack {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("No \(selectedFilter.rawValue) Expenses")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top)
            Text("No expenses match the selected filter.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }
    
    // MARK: - Expenses List View
    private var expensesListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredExpenses, id: \.id) { expense in
                    MemberExpenseRowView(expense: expense)
                }
            }
            .padding()
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
    
    func loadExpenses(for project: Project, memberId: String) {
        guard let projectId = project.id else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let snapshot = try await db
                    .collection("projects_ios")
                    .document(projectId)
                    .collection("expenses")
                    .whereField("submittedBy", isEqualTo: memberId)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                var loadedExpenses: [Expense] = []
                for document in snapshot.documents {
                    if let expense = try? document.data(as: Expense.self) {
                        loadedExpenses.append(expense)
                    }
                }
                
                await MainActor.run {
                    self.expenses = loadedExpenses
                    self.isLoading = false
                }
            } catch {
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
    
    var body: some View {
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
            Text(expense.description)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(2)
            
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
