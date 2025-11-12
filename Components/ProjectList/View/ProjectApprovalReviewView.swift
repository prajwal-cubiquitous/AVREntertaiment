//
//  ProjectApprovalReviewView.swift
//  AVREntertainment
//
//  Created for project approval review by approver
//

import SwiftUI
import FirebaseFirestore

struct ProjectApprovalReviewView: View {
    let project: Project
    let customerId: String?
    let onApprove: () async -> Void
    let onReject: (String) async -> Void
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProjectApprovalReviewViewModel()
    @State private var showingRejectionSheet = false
    @State private var rejectionReason = ""
    @State private var isProcessing = false
    @State private var showingApprovalConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Loading project details...")
                } else {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.large) {
                            // Header Section
                            headerSection
                            
                            // Project Basics
                            projectBasicsCard
                            
                            // Description
                            if !project.description.isEmpty {
                                descriptionCard
                            }
                            
                            // Project Team
                            projectTeamCard
                            
                            // Project Phases
                            if !viewModel.phases.isEmpty {
                                phasesSection
                            }
                            
                            // Action Buttons
                            actionButtonsSection
                                .padding(.bottom, DesignSystem.Spacing.extraLarge)
                        }
                        .padding(DesignSystem.Spacing.medium)
                    }
                }
            }
            .navigationTitle("Review Project")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingRejectionSheet) {
            rejectionSheet
        }
        .alert("Approve Project", isPresented: $showingApprovalConfirmation) {
            Button("Cancel", role: .cancel) {
                // Do nothing, just dismiss
            }
            Button("Confirm") {
                Task {
                    isProcessing = true
                    await onApprove()
                    isProcessing = false
                    onDismiss()
                }
            }
        } message: {
            if let plannedDateStr = project.plannedDate {
                Text("Project status will change to LOCKED until the planned start date (\(plannedDateStr)). The project will automatically become ACTIVE when the planned start date arrives.")
            } else {
                Text("Project status will change to LOCKED until the phase start date. The project will automatically become ACTIVE when the first phase starts.")
            }
        }
        .onAppear {
            Task {
                await viewModel.loadProjectDetails(project: project, customerId: customerId)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.purple)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Project Review")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Please review all project details before approving or rejecting this project.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, DesignSystem.Spacing.medium)
    }
    
    // MARK: - Project Basics Card
    private var projectBasicsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Project Basics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: DesignSystem.Spacing.small) {
                ApprovalInfoRow(label: "Project Name", value: project.name)
                ApprovalInfoRow(label: "Client", value: project.client)
                ApprovalInfoRow(label: "Location", value: project.location)
                ApprovalInfoRow(label: "Currency", value: "\(currencySymbol) \(project.currency)")
                ApprovalInfoRow(label: "Total Budget", value: project.budgetFormatted)
                
                if let plannedDateStr = project.plannedDate {
                    ApprovalInfoRow(label: "Planned Date", value: plannedDateStr)
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Description Card
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Description")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(project.description)
                .font(.body)
                .foregroundColor(.primary)
        }
        .cardStyle()
    }
    
    // MARK: - Project Team Card
    private var projectTeamCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Project Team")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                if !viewModel.managers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manager\(viewModel.managers.count > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        ForEach(viewModel.managers, id: \.id) { manager in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 6, height: 6)
                                Text(manager.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                if !viewModel.teamMembers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Team Members (\(viewModel.teamMembers.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.top, viewModel.managers.isEmpty ? 0 : DesignSystem.Spacing.small)
                        
                        ForEach(viewModel.teamMembers, id: \.id) { member in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 6, height: 6)
                                Text(member.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Phases Section
    private var phasesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Project Phases")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            ForEach(viewModel.phases) { phase in
                PhaseApprovalCard(phase: phase, currencySymbol: currencySymbol)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Approve Button
            Button(action: {
                HapticManager.selection()
                showingApprovalConfirmation = true
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    
                    Text("Approve Project")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.medium)
            }
            .primaryButton()
            .disabled(isProcessing)
            
            // Reject Button
            Button(action: {
                showingRejectionSheet = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                    
                    Text("Reject Project")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.medium)
            }
            .secondaryButton()
            .disabled(isProcessing)
        }
    }
    
    // MARK: - Rejection Sheet
    private var rejectionSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.large) {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Reject Project")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Please provide a reason for rejecting this project. The admin will be able to edit and resubmit the project for review.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Reason for Rejection")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your reason...", text: $rejectionReason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Spacer()
                
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Button("Cancel") {
                        showingRejectionSheet = false
                        rejectionReason = ""
                    }
                    .secondaryButton()
                    
                    Button("Confirm Rejection") {
                        Task {
                            isProcessing = true
                            await onReject(rejectionReason)
                            isProcessing = false
                            showingRejectionSheet = false
                            onDismiss()
                        }
                    }
                    .primaryButton()
                    .disabled(rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                }
            }
            .padding(DesignSystem.Spacing.large)
            .navigationTitle("Reject Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingRejectionSheet = false
                        rejectionReason = ""
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    private var currencySymbol: String {
        switch project.currency {
        case "INR": return "₹"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default: return "₹"
        }
    }
}

