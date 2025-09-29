import SwiftUI
import FirebaseFirestore

struct AdminProjectDetailView: View {
    let project: Project
    @StateObject private var viewModel: AdminProjectDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
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
                timelineSection
                
                // Team Management Section
                teamSection
                
                // Departments & Budget Section
                departmentsSection
            }
            .padding(.horizontal)
            .padding(.top, DesignSystem.Spacing.small)
        }
        .navigationTitle("Project Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
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
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Project Name
            ModernEditableCard(
                title: "Project Name",
                value: viewModel.projectName,
                isEditing: $viewModel.isEditingName,
                icon: "textformat",
                onSave: viewModel.updateProjectName
            )
            
            // Description
            ModernEditableCard(
                title: "Description",
                value: viewModel.projectDescription,
                isEditing: $viewModel.isEditingDescription,
                icon: "doc.text",
                isMultiline: true,
                onSave: viewModel.updateProjectDescription
            )
            
            // Status
            ModernStatusCard(
                title: "Project Status",
                status: viewModel.projectStatus,
                icon: "flag.fill",
                onStatusChange: viewModel.updateProjectStatus
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            ModernSectionHeader(
                title: "Team Management",
                icon: "person.3.fill",
                isEditing: $viewModel.isEditingTeam
            )
            
            if viewModel.isEditingTeam {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    // Project Manager Selection
                    TeamMemberSelectionCard(
                        title: "Project Manager",
                        subtitle: "Select the project approver",
                        searchText: $viewModel.approverSearchText,
                        items: viewModel.filteredApprovers,
                        onSelect: viewModel.selectApprover,
                        icon: "person.badge.key.fill"
                    )
                    
                    // Team Members Selection
                    TeamMemberSelectionCard(
                        title: "Team Members",
                        subtitle: "Add team members to the project",
                        searchText: $viewModel.teamMemberSearchText,
                        items: viewModel.filteredTeamMembers,
                        onSelect: viewModel.selectTeamMember,
                        icon: "person.2.fill"
                    )
                    
                    // Selected Team Members
                    if !viewModel.selectedTeamMembers.isEmpty {
                        SelectedTeamMembersCard(
                            members: viewModel.selectedTeamMembers,
                            onRemove: viewModel.removeTeamMember
                        )
                    }
                    
                    // Temporary Approvers Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                        HStack {
                            Image(systemName: "person.badge.clock.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                            
                            Text("Temporary Approvers")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.selection()
                                viewModel.showingTempApproverSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.caption)
                                    Text("Add")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                        
                   if let tempApprover = viewModel.tempApprover {
                       TempApproverInlineCard(
                           tempApprover: tempApprover,
                           tempApproverName: viewModel.tempApproverName,
                           onRemove: { viewModel.removeTempApprover() }
                       )
                   } else {
                       Text("No temporary approver assigned")
                           .font(.caption)
                           .foregroundStyle(.tertiary)
                           .italic()
                   }
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                    
                    ModernActionButton(
                        title: "Save Team",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        action: viewModel.updateProjectTeam
                    )
                }
            } else {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    // Manager Display
                    TeamMemberDisplayCard(
                        title: "Project Manager",
                        member: viewModel.managerName,
                        icon: "person.badge.key.fill",
                        color: .blue
                    )
                    
                    // Team Members Display
                    if !viewModel.teamMembers.isEmpty {
                        TeamMembersListCard(
                            members: viewModel.teamMembers,
                            icon: "person.2.fill"
                        )
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
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Departments Section
    private var departmentsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            ModernSectionHeader(
                title: "Budget & Departments",
                icon: "building.columns.fill",
                isEditing: $viewModel.isEditingDepartments
            )
            
            if viewModel.isEditingDepartments {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    // Department Editor
                    ForEach($viewModel.tempDepartments) { $dept in
                        DepartmentEditCard(
                            department: $dept,
                            onRemove: { viewModel.removeDepartment(dept) }
                        )
                    }
                    
                    // Add Department Button
                    Button {
                        HapticManager.selection()
                        viewModel.addDepartment()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            
                            Text("Add Department")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                    }
                    
                    // Total Budget Preview
                    BudgetSummaryCard(
                        title: "Total Budget (Preview)",
                        amount: viewModel.tempTotalBudget,
                        isPreview: true
                    )
                    
                    // Action Buttons
                    HStack(spacing: DesignSystem.Spacing.medium) {
                        ModernActionButton(
                            title: "Cancel",
                            icon: "xmark.circle.fill",
                            color: .gray,
                            action: viewModel.cancelDepartmentEditing
                        )
                        
                        ModernActionButton(
                            title: "Save Changes",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            action: viewModel.updateProjectDepartments
                        )
                    }
                }
            } else {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    // Department List
                    ForEach(Array(viewModel.departments.enumerated()), id: \.offset) { _, dept in
                        DepartmentDisplayCard(department: dept)
                    }
                    
                    // Total Budget
                    BudgetSummaryCard(
                        title: "Total Project Budget",
                        amount: viewModel.totalBudget,
                        isPreview: false
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.bottom, DesignSystem.Spacing.large)
       .sheet(isPresented: $viewModel.showingTempApproverSheet) {
           TempApproverSheet(
               allApprovers: viewModel.allApprovers,
               onSet: viewModel.setTempApprover
           )
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
    let onSave: (String) -> Void
    
    @State private var editedValue: String = ""
    
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

struct ModernStatusCard: View {
    let title: String
    let status: String
    let icon: String
    let onStatusChange: (ProjectStatus) -> Void
    
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
            
            Menu {
                ForEach(ProjectStatus.allCases, id: \.self) { projectStatus in
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

struct DepartmentEditCard: View {
    @Binding var department: DepartmentItem
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text("Department")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                
                TextField("e.g., Marketing", text: $department.name)
                    .font(.subheadline)
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            }
            
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.extraSmall) {
                Text("Budget")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                
                TextField("₹0", text: $department.amount)
                    .font(.subheadline.weight(.medium))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            }
            
            Button {
                HapticManager.selection()
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct DepartmentDisplayCard: View {
    let department: DepartmentItem
    
    var body: some View {
        HStack {
            Image(systemName: "building.2.fill")
                .font(.subheadline)
                .foregroundStyle(.blue)
            
            Text(department.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text("₹\(department.amount)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding()
        .background(Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct BudgetSummaryCard: View {
    let title: String
    let amount: Double
    let isPreview: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "indianrupeesign.circle.fill")
                .font(.title2)
                .foregroundStyle(isPreview ? .orange : .green)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Text("₹\(String(format: "%.2f", amount))")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            if isPreview {
                Text("PREVIEW")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            }
        }
        .padding()
        .background(isPreview ? Color.orange.opacity(0.05) : Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(isPreview ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
        )
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
    let onSet: (TempApprover) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedApprover: User?
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var showingDateSelection = false
    
    var filteredApprovers: [User] {
        if searchText.isEmpty {
            return allApprovers
        }
        return allApprovers.filter { approver in
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
                        Text("Select Approver")
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
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.accentColor)
                                
                                Text("Select an Approver")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Choose from the list below to assign temporary approval")
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
                        Button("Set") {
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
