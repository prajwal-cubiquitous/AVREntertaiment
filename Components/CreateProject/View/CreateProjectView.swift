//
//  CreateProjectView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//


// CreateProjectView.swift
// CreateProjectView.swift

import SwiftUI

struct CreateProjectView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var viewModel = CreateProjectViewModel()
    @Environment(\.compatibleDismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Project Information
                projectDetailsSection
                
                // MARK: - Timeline Settings
                timelineSection
                
                // MARK: - Team Management
                teamAssignmentSection
                
                // MARK: - Budget Planning
                departmentsSection
                
                // MARK: - Submit Action
                submitSection
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(leading:
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            )
            .onAppear {
                viewModel.setAuthService(authService)
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("Project Status"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .cancel(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Section Views
    
    private var projectDetailsSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spacing.medium) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Project Name")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter project name", text: $viewModel.projectName)
                        .font(DesignSystem.Typography.body)
                        .fieldStyle()
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Description")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $viewModel.projectDescription)
                        .frame(height: 100)
                        .font(DesignSystem.Typography.body)
                        .padding(DesignSystem.Spacing.small)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(DesignSystem.CornerRadius.field)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
            }
            .padding(.vertical, DesignSystem.Spacing.small)
        } header: {
            SectionHeaderLabel(title: "Project Details", icon: "folder.badge.plus")
        }
    }
    
    private var timelineSection: some View {
        Section {
            timelineView
        } header: {
            SectionHeaderLabel(title: "Timeline", icon: "calendar")
        } footer: {
            Text("Dates are optional. Enable to set specific project timeline.")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.secondary)
        }
    }
    
    private var teamAssignmentSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spacing.large) {
                managerSelectionView
                teamMemberSelectionView
            }
            .padding(.vertical, DesignSystem.Spacing.small)
        } header: {
            SectionHeaderLabel(title: "Team Assignment", icon: "person.2.fill")
        }
    }
    
    private var departmentsSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spacing.medium) {
                ForEach($viewModel.departments) { $item in
                    DepartmentInputRow(item: $item)
                }
                .onDelete { offsets in
                    viewModel.removeDepartment(at: offsets)
                }
                
                Button(action: {
                    HapticManager.selection()
                    withAnimation(DesignSystem.Animation.standardSpring) {
                        viewModel.addDepartment()
                    }
                }) {
                    if #available(iOS 16, *) {
                        Label("Add Department", systemImage: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                    } else {
                        Label("Add Department", systemImage: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16, weight: .medium, design: .default)) // Use weight here
                    }

                }
                .secondaryButton()
                .padding(.top, DesignSystem.Spacing.small)
            }
            .padding(.vertical, DesignSystem.Spacing.small)
        } header: {
            SectionHeaderLabel(title: "Departments", icon: "building.2.fill")
        } footer: {
            budgetFooterView
        }
    }
    
    private var submitSection: some View {
        Section {
            submitButton
                .padding(.vertical, DesignSystem.Spacing.small)
        }
    }
    
    // MARK: - Subviews
    
    private var timelineView: some View {
        VStack(spacing: 16) {
            // Start Date Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Start Date", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $viewModel.hasStartDate)
                        .labelsHidden()
                }
                
                if viewModel.hasStartDate {
                    DatePicker("Select start date", selection: $viewModel.startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.hasStartDate)
                }
            }
            .padding(.vertical, 4)
            
            // End Date Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("End Date", systemImage: "calendar.badge.minus")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $viewModel.hasEndDate)
                        .labelsHidden()
                }
                
                if viewModel.hasEndDate {
                    DatePicker("Select end date", selection: $viewModel.endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.hasEndDate)
                }
            }
            .padding(.vertical, 4)
            
            // Date Validation Warning
            if viewModel.hasStartDate && viewModel.hasEndDate && viewModel.endDate <= viewModel.startDate {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("End date must be after start date")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.top, 4)
                .transition(.opacity.animation(.easeInOut))
            }
        }
    }
    
    private var managerSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project Manager (Approver)").font(.caption).foregroundColor(.secondary)
            
            if let manager = viewModel.selectedManager {
                HStack {
                    VStack(alignment: .leading) {
                        Text(manager.name).fontWeight(.bold)
                        Text(manager.phoneNumber).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { viewModel.selectedManager = nil }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
                .padding(10).background(Color.blue.opacity(0.1)).cornerRadius(8)
            } else {
                SearchableDropdownView(
                    title: "Search name or phone number...",
                    searchText: $viewModel.managerSearchText,
                    items: viewModel.filteredApprovers,
                    itemContent: { user in Text("\(user.name) - \(user.phoneNumber)") },
                    onSelect: viewModel.selectManager
                )
            }
        }
        .padding(.vertical, 5)
    }
    
    private var teamMemberSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Team Members (Users)").font(.caption).foregroundColor(.secondary)
            
            SearchableDropdownView(
                title: "Search name or phone number...",
                searchText: $viewModel.teamMemberSearchText,
                items: viewModel.filteredTeamMembers,
                itemContent: { user in Text("\(user.name) - \(user.phoneNumber)") },
                onSelect: viewModel.selectTeamMember
            )
            
            if !viewModel.selectedTeamMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(viewModel.selectedTeamMembers)) { member in
                            TagView(user: member, onRemove: { viewModel.removeTeamMember(member) })
                        }
                    }
                    .padding(.top, 5)
                }
            }
        }
        .padding(.vertical, 5)
    }
    
    private var budgetFooterView: some View {
        HStack {
            Image(systemName: "indianrupeesign.circle.fill")
                .foregroundColor(.green)
                .font(DesignSystem.Typography.callout)
                .applysymbolRenderingModeIfAvailable
            
            Text("Total Budget:")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(viewModel.totalBudgetFormatted)
                .font(DesignSystem.Typography.callout)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(.top, DesignSystem.Spacing.small)
    }
    
    private var submitButton: some View {
        Button(action: {
            HapticManager.impact(.medium)
            viewModel.saveProject()
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Label("Create Project", systemImage: "plus.app.fill")
                        .applysymbolRenderingModeIfAvailable
                }
            }
            .font(DesignSystem.Typography.headline)
        }
        .primaryButton()
        .disabled(!viewModel.isFormValid || viewModel.isLoading)
        .animation(DesignSystem.Animation.standardSpring, value: viewModel.isFormValid)
    }
}