// MARK: - Project Approval Review ViewModel
@MainActor
class ProjectApprovalReviewViewModel: ObservableObject {
    @Published var phases: [PhaseReviewInfo] = []
    @Published var managers: [User] = []
    @Published var teamMembers: [User] = []
    @Published var isLoading = false
    
    struct PhaseReviewInfo: Identifiable {
        let id: String
        let phaseName: String
        let phaseNumber: Int
        let startDate: String?
        let endDate: String?
        let departments: [DepartmentReviewInfo]
        let totalBudget: Double
    }
    
    struct DepartmentReviewInfo: Identifiable {
        let id = UUID()
        let name: String
        let budget: Double
    }
    
    func loadProjectDetails(project: Project, customerId: String?) async {
        guard let projectId = project.id,
              let customerId = customerId else {
            return
        }
        
        isLoading = true
        
        do {
            // Load phases
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .order(by: "phaseNumber")
                .getDocuments()
            
            var loadedPhases: [PhaseReviewInfo] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    // Extract departments
                    var departments: [DepartmentReviewInfo] = []
                    for (deptKey, amount) in phase.departments {
                        // Extract department name from key (handles "phaseId_departmentName" format)
                        let displayName: String
                        if let underscoreIndex = deptKey.firstIndex(of: "_") {
                            displayName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                        } else {
                            displayName = deptKey
                        }
                        departments.append(DepartmentReviewInfo(name: displayName, budget: amount))
                    }
                    
                    loadedPhases.append(PhaseReviewInfo(
                        id: doc.documentID,
                        phaseName: phase.phaseName,
                        phaseNumber: phase.phaseNumber,
                        startDate: phase.startDate,
                        endDate: phase.endDate,
                        departments: departments.sorted { $0.name < $1.name },
                        totalBudget: phase.departments.values.reduce(0, +)
                    ))
                }
            }
            
            // Load managers and team members
            var loadedManagers: [User] = []
            var loadedTeamMembers: [User] = []
            
            // Load managers
            for managerId in project.managerIds {
                if let user = try? await FirebasePathHelper.shared
                    .usersCollection(customerId: customerId)
                    .whereField("phoneNumber", isEqualTo: managerId)
                    .limit(to: 1)
                    .getDocuments()
                    .documents.first?.data(as: User.self) {
                    loadedManagers.append(user)
                } else if let user = try? await FirebasePathHelper.shared
                    .usersCollection(customerId: customerId)
                    .whereField("email", isEqualTo: managerId)
                    .limit(to: 1)
                    .getDocuments()
                    .documents.first?.data(as: User.self) {
                    loadedManagers.append(user)
                }
            }
            
            // Load team members
            for teamMemberPhone in project.teamMembers {
                if let user = try? await FirebasePathHelper.shared
                    .usersCollection(customerId: customerId)
                    .whereField("phoneNumber", isEqualTo: teamMemberPhone)
                    .limit(to: 1)
                    .getDocuments()
                    .documents.first?.data(as: User.self) {
                    loadedTeamMembers.append(user)
                }
            }
            
            await MainActor.run {
                self.phases = loadedPhases
                self.managers = loadedManagers
                self.teamMembers = loadedTeamMembers
                self.isLoading = false
            }
        } catch {
            print("Error loading project details: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Phase Approval Card
struct PhaseApprovalCard: View {
    let phase: ProjectApprovalReviewViewModel.PhaseReviewInfo
    let currencySymbol: String
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return currencySymbol + formatted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Phase Header
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phase \(phase.phaseNumber)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(phase.phaseName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatAmount(phase.totalBudget))
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                
                // Timeline
                if let startDate = phase.startDate, let endDate = phase.endDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Start: \(startDate) • End: \(endDate)")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Departments
            if !phase.departments.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("DEPARTMENTS")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(phase.departments) { dept in
                        HStack {
                            Text(dept.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(formatAmount(dept.budget))
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

// MARK: - Approval Info Row
private struct ApprovalInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Card Style Extension
private extension View {
    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: DesignSystem.Shadow.small.color,
                        radius: DesignSystem.Shadow.small.radius,
                        x: DesignSystem.Shadow.small.x,
                        y: DesignSystem.Shadow.small.y
                    )
            )
    }
}

