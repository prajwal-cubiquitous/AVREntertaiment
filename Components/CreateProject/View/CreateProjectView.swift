//
//  CreateProjectView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

// CreateProjectView.swift

import SwiftUI

struct CreateProjectView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var viewModel = CreateProjectViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Project Information
                projectDetailsSection
                
                // MARK: - Phases Section
                phasesSection
                
                // MARK: - Template Overrides Section
                templateOverridesSection
                
                // MARK: - Submit Action
                submitSection
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .onAppear {
                viewModel.setAuthService(authService)
            }
            .alert("Project Status", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
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
    
    private var phasesSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spacing.large) {
                ForEach($viewModel.phases) { $phase in
                    PhaseCardView(phase: $phase, viewModel: viewModel)
                }
                
                // Add Phase Button
                Button(action: {
                    HapticManager.selection()
                    withAnimation(DesignSystem.Animation.standardSpring) {
                        viewModel.addPhase()
                    }
                }) {
                    Label("Add Phase", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                }
                .secondaryButton()
                .padding(.top, DesignSystem.Spacing.small)
            }
            .padding(.vertical, DesignSystem.Spacing.small)
        } header: {
            SectionHeaderLabel(title: "Project Phases", icon: "arrow.triangle.2.circlepath")
        } footer: {
            budgetFooterView
        }
    }
    
    private var templateOverridesSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allow Template Overrides")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text("Enable to allow overriding project templates")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.allowTemplateOverrides)
                    .labelsHidden()
            }
            .padding(.vertical, DesignSystem.Spacing.small)
        } header: {
            SectionHeaderLabel(title: "Template Settings", icon: "doc.on.doc")
        }
    }
    
    private var submitSection: some View {
        Section {
            submitButton
                .padding(.vertical, DesignSystem.Spacing.small)
        }
    }
    
    // MARK: - Subviews
    
    private var budgetFooterView: some View {
        HStack {
            Image(systemName: "indianrupeesign.circle.fill")
                .foregroundColor(.green)
                .font(DesignSystem.Typography.callout)
                .symbolRenderingMode(.hierarchical)
            
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
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .font(DesignSystem.Typography.headline)
        }
        .primaryButton()
        .disabled(!viewModel.isFormValid || viewModel.isLoading)
        .animation(DesignSystem.Animation.standardSpring, value: viewModel.isFormValid)
    }
}

// MARK: - Phase Card View

struct PhaseCardView: View {
    @Binding var phase: PhaseItem
    @ObservedObject var viewModel: CreateProjectViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Phase Header
            HStack {
                Text("Phase \(phase.phaseNumber)")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Delete Phase Button
                if viewModel.phases.count > 1 {
                    Button(action: {
                        HapticManager.selection()
                        if let index = viewModel.phases.firstIndex(where: { $0.id == phase.id }) {
                            viewModel.removePhase(at: IndexSet(integer: index))
                        }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                    }
                }
            }
            
            // Phase Name
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Phase Name")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter phase name", text: $phase.phaseName)
                    .font(DesignSystem.Typography.body)
                    .fieldStyle()
            }
            
            // Timeline Section
            timelineView
            
            // Manager Selection
            managerSelectionView
            
            // Team Members Selection
            teamMemberSelectionView
            
            // Departments
            departmentsView
            
            Divider()
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Timeline View
    
    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.secondary)
            
            // Start Date
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Start Date", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $phase.hasStartDate)
                        .labelsHidden()
                }
                
                if phase.hasStartDate {
                    DatePicker("Select start date", selection: $phase.startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.vertical, 4)
            
            // End Date
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("End Date", systemImage: "calendar.badge.minus")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $phase.hasEndDate)
                        .labelsHidden()
                }
                
                if phase.hasEndDate {
                    DatePicker("Select end date", selection: $phase.endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.vertical, 4)
            
            // Date Validation Warnings
            if phase.hasStartDate && phase.hasEndDate && phase.endDate <= phase.startDate {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("End date must be after start date")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .transition(.opacity.animation(.easeInOut))
            }
            
            // Phase Timeline Validation
            if let phaseIndex = viewModel.phases.firstIndex(where: { $0.id == phase.id }),
               phaseIndex > 0,
               let previousPhase = viewModel.phases[safe: phaseIndex - 1],
               previousPhase.hasEndDate,
               phase.hasStartDate,
               phase.startDate <= previousPhase.endDate {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Phase must start after Phase \(previousPhase.phaseNumber) ends")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .transition(.opacity.animation(.easeInOut))
            }
        }
    }
    
    // MARK: - Manager Selection
    
    private var managerSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase Manager (Approver)").font(.caption).foregroundColor(.secondary)
            
            if let manager = phase.selectedManager {
                HStack {
                    VStack(alignment: .leading) {
                        Text(manager.name).fontWeight(.bold)
                        Text(manager.phoneNumber).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { phase.selectedManager = nil }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
                .padding(10).background(Color.blue.opacity(0.1)).cornerRadius(8)
            } else {
                SearchableDropdownView(
                    title: "Search name or phone number...",
                    searchText: $phase.managerSearchText,
                    items: viewModel.filteredApprovers(for: phase),
                    itemContent: { user in Text("\(user.name) - \(user.phoneNumber)") },
                    onSelect: { manager in
                        viewModel.updatePhaseManager(phase.id, manager: manager)
                    }
                )
            }
        }
    }
    
    // MARK: - Team Members Selection
    
    private var teamMemberSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Team Members (Users)").font(.caption).foregroundColor(.secondary)
            
            SearchableDropdownView(
                title: "Search name or phone number...",
                searchText: $phase.teamMemberSearchText,
                items: viewModel.filteredTeamMembers(for: phase),
                itemContent: { user in Text("\(user.name) - \(user.phoneNumber)") },
                onSelect: { member in
                    viewModel.selectTeamMember(for: phase.id, member: member)
                }
            )
            
            if !phase.selectedTeamMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(phase.selectedTeamMembers)) { member in
                            TagView(user: member, onRemove: {
                                viewModel.removeTeamMember(for: phase.id, member: member)
                            })
                        }
                    }
                    .padding(.top, 5)
                }
            }
        }
    }
    
    // MARK: - Departments View
    
    private var departmentsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Departments")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.secondary)
            
            ForEach($phase.departments) { $dept in
                DepartmentInputRow(item: $dept)
            }
            
            Button(action: {
                HapticManager.selection()
                viewModel.addDepartment(to: phase.id)
            }) {
                Label("Add Department", systemImage: "plus.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(DesignSystem.Typography.caption1)
                    .fontWeight(.medium)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
                .overlay(alignment: .trailing) {
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }.padding(.trailing, 8)
                    }
                }
            
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
                .symbolRenderingMode(.hierarchical)
            
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
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
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