// MARK: - Reusable Helper Views

struct SearchableDropdownView: View {
    let title: String
    @Binding var searchText: String
    let items: [User]
    let itemContent: (User) -> Text
    let onSelect: (User) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField(title, text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .overlay(
                    HStack {
                        Spacer()
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.trailing, 8)
                        }
                    }
                )

            if !items.isEmpty && !searchText.isEmpty {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            Button(action: { onSelect(item) }) {
                                itemContent(item)
                                    .padding(.vertical, 10).padding(.horizontal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
    }
}

struct TagView: View {
    let user: User
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(user.name).font(.caption).lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption).foregroundColor(.primary)
                    .padding(4).background(Color.black.opacity(0.1)).clipShape(Circle())
            }
        }
        .padding(.leading, 8).padding([.trailing, .vertical], 4)
        .background(Color.gray.opacity(0.2))
        .clipShape(Capsule())
    }
}

// MARK: - Supporting Components

private struct SectionHeaderLabel: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(DesignSystem.Typography.callout)
                .applysymbolRenderingModeIfAvailable
            
            Text(title)
                .sectionHeaderStyle()
        }
    }
}

private struct DepartmentInputRow: View {
    @Binding var item: DepartmentItem
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                    Text("Department")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("e.g., Marketing", text: $item.name)
                        .font(DesignSystem.Typography.callout)
                        .textFieldStyle(.plain)
                }
                
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.extraSmall) {
                    Text("Budget")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("₹0", text: $item.amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .medium, design: .default))  // specify weight here
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                        .frame(width: 100)

                }
            }
            
            Divider()
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}

// MARK: - Preview Provider
struct CreateProjectView_Previews: PreviewProvider {
    static var previews: some View {
        CreateProjectView()
    }
}
