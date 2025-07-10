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
            VStack(spacing: DesignSystem.Spacing.large) {
                // Project Name Section
                EditableSection(
                    title: "Project Name",
                    value: viewModel.projectName,
                    isEditing: $viewModel.isEditingName
                ) { newValue in
                    viewModel.updateProjectName(newValue)
                }
                
                // Description Section
                EditableSection(
                    title: "Description",
                    value: viewModel.projectDescription,
                    isEditing: $viewModel.isEditingDescription,
                    isMultiline: true
                ) { newValue in
                    viewModel.updateProjectDescription(newValue)
                }
                
                // Status Section
                HStack {
                    Text("Status")
                        .font(DesignSystem.Typography.headline)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Button(status.rawValue) {
                                viewModel.updateProjectStatus(status)
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.projectStatus)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                // Timeline Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    HStack {
                        Text("Timeline")
                            .font(DesignSystem.Typography.headline)
                        Spacer()
                        Button {
                            viewModel.isEditingDates.toggle()
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                    
                    if viewModel.isEditingDates {
                        DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $viewModel.endDate, displayedComponents: .date)
                        
                        Button("Save Dates") {
                            viewModel.updateProjectDates()
                        }
                        .primaryButton()
                    } else {
                        Text(viewModel.dateRangeFormatted)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                // Team Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    HStack {
                        Text("Team")
                            .font(DesignSystem.Typography.headline)
                        Spacer()
                        Button {
                            viewModel.isEditingTeam.toggle()
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                    
                    // Approver
                    VStack(alignment: .leading) {
                        Text("Project Manager")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if viewModel.isEditingTeam {
                            SearchableDropdownView(
                                title: "Search approver...",
                                searchText: $viewModel.approverSearchText,
                                items: viewModel.filteredApprovers,
                                itemContent: { user in Text("\(user.name) - \(user.phoneNumber)") },
                                onSelect: viewModel.selectApprover
                            )
                        } else {
                            Text(viewModel.managerName)
                                .font(.body)
                        }
                    }
                    
                    // Team Members
                    VStack(alignment: .leading) {
                        Text("Team Members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if viewModel.isEditingTeam {
                            SearchableDropdownView(
                                title: "Search team members...",
                                searchText: $viewModel.teamMemberSearchText,
                                items: viewModel.filteredTeamMembers,
                                itemContent: { user in Text("\(user.name) - \(user.phoneNumber)") },
                                onSelect: viewModel.selectTeamMember
                            )
                            
                            ForEach(viewModel.selectedTeamMembers.sorted(by: { $0.name < $1.name })) { member in
                                HStack {
                                    Text(member.name)
                                    Spacer()
                                    Button {
                                        viewModel.removeTeamMember(member)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            
                            Button("Save Team") {
                                viewModel.updateProjectTeam()
                            }
                            .primaryButton()
                        } else {
                            ForEach(viewModel.teamMembers, id: \.self) { member in
                                Text(member)
                                    .font(.body)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                // Departments Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    HStack {
                        Text("Departments")
                            .font(DesignSystem.Typography.headline)
                        Spacer()
                        Button {
                            viewModel.isEditingDepartments.toggle()
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                    
                    if viewModel.isEditingDepartments {
                        ForEach($viewModel.tempDepartments) { $dept in
                            HStack {
                                TextField("Department", text: $dept.name)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Amount", text: $dept.amount)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
                                Button {
                                    viewModel.removeDepartment(dept)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        Button("Add Department") {
                            viewModel.addDepartment()
                        }
                        .secondaryButton()
                        
                        // Total Budget Display (Preview)
                        HStack {
                            Text("Total Budget (Preview):")
                                .font(.headline)
                            Spacer()
                            Text("₹\(String(format: "%.2f", viewModel.tempTotalBudget))")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, DesignSystem.Spacing.medium)
                        
                        // Save and Cancel Buttons
                        HStack {
                            Button("Cancel") {
                                viewModel.cancelDepartmentEditing()
                            }
                            .secondaryButton()
                            
                            Button("Save Departments") {
                                viewModel.updateProjectDepartments()
                            }
                            .primaryButton()
                        }
                        .padding(.top, DesignSystem.Spacing.medium)
                        
                    } else {
                        ForEach(Array(viewModel.departments.enumerated()), id: \.offset) { _, dept in
                            HStack {
                                Text(dept.name)
                                Spacer()
                                Text("₹\(dept.amount)")
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Total Budget Display
                        HStack {
                            Text("Total Budget:")
                                .font(.headline)
                            Spacer()
                            Text("₹\(String(format: "%.2f", viewModel.totalBudget))")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, DesignSystem.Spacing.medium)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Project Details")
        .navigationBarTitleDisplayMode(.inline)
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
}

struct EditableSection: View {
    let title: String
    let value: String
    @Binding var isEditing: Bool
    var isMultiline: Bool = false
    let onSave: (String) -> Void
    
    @State private var editedValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                Spacer()
                Button {
                    if isEditing {
                        onSave(editedValue)
                    }
                    isEditing.toggle()
                    if isEditing {
                        editedValue = value
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
            
            if isEditing {
                if isMultiline {
                    TextEditor(text: $editedValue)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                } else {
                    TextField(title, text: $editedValue)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
} 