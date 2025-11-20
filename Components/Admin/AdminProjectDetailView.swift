import SwiftUI
import FirebaseFirestore

struct AdminProjectDetailView: View {
    let project: Project
    @StateObject private var viewModel: AdminProjectDetailViewModel
    @StateObject private var stateManager = DashboardStateManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showingTeamMembersDetail = false
    @State private var pendingManagerChange: User? = nil
    
    init(project: Project) {
        self.project = project
        _viewModel = StateObject(wrappedValue: AdminProjectDetailViewModel(project: project))
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.large) {
                // Hero Section
                heroSection
                
                // Project Basic Info
                basicInfoSection
                
                // Timeline Section
//                timelineSection
                
                // Team Management Section
                teamSection
            }
            .padding(.horizontal)
            .padding(.top, DesignSystem.Spacing.small)
        }
        .refreshable {
            await viewModel.refreshAllData()
        }
        .navigationTitle("Project Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            if viewModel.canDeleteProject {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: {
                            HapticManager.selection()
                            viewModel.showDeleteConfirmation = true
                        }) {
                            Label("Delete Project", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Project updated successfully")
        }
        .alert("Delete Project", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.showDeleteConfirmation = false
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteProject()
            }
        } message: {
            Text("Are you sure you want to delete this project? This action cannot be undone.")
        }
        .alert("Confirm Status Change", isPresented: $viewModel.showStatusChangeConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelStatusChange()
            }
            Button("Confirm", role: .none) {
                viewModel.confirmStatusChange()
            }
        } message: {
            Text(viewModel.statusChangeMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProjectDeleted"))) { _ in
            dismiss()
        }
        .onAppear {
            // Load team members in state manager when view appears
            if let projectId = project.id,
               let customerId = viewModel.customerId {
                Task {
                    await stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProjectUpdated"))) { _ in
            // Refresh team members when project is updated
            Task {
                await viewModel.fetchTeamMembers()
                await viewModel.fetchHighestPhaseEndDate()
                // Also update state manager
                if let projectId = project.id,
                   let customerId = viewModel.customerId {
                    await stateManager.loadTeamMembers(projectId: projectId, customerId: customerId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PhaseUpdated"))) { _ in
            // Refresh highest phase end date when phases are updated
            Task {
                await viewModel.fetchHighestPhaseEndDate()
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
                .symbolRenderingMode(.hierarchical)
            
            Text("Project Administration")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            
            Text("Manage project settings, team members, and budget allocations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, DesignSystem.Spacing.large)
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSection: some View {
        let isArchived = viewModel.projectStatus == ProjectStatus.ARCHIVE.rawValue
        
        return VStack(spacing: DesignSystem.Spacing.medium) {
            // Project Name
            ModernEditableCard(
                title: "Project Name",
                value: viewModel.projectName,
                isEditing: $viewModel.isEditingName,
                icon: "textformat",
                isEditable: !isArchived,
                onSave: viewModel.updateProjectName
            )
            
            // Description
            ModernEditableCard(
                title: "Description",
                value: viewModel.projectDescription,
                isEditing: $viewModel.isEditingDescription,
                icon: "doc.text",
                isMultiline: true,
                isEditable: !isArchived,
                onSave: viewModel.updateProjectDescription
            )
            
            // Client
            ModernEditableCard(
                title: "Client Name",
                value: viewModel.client,
                isEditing: $viewModel.isEditingClient,
                icon: "person.2.fill",
                isEditable: !isArchived,
                onSave: viewModel.updateProjectClient
            )
            
            // Location
            ModernEditableCard(
                title: "Location",
                value: viewModel.location,
                isEditing: $viewModel.isEditingLocation,
                icon: "Violet_Location", // 👈 your PNG asset name
                isEditable: !isArchived,
                onSave: viewModel.updateProjectLocation
            )
            
            // Planned Date
            ModernEditableDateCard(
                title: "Planned Start Date",
                date: viewModel.plannedDate,
                isEditing: $viewModel.isEditingPlannedDate,
                icon: "calendar.badge.clock",
                isEditable: !isArchived,
                onSave: viewModel.updateProjectPlannedDate
            )
            
            // Handover Date
            HandoverDateCard(
                title: "Handover Date",
                date: viewModel.handoverDate,
                initialHandOverDate: viewModel.initialHandOverDate,
                projectStatus: viewModel.project.statusType,
                isEditing: $viewModel.isEditingHandoverDate,
                icon: "calendar.badge.checkmark",
                minimumDate: viewModel.highestPhaseEndDate,
                isEditable: !isArchived,
                onSave: viewModel.updateProjectHandoverDate
            )
            
            // Maintenance Date
            MaintenanceDateCard(
                title: "Maintenance Date",
                handoverDate: viewModel.handoverDate,
                maintenanceDate: viewModel.maintenanceDate,
                isEditing: $viewModel.isEditingMaintenanceDate,
                icon: "wrench.and.screwdriver.fill",
                isEditable: !isArchived,
                onSave: viewModel.updateProjectMaintenanceDate,
                onSetPeriod: viewModel.setMaintenancePeriod
            )
            
            // Status (always editable, even when archived)
            ModernStatusCard(
                title: "Project Status",
                status: viewModel.projectStatus,
                icon: "flag.fill",
                isProjectSuspended: viewModel.project.isSuspended ?? false,
                onStatusChange: viewModel.updateProjectStatus
            )
            
            // Suspension
            SuspensionCard(
                isSuspended: $viewModel.isSuspended,
                suspendedDate: $viewModel.suspendedDate,
                suspensionReason: $viewModel.suspensionReason,
                isEditing: $viewModel.isEditingSuspension,
                icon: "pause.circle.fill",
                isEditable: !isArchived,
                onSave: { isSuspended, date, reason in
                    viewModel.updateProjectSuspension(isSuspended: isSuspended, suspendedDate: date, suspensionReason: reason)
                }
            )
        }
    }
    
    // MARK: - Timeline Section
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            ModernSectionHeader(
                title: "Timeline",
                icon: "calendar",
                isEditing: $viewModel.isEditingDates
            )
            
            if viewModel.isEditingDates {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    DatePickerCard(
                        title: "Start Date",
                        date: $viewModel.startDate,
                        icon: "calendar.badge.plus"
                    )
                    
                    DatePickerCard(
                        title: "End Date", 
                        date: $viewModel.endDate,
                        icon: "calendar.badge.clock"
                    )
                    
                    ModernActionButton(
                        title: "Save Timeline",
                        icon: "checkmark.circle.fill",
                        color: .blue,
                        action: viewModel.updateProjectDates
                    )
                }
            } else {
                TimelineDisplayCard(dateRange: viewModel.dateRangeFormatted)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Team Section
    private var teamSection: some View {
        let isArchived = viewModel.projectStatus == ProjectStatus.ARCHIVE.rawValue
        
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Header
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title3)
                    .foregroundStyle(.blue.gradient)
                    .symbolRenderingMode(.hierarchical)
                
                Text("Team Management")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            // Project Manager Selection
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                HStack {
                    Image(systemName: "person.badge.key.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Project Manager")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Text("Select project approver (single selection)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, DesignSystem.Spacing.small)
                
                // Show display-only view when archived, picker when not archived
                if isArchived {
                    // Display-only view for archived projects
                    HStack {
                        if let manager = viewModel.selectedManager {
                            Text("\(manager.name) - \(manager.phoneNumber)")
                                .font(.body)
                                .foregroundStyle(.primary)
                        } else {
                            Text("No manager assigned")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                } else {
                    SingleSelectionPicker(
                        selectedUser: Binding(
                            get: { pendingManagerChange ?? viewModel.selectedManager },
                            set: { newValue in
                                pendingManagerChange = newValue
                            }
                        ),
                        users: viewModel.allApprovers.filter { $0.isActive },
                        placeholder: "Select project manager"
                    )
                }
                
                // Save button (only show when there's a pending change and not archived)
                let currentManagerId = viewModel.selectedManager?.phoneNumber
                let pendingManagerId = pendingManagerChange?.phoneNumber
                let hasPendingChange = currentManagerId != pendingManagerId
                
                if hasPendingChange && !isArchived {
                    Button(action: {
                        HapticManager.selection()
                        if let manager = pendingManagerChange {
                            viewModel.updateProjectManager(manager)
                            viewModel.selectedManager = manager
                        } else {
                            // Removing manager (None selected)
                            viewModel.removeProjectManager()
                            viewModel.selectedManager = nil
                        }
                        pendingManagerChange = nil
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline.weight(.medium))
                            
                            Text("Save Project Manager")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DesignSystem.Spacing.small)
                }
            }
            .padding()
            .background(Color(.quaternarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            
            // Team Members Preview (2-3 users)
            if !viewModel.loadedTeamMembers.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        
                        Text("Team Members")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if viewModel.loadedTeamMembers.count > 3 {
                            Text("\(viewModel.loadedTeamMembers.count) total")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    // Display first 2-3 team members
                    VStack(spacing: DesignSystem.Spacing.small) {
                        ForEach(Array(viewModel.loadedTeamMembers.prefix(3))) { member in
                            TeamMemberPreviewRow(member: member)
                        }
                    }
                }
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            } else {
                VStack(spacing: DesignSystem.Spacing.small) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Text("Team Members")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    Text("No team members added yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
            
            // View All Users Button (hidden when archived)
            if !isArchived {
                Button(action: {
                    HapticManager.selection()
                    showingTeamMembersDetail = true
                }) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.subheadline.weight(.medium))
                        
                        Text("View All Team Members")
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                }
                .buttonStyle(.plain)
            }
            
            // Temporary Approver Display
            if let tempApprover = viewModel.tempApprover {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    HStack {
                        Image(systemName: "person.badge.clock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        
                        Text("Temporary Approver")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    TempApproverDisplayInlineCard(
                        tempApprover: tempApprover,
                        tempApproverName: viewModel.tempApproverName
                    )
                }
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingTeamMembersDetail) {
            TeamMembersDetailView(project: project, role: .ADMIN, stateManager: stateManager)
                .presentationDetents([.large])
        }
    }
    
}

// MARK: - Supporting Views

struct ModernEditableCard: View {
    let title: String
    let value: String
    @Binding var isEditing: Bool
    let icon: String
    var isMultiline: Bool = false
    var isEditable: Bool = true
    let onSave: (String) -> Void
    
    @State private var editedValue: String = ""
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                if UIImage(systemName: icon) != nil {
                    // SF Symbol
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(.blue.gradient)
                } else {
                    // Custom asset image
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(.blue)
                }

                
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Only show edit button if editable
                if isEditable {
                    Button {
                        HapticManager.selection()
                        if isEditing {
                            onSave(editedValue)
                        }
                        isEditing.toggle()
                        if isEditing {
                            editedValue = value
                        }
                    } label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isEditing ? .green : .blue)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            
            if isEditing {
                if isMultiline {
                    TextEditor(text: $editedValue)
                        .frame(height: 100)
                        .padding(DesignSystem.Spacing.small)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                } else {
                    TextField(title, text: $editedValue)
                        .font(.body)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                }
            } else {
                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.quaternarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ModernEditableDateCard: View {
    let title: String
    let date: Date
    @Binding var isEditing: Bool
    let icon: String
    var isEditable: Bool = true
    let onSave: (Date) -> Void
    
    @State private var editedDate: Date = Date()
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue.gradient)
                
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Only show edit button if editable
                if isEditable {
                    Button {
                        HapticManager.selection()
                        if isEditing {
                            onSave(editedDate)
                        }
                        isEditing.toggle()
                        if isEditing {
                            editedDate = date
                        }
                    } label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isEditing ? .green : .blue)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            
            if isEditing {
                DatePicker("", selection: $editedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            } else {
                HStack {
                    Text(dateFormatted)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if let statusInfo = statusInfo {
                        HStack(spacing: 4) {
                            Image(systemName: statusInfo.icon)
                                .font(.caption)
                            Text(statusInfo.text)
                                .font(.caption)
                        }
                        .foregroundStyle(statusInfo.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusInfo.color.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private var statusInfo: (text: String, icon: String, color: Color)? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let planned = calendar.startOfDay(for: date)
        
        if planned < today {
            return ("Past Date", "calendar.badge.exclamationmark", .orange)
        } else if planned == today {
            return ("Today", "calendar.badge.checkmark", .green)
        } else {
            let daysUntil = calendar.dateComponents([.day], from: today, to: planned).day ?? 0
            return ("In \(daysUntil) days", "calendar.badge.clock", .blue)
        }
    }
}

struct ModernStatusCard: View {
    let title: String
    let status: String
    let icon: String
    let isProjectSuspended: Bool // Pass whether the project is actually suspended
    let onStatusChange: (ProjectStatus) -> Void
    
    // Check if status is ARCHIVE
    private var isArchived: Bool {
        status == ProjectStatus.ARCHIVE.rawValue
    }
    
    // Check if status is SUSPENDED
    private var isSuspendedStatus: Bool {
        status == ProjectStatus.SUSPENDED.rawValue
    }
    
    private var isInReview: Bool {
        status == ProjectStatus.IN_REVIEW.rawValue
    }
    private var isDeclined: Bool {
        status == ProjectStatus.DECLINED.rawValue
    }
    
    // Computed property for allowed statuses based on current status
    private var allowedStatuses: [ProjectStatus] {
        // Filter out automatic statuses that shouldn't be manually selectable
        var statuses = ProjectStatus.allCases.filter { status in
            status != .IN_REVIEW &&
            status != .LOCKED &&
            status != .DECLINED &&
            status != .ARCHIVE &&
            status != .SUSPENDED &&
            status != .STANDBY
        }
        
        // Convert current status string → enum safely
        if let currentStatus = ProjectStatus(rawValue: status) {
            // Check if current status is COMPLETED or MAINTENANCE
            if currentStatus == .COMPLETED || currentStatus == .MAINTENANCE {
                // Remove ACTIVE from allowedStatuses
                statuses = statuses.filter { $0 != .ACTIVE }
            }else if currentStatus == .LOCKED {
                // Remove ACTIVE and SUSPENDED from allowedStatuses
                statuses = statuses.filter { $0 != .COMPLETED && $0 != .MAINTENANCE }
            }
        }
        
        return statuses
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.orange.gradient)
                
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            if isArchived {
                // Display only status text with OK indicator when archived
                HStack {
                    Text(status)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            } else if isSuspendedStatus && isProjectSuspended {
                HStack {
                    Text(status)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }else if isInReview{
                HStack {
                    Text(status)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }else if isDeclined{
                HStack {
                    Text(status)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }else {
                // Show dropdown menu for non-archived statuses
                Menu {
                    ForEach(allowedStatuses, id: \.self) { projectStatus in
                        Button {
                            HapticManager.selection()
                            onStatusChange(projectStatus)
                        } label: {
                            HStack {
                                Text(projectStatus.rawValue)
                                if projectStatus.rawValue == status {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(status)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color(.quaternarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ModernSectionHeader: View {
    let title: String
    let icon: String
    @Binding var isEditing: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.purple.gradient)
            
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button {
                HapticManager.selection()
                isEditing.toggle()
            } label: {
                Image(systemName: isEditing ? "xmark.circle.fill" : "pencil.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isEditing ? .red : .blue)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }
}

struct DatePickerCard: View {
    let title: String
    @Binding var date: Date
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct TimelineDisplayCard: View {
    let dateRange: String
    
    var body: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(.blue.gradient)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text("Project Timeline")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Text(dateRange)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct TeamMemberSelectionCard: View {
    let title: String
    let subtitle: String
    @Binding var searchText: String
    let items: [User]
    let onSelect: (User) -> Void
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            SearchableDropdownView(
                title: "Search \(title.lowercased())...",
                searchText: $searchText,
                items: items,
                itemContent: { user in Text("\(user.name) - \(user.phoneNumber)") },
                onSelect: onSelect
            )
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct SelectedTeamMembersCard: View {
    let members: Set<User>
    let onRemove: (User) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text("Selected Team Members")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.small) {
                ForEach(members.sorted(by: { $0.name < $1.name })) { member in
                    HStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(String(member.name.prefix(1)))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.green)
                            )
                        
                        Text(member.name)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button {
                            HapticManager.selection()
                            onRemove(member)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                    .background(Color(.quaternarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct TeamMemberDisplayCard: View {
    let title: String
    let member: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color.gradient)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Text(member)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct TeamMembersListCard: View {
    let members: [String]
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.green)
                
                Text("Team Members")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.small) {
                ForEach(members, id: \.self) { member in
                    HStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(String(member.prefix(1)))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.green)
                            )
                        
                        Text(member)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                    .background(Color(.quaternarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

// MARK: - Selected Manager Card (Single)
struct SelectedManagerCard: View {
    let manager: User
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(manager.name.prefix(1)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text(manager.phoneNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                HapticManager.selection()
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}


struct ModernActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Temporary Approver Inline Views

struct TempApproverInlineCard: View {
    let tempApprover: TempApprover
    let tempApproverName: String?
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "person.badge.clock")
                .font(.caption)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tempApproverName ?? tempApprover.approverId)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text(tempApprover.dateRangeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(tempApprover.approvedExpenseDisplay)
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(tempApprover.statusDisplay)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor(for: tempApprover.status))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .background(Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
    }
    
    private func statusColor(for status: TempApproverStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .active:
            return .blue
        case .expired:
            return .gray
        }
    }
}

struct TempApproverDisplayInlineCard: View {
    let tempApprover: TempApprover
    let tempApproverName: String?
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "person.badge.clock")
                .font(.caption)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tempApproverName ?? tempApprover.approverId)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text(tempApprover.dateRangeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(tempApprover.approvedExpenseDisplay)
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            Text(tempApprover.statusDisplay)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor(for: tempApprover.status))
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .background(Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
    }
    
    private func statusColor(for status: TempApproverStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .active:
            return .blue
        case .expired:
            return .gray
        }
    }
}

// MARK: - Temporary Approver Views

struct TempApproverCard: View {
    let tempApprover: TempApprover
    let tempApproverName: String?
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: "person.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                
                Text("Approver: \(tempApproverName ?? tempApprover.approverId)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(tempApprover.statusDisplay)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(for: tempApprover.status))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            
            Text(tempApprover.dateRangeFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(tempApprover.approvedExpenseDisplay)
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
    
    private func statusColor(for status: TempApproverStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .active:
            return .blue
        case .expired:
            return .gray
        }
    }
}

struct TempApproverDisplayCard: View {
    let tempApprover: TempApprover
    let tempApproverName: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: "person.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                
                Text("Approver: \(tempApproverName ?? tempApprover.approverId)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(tempApprover.statusDisplay)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(for: tempApprover.status))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Text(tempApprover.dateRangeFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(tempApprover.approvedExpenseDisplay)
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding()
        .background(Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
    
    private func statusColor(for status: TempApproverStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .active:
            return .blue
        case .expired:
            return .gray
        }
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            VStack(spacing: DesignSystem.Spacing.extraSmall) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct TempApproverSheet: View {
    let allApprovers: [User]
    let isInitialAssignment: Bool
    let onSet: (TempApprover) -> Void
    let currentProjectManagerIds: [String]? // Manager IDs to exclude from the list
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedApprover: User?
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var showingDateSelection = false
    
    // Filter out the current project manager(s) from the approvers list
    private var availableApprovers: [User] {
        guard let managerIds = currentProjectManagerIds, !managerIds.isEmpty else {
            return allApprovers
        }
        
        return allApprovers.filter { approver in
            // Exclude approvers whose phoneNumber or email matches any manager ID
            let matchesPhone = managerIds.contains(approver.phoneNumber)
            let matchesEmail = approver.email != nil && managerIds.contains(approver.email!)
            return !matchesPhone && !matchesEmail
        }
    }
    
    var filteredApprovers: [User] {
        let approvers = availableApprovers
        if searchText.isEmpty {
            return approvers
        }
        return approvers.filter { approver in
            approver.name.localizedCaseInsensitiveContains(searchText) ||
            approver.phoneNumber.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        Text(isInitialAssignment ? "Assign Temp Approver" : "Change Temp Approver")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search by name or phone number", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.vertical, DesignSystem.Spacing.small)
                        .background(Color(.systemGray6))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.top, DesignSystem.Spacing.medium)
                    .padding(.bottom, DesignSystem.Spacing.small)
                    
                    // Content Section
                    if selectedApprover == nil {
                        // Approver Selection List
                        if !filteredApprovers.isEmpty {
                            List(filteredApprovers, id: \.phoneNumber) { approver in
                                ApproverRow(
                                    approver: approver,
                                    isSelected: selectedApprover?.phoneNumber == approver.phoneNumber,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedApprover = approver
                                            showingDateSelection = true
                                        }
                                        HapticManager.selection()
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                            }
                            .listStyle(PlainListStyle())
                        } else if !searchText.isEmpty {
                            // Empty State
                            VStack(spacing: DesignSystem.Spacing.medium) {
                                Image(systemName: "person.crop.circle.badge.exclamationmark")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("No Approvers Found")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Try adjusting your search terms")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemGroupedBackground))
                        } else {
                            // Initial State
                            VStack(spacing: DesignSystem.Spacing.medium) {
                                Image(systemName: isInitialAssignment ? "person.badge.plus" : "person.badge.clock")
                                    .font(.system(size: 50))
                                    .foregroundColor(.accentColor)
                                
                                Text(isInitialAssignment ? "Assign an Approver" : "Select an Approver")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(isInitialAssignment ? "Choose from the list below to assign temporary approval responsibilities" : "Choose from the list below to change temporary approval")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemGroupedBackground))
                        }
                    } else {
                        // Date Selection Section
                        ScrollView {
                            VStack(spacing: DesignSystem.Spacing.large) {
                                // Selected Approver Card
                                SelectedApproverCard(
                                    approver: selectedApprover!,
                                    onDeselect: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedApprover = nil
                                            showingDateSelection = false
                                        }
                                    }
                                )
                                
                                // Date Selection Cards
                                VStack(spacing: DesignSystem.Spacing.medium) {
                                    DateSelectionCard(
                                        title: "Start Date & Time",
                                        date: $startDate,
                                        icon: "calendar.badge.plus"
                                    )
                                    
                                    DateSelectionCard(
                                        title: "End Date & Time",
                                        date: $endDate,
                                        icon: "calendar.badge.minus"
                                    )
                                }
                                
                                // Validation Message
                                if endDate <= startDate {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("End date must be after start date")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.medium)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.bottom, DesignSystem.Spacing.large)
                        }
                        .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedApprover != nil {
                        Button(isInitialAssignment ? "Assign" : "Change") {
                            let tempApprover = TempApprover(
                                approverId: selectedApprover!.phoneNumber,
                                startDate: startDate,
                                endDate: endDate
                            )
                            onSet(tempApprover)
                            dismiss()
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                        .disabled(endDate <= startDate)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ApproverRow: View {
    let approver: User
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                // Avatar
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(approver.name.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    )
                
                // User Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(approver.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(approver.phoneNumber.formatPhoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SelectedApproverCard: View {
    let approver: User
    let onDeselect: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Selected Approver")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Change") {
                    onDeselect()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            HStack(spacing: DesignSystem.Spacing.medium) {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(approver.name.prefix(1)).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(approver.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(approver.phoneNumber.formatPhoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct DateSelectionCard: View {
    let title: String
    @Binding var date: Date
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.subheadline)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Team Member Preview Row
struct TeamMemberPreviewRow: View {
    let member: User
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            // Avatar
            ZStack {
                Circle()
                    .fill(member.role.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(member.name.prefix(1).uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(member.role.color)
            }
            
            // Member Info
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(member.phoneNumber.isEmpty ? (member.email ?? "") : member.phoneNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
    }
}

// MARK: - Handover Date Card (with phase end date validation)
struct HandoverDateCard: View {
    let title: String
    let date: Date
    let initialHandOverDate: Date
    let projectStatus: ProjectStatus
    @Binding var isEditing: Bool
    let icon: String
    let minimumDate: Date?
    var isEditable: Bool = true
    let onSave: (Date) -> Void
    
    @State private var editedDate: Date = Date()
    @State private var validationError: String? = nil
    
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private var initialHandOverDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: initialHandOverDate)
    }
    
    private var daysExtended: Int? {
        let calendar = Calendar.current
        let initial = calendar.startOfDay(for: initialHandOverDate)
        let current = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: initial, to: current).day
        return days != nil && days! > 0 ? days : nil
    }
    
    private var isValidDate: Bool {
        guard let minimumDate = minimumDate else { return true }
        let calendar = Calendar.current
        let edited = calendar.startOfDay(for: editedDate)
        let minimum = calendar.startOfDay(for: minimumDate)
        return edited >= minimum
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue.gradient)
                
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Only show edit button if editable
                if isEditable {
                    Button {
                        HapticManager.selection()
                        if isEditing {
                            if isValidDate {
                                onSave(editedDate)
                                validationError = nil
                            } else {
                                HapticManager.notification(.error)
                                if let minimumDate = minimumDate {
                                    let formatter = DateFormatter()
                                    formatter.dateStyle = .medium
                                    validationError = "Handover date must be on or after \(formatter.string(from: minimumDate)) (highest phase end date)"
                                }
                            }
                        }
                        if isEditing && isValidDate {
                            isEditing.toggle()
                        } else if !isEditing {
                            isEditing.toggle()
                            editedDate = date
                            validationError = nil
                        }
                    } label: {
                        Image(systemName: isEditing ? (isValidDate ? "checkmark.circle.fill" : "exclamationmark.circle.fill") : "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isEditing ? (isValidDate ? .green : .red) : .blue)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            
            if isEditing {
                VStack(spacing: DesignSystem.Spacing.small) {
                    if let minimumDate = minimumDate {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Must be on or after highest phase end date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, DesignSystem.Spacing.small)
                    }
                    
                    DatePicker("", selection: $editedDate, in: (minimumDate ?? Date())..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        .onChange(of: editedDate) { oldValue, newValue in
                            // Clear validation error when date changes
                            if isValidDate {
                                validationError = nil
                            }
                        }
                    
                    if let error = validationError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(.horizontal, DesignSystem.Spacing.small)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    // Initial Handover Date (static display)
//                    HStack {
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Initial Handover Date")
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//                            Text(initialHandOverDateFormatted)
//                                .font(.body)
//                                .foregroundStyle(.primary)
//                        }
//                        Spacer()
//                    }
//                    
//                    Divider()
                    
                    // Current Handover Date
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Handover Date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(dateFormatted)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                        
                        // Days Extended Badge
                        if let days = daysExtended {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.caption)
                                Text("\(days) day\(days == 1 ? "" : "s") extended")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        
                        // Status Info
                        if let statusInfo = statusInfo {
                            HStack(spacing: 4) {
                                Image(systemName: statusInfo.icon)
                                    .font(.caption)
                                Text(statusInfo.text)
                                    .font(.caption)
                            }
                            .foregroundStyle(statusInfo.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusInfo.color.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var statusInfo: (text: String, icon: String, color: Color)? {
        guard let minimumDate = minimumDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let handover = calendar.startOfDay(for: date)
        let minimum = calendar.startOfDay(for: minimumDate)
        
        if handover < minimum {
            return ("Below minimum", "exclamationmark.triangle.fill", .orange)
        } else if handover == minimum {
            return ("At minimum", "checkmark.circle.fill", .green)
        } else if handover < today {
            return ("Past Date", "calendar.badge.exclamationmark", .orange)
        } else if handover == today {
            return ("Today", "calendar.badge.checkmark", .green)
        } else {
            let daysUntil = calendar.dateComponents([.day], from: today, to: handover).day ?? 0
            return ("In \(daysUntil) days", "calendar.badge.clock", .blue)
        }
    }
}

// MARK: - Maintenance Date Card
struct MaintenanceDateCard: View {
    let title: String
    let handoverDate: Date
    let maintenanceDate: Date
    @Binding var isEditing: Bool
    let icon: String
    var isEditable: Bool = true
    let onSave: (Date) -> Void
    let onSetPeriod: (Int) -> Void
    
    @State private var editedDate: Date = Date()
    @State private var selectedPeriod: MaintenancePeriod? = nil
    @State private var showCustomDatePicker = false
    
    enum MaintenancePeriod: Int, CaseIterable {
        case oneMonth = 1
        case twoMonths = 2
        case threeMonths = 3
        case sixMonths = 6
        case twelveMonths = 12
        case twentyFourMonths = 24
        case custom = 0
        
        var displayName: String {
            switch self {
            case .oneMonth: return "1 Month"
            case .twoMonths: return "2 Months"
            case .threeMonths: return "3 Months"
            case .sixMonths: return "6 Months"
            case .twelveMonths: return "12 Months"
            case .twentyFourMonths: return "24 Months"
            case .custom: return "Custom Date"
            }
        }
    }
    
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: maintenanceDate)
    }
    
    private var periodFromHandover: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: handoverDate, to: maintenanceDate)
        
        if let months = components.month, months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") from handover"
        } else if let days = components.day, days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") from handover"
        } else {
            return "Same as handover date"
        }
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.orange.gradient)
                
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Only show edit button if editable
                if isEditable {
                    Button {
                        HapticManager.selection()
                        if isEditing {
                            if showCustomDatePicker {
                                onSave(editedDate)
                            } else if let period = selectedPeriod, period != .custom {
                                onSetPeriod(period.rawValue)
                            } else {
                                onSave(editedDate)
                            }
                        }
                        isEditing.toggle()
                        if isEditing {
                            editedDate = maintenanceDate
                            // Determine current period
                            let calendar = Calendar.current
                            let components = calendar.dateComponents([.month], from: handoverDate, to: maintenanceDate)
                            if let months = components.month, let period = MaintenancePeriod(rawValue: months) {
                                selectedPeriod = period
                            } else {
                                selectedPeriod = .custom
                                showCustomDatePicker = true
                            }
                        } else {
                            selectedPeriod = nil
                            showCustomDatePicker = false
                        }
                    } label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isEditing ? .green : .orange)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            
            if isEditing {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    // Period Selection Menu
                    Menu {
                        ForEach(MaintenancePeriod.allCases.filter { $0 != .custom }, id: \.self) { period in
                            Button(action: {
                                HapticManager.selection()
                                selectedPeriod = period
                                showCustomDatePicker = false
                                if period != .custom {
                                    let calendar = Calendar.current
                                    editedDate = calendar.date(byAdding: .month, value: period.rawValue, to: handoverDate) ?? handoverDate
                                }
                            }) {
                                HStack {
                                    Text(period.displayName)
                                    if selectedPeriod == period {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            HapticManager.selection()
                            selectedPeriod = .custom
                            showCustomDatePicker = true
                        }) {
                            HStack {
                                Text(MaintenancePeriod.custom.displayName)
                                if selectedPeriod == .custom {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedPeriod?.displayName ?? "Select Period")
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                    }
                    
                    // Custom Date Picker (shown when custom is selected or when period doesn't match preset)
                    if showCustomDatePicker || selectedPeriod == .custom {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            Text("Custom Date")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            DatePicker("", selection: $editedDate, in: handoverDate..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding()
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        }
                    }
                    
                    // Preview of selected date
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Will be set to: \(dateFormatter.string(from: editedDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.small)
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateFormatted)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Text(periodFromHandover)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// MARK: - Suspension Reason Enum
enum SuspensionReason: String, CaseIterable {
    case paymentMilestoneDelay = "Payment Milestone Delay"
    case siteAccessPermitHold = "Site Access/Permit Hold"
    case designApprovalPending = "Design Approval Pending"
    case vendorMaterialShortage = "Vendor/Material Shortage"
    case safetyNonCompliance = "Safety Non-Compliance"
    case regulatoryPending = "Regulatory Pending"
    case resourceReallocation = "Resource Reallocation"
    case weatherForceMajeure = "Weather/Force Majeure"
    case other = "Other"
}

// MARK: - Suspension Card
struct SuspensionCard: View {
    @Binding var isSuspended: Bool
    @Binding var suspendedDate: Date?
    @Binding var suspensionReason: String
    @Binding var isEditing: Bool
    let icon: String
    var isEditable: Bool = true
    let onSave: (Bool, Date?, String) -> Void
    
    @State private var editedIsSuspended: Bool = false
    @State private var editedSuspendedDate: Date = Date()
    @State private var selectedReason: SuspensionReason? = nil
    @State private var customReasonNotes: String = ""
    
    private let maxReasonLength = 200 // Character limit for custom notes
    
    private var dateFormatted: String {
        guard let date = suspendedDate else { return "Not set" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private var truncatedReason: String {
        if suspensionReason.isEmpty {
            return "No reason provided"
        }
        if suspensionReason.count <= maxReasonLength {
            return suspensionReason
        }
        return String(suspensionReason.prefix(maxReasonLength)) + "..."
    }
    
    // Get the final reason string to save
    private func getFinalReason() -> String {
        guard let selected = selectedReason else { return "" }
        
        if selected == .other {
            return customReasonNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return selected.rawValue
        }
    }
    
    // Parse existing reason to determine selected reason and custom notes
    private func parseExistingReason() {
        let trimmedReason = suspensionReason.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedReason.isEmpty {
            selectedReason = nil
            customReasonNotes = ""
            return
        }
        
        // Check if the reason matches any enum case
        if let matchedReason = SuspensionReason.allCases.first(where: { $0.rawValue == trimmedReason }) {
            selectedReason = matchedReason
            customReasonNotes = ""
        } else {
            // If it doesn't match, it's a custom "Other" reason
            selectedReason = .other
            customReasonNotes = trimmedReason
        }
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.red.gradient)
                
                Text("Project Suspension")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Only show edit button if editable
                if isEditable {
                    Button {
                        HapticManager.selection()
                        if isEditing {
                            // Validate: if suspension is enabled, reason must be provided
                            let finalReason = getFinalReason()
                            if editedIsSuspended && finalReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                HapticManager.notification(.error)
                                return
                            }
                            onSave(editedIsSuspended, editedIsSuspended ? editedSuspendedDate : nil, finalReason)
                        }
                        isEditing.toggle()
                        if isEditing {
                            editedIsSuspended = isSuspended
                            editedSuspendedDate = suspendedDate ?? Date()
                            // Parse existing reason to determine selected reason
                            parseExistingReason()
                        }
                    } label: {
                        let finalReason = getFinalReason()
                        let isValid = !editedIsSuspended || !finalReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        Image(systemName: isEditing ? (isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill") : "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isEditing ? (isValid ? .green : .orange) : .red)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            
            if isEditing {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    // Toggle for suspension
                    HStack {
                        Text("Enable Suspension")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $editedIsSuspended)
                            .labelsHidden()
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                    
                    // Date picker (only shown when suspension is enabled)
                    if editedIsSuspended {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            Text("Suspended Until")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            DatePicker("", selection: $editedSuspendedDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding()
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                            
                            // Reason picker
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                HStack(spacing: 4) {
                                    Text("Reason for Suspension")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    
                                    Text("*")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.red)
                                }
                                
                                // Reason Picker
                                Menu {
                                    ForEach(SuspensionReason.allCases, id: \.self) { reason in
                                        Button(action: {
                                            HapticManager.selection()
                                            selectedReason = reason
                                            // Clear custom notes if not "Other"
                                            if reason != .other {
                                                customReasonNotes = ""
                                            }
                                        }) {
                                            HStack {
                                                Text(reason.rawValue)
                                                if selectedReason == reason {
                                                    Image(systemName: "checkmark")
                                                        .foregroundStyle(.blue)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedReason?.rawValue ?? "Select reason")
                                            .font(.body)
                                            .foregroundStyle(selectedReason == nil ? .secondary : .primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding()
                                    .background(selectedReason == nil && editedIsSuspended ? Color.red.opacity(0.1) : Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                            .stroke(selectedReason == nil && editedIsSuspended ? Color.red : Color.clear, lineWidth: 1)
                                    )
                                }
                                
                                // Custom notes field (only shown when "Other" is selected)
                                if selectedReason == .other {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                                        HStack(spacing: 4) {
                                            Text("Suspension Notes")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.secondary)
                                            
                                            Text("*")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.red)
                                        }
                                        
                                        TextField("Enter suspension notes (required)", text: $customReasonNotes, axis: .vertical)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .lineLimit(3...5)
                                            .padding()
                                            .background(customReasonNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.red.opacity(0.1) : Color(.tertiarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                                    .stroke(customReasonNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.red : Color.clear, lineWidth: 1)
                                            )
                                        
                                        HStack {
                                            Text("\(customReasonNotes.count) characters")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            
                                            if customReasonNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                Spacer()
                                                Text("Notes are required for 'Other'")
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                }
                                
                                // Validation message
                                if editedIsSuspended {
                                    if selectedReason == nil {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                            Text("Reason is required")
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                        }
                                    } else if selectedReason == .other && customReasonNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                            Text("Suspension notes are required for 'Other'")
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isSuspended ? "Suspended" : "Not Suspended")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        if isSuspended {
                            if let date = suspendedDate {
                                Text("Until: \(dateFormatted)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !suspensionReason.isEmpty {
                                Text(truncatedReason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        } else {
                            Text("Project is active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isSuspended {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.circle.fill")
                                .font(.caption)
                            Text("SUSPENDED")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding()
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
} 
