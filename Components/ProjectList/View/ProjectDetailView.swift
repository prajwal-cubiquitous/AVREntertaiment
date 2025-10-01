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
    @State private var showingAddExpense = false
    @State private var showingChats = false
    @ObservedObject private var viewModel: ProjectDetailViewModel
    let role: UserRole?
    let phoneNumber: String

    init(project: Project, role: UserRole? = nil, phoneNumber: String = ""){
        self.project = project
        self.role = role
        self.phoneNumber = phoneNumber
        self._viewModel = ObservedObject(wrappedValue: ProjectDetailViewModel(project: project))
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
                
                // MARK: - Budget Breakdown
                if !project.departments.isEmpty {
                    EnhancedDepartmentBreakdownView(project: project, viewModel: viewModel)
                        .cardStyle()
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                }
                
                // MARK: - Expense Section
                ExpenseListView(project: project)
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                
                // Bottom padding for floating button
                Color.clear
                    .frame(height: 80)
            }
            .padding(.top, DesignSystem.Spacing.small)
            .onAppear {
                print("DEBUG 10: \(phoneNumber)")
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Project Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
            viewModel.fetchApprovedExpenses()
        }
        .refreshable {
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
            } else {
                ChatsView(
                    project: project,
                    currentUserPhone: phoneNumber,
                    currentUserRole: role ?? .USER
                )
                .presentationDetents([.large])
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
                .onAppear{
                    print("DEBUG 1 \(totalApprovedAmount)")
                }
                
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
                    value: project.managerId,
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

private struct EnhancedDepartmentBreakdownView: View {
    let project: Project
    @ObservedObject var viewModel: ProjectDetailViewModel
    
    private var sortedDepartments: [(String, Double)] {
        project.departments.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            SectionHeader(title: "Department Budget Breakdown")
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading expenses...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.medium)
            } else {
                VStack(spacing: DesignSystem.Spacing.small) {
                    ForEach(Array(sortedDepartments.enumerated()), id: \.offset) { index, department in
                        EnhancedDepartmentRow(
                            name: department.0,
                            allocatedBudget: department.1,
                            approvedAmount: viewModel.approvedAmount(for: department.0),
                            remainingBudget: viewModel.remainingBudget(for: department.0, allocatedBudget: department.1),
                            spentPercentage: viewModel.spentPercentage(for: department.0, allocatedBudget: department.1)
                        )
                        
                        if index < sortedDepartments.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
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
                    
                    Text("AVR Entertainment")
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
