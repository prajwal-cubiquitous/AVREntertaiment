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
    @State private var showingReviewScreen = false
    
    let currencies = [
        ("₹ Indian Rupee", "INR"),
        ("$ US Dollar", "USD"),
        ("€ Euro", "EUR"),
        ("£ British Pound", "GBP")
    ]
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.large) {
                        // MARK: - Project Information
                        projectDetailsSectionScrollView
                        
                        // MARK: - Phases Section
                        phasesSectionScrollView
                        
                        // MARK: - Project Team Section
                        projectTeamSectionScrollView

                        // MARK: - Template Overrides Section
                        templateOverridesSectionScrollView
                        
                        // MARK: - Submit Action
                        submitSectionScrollView
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.medium)
                }
                .background(Color(.systemGroupedBackground))
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
                .onChange(of: viewModel.firstInvalidFieldId) { fieldId in
                    if let fieldId = fieldId {
                        print("🔄 Attempting to scroll to field: \(fieldId)")
                        // Use Task to ensure it runs after view updates
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            withAnimation(.easeInOut(duration: 0.6)) {
                                proxy.scrollTo(fieldId, anchor: .top)
                            }
                        }
                    }
                }
                .alert("Project Status", isPresented: $viewModel.showAlert) {
                    Button("OK", role: .cancel) { 
                        if viewModel.showSuccessMessage {
                            dismiss()
                        }
                    }
                } message: {
                    Text(viewModel.alertMessage)
                }
                .sheet(isPresented: $showingReviewScreen) {
                    NavigationView {
                        ProjectReviewScreen(
                            viewModel: viewModel,
                            onConfirm: {
                                viewModel.saveProject()
                                // Dismiss review screen after starting save
                                showingReviewScreen = false
                                // Dismiss main view after save completes (handled in alert)
                            },
                            onCancel: {
                                showingReviewScreen = false
                            },
                            onEdit: {
                                // Dismiss review screen to go back to editing
                                showingReviewScreen = false
                            }
                        )
                    }
                    .presentationDetents([.large])
                }
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
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                                .stroke(viewModel.projectNameError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                    
                    if let error = viewModel.projectNameError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("projectName")
                
                // Client
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Client")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter client name", text: $viewModel.client)
                        .font(DesignSystem.Typography.body)
                        .fieldStyle()
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                                .stroke(viewModel.clientError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                    
                    if let error = viewModel.clientError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("client")
                
                // Location
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Location")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter location", text: $viewModel.location)
                        .font(DesignSystem.Typography.body)
                        .fieldStyle()
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                                .stroke(viewModel.locationError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                    
                    if let error = viewModel.locationError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("location")
                
                // Currency Picker (currently only INR)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Currency")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Picker("Currency", selection: $viewModel.currency) {
                        ForEach(currencies, id: \.1) { currency in
                            Text(currency.0).tag(currency.1)
                        }
                    }
                    .pickerStyle(.menu)
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
                                .stroke(viewModel.projectDescriptionError != nil ? Color.red : Color(.separator), lineWidth: viewModel.projectDescriptionError != nil ? 1 : 0.5)
                        )
                    
                    if let error = viewModel.projectDescriptionError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("projectDescription")
            }
            .padding(.vertical, DesignSystem.Spacing.small)
        } header: {
            SectionHeaderLabel(title: "Project Details", icon: "folder.badge.plus")
        }
    }
    
    private var phasesSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spacing.large) {
                // Use the phase ID for stable identification
                ForEach(viewModel.phases) { phase in
                    PhaseCardView(
                        phase: phaseBinding(for: phase.id),
                        phaseNumber: phase.phaseNumber,
                        canDelete: viewModel.phases.count > 1,
                        viewModel: viewModel,
                        onDelete: {
                            HapticManager.selection()
                            viewModel.removePhaseById(phase.id)
                        },
                        onAddDepartment: {
                            viewModel.addDepartment(to: phase.id)
                        }
                    )
                    .id(phase.id) // Critical: Tell SwiftUI to track by ID
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
    
    private func phaseBinding(for id: UUID) -> Binding<PhaseItem> {
        Binding(
            get: {
                viewModel.phases.first(where: { $0.id == id }) ?? PhaseItem(phaseNumber: 1)
            },
            set: { newValue in
                if let index = viewModel.phases.firstIndex(where: { $0.id == id }) {
                    viewModel.phases[index] = newValue
                }
            }
        )
    }

    
    // Add this helper method to CreateProjectView
    private func binding(for phaseId: UUID) -> Binding<PhaseItem> {
        guard let index = viewModel.phases.firstIndex(where: { $0.id == phaseId }) else {
            fatalError("Phase not found")
        }
        return $viewModel.phases[index]
    }

    // MARK: - Project Team & Managers Section
    private var projectTeamSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                // Manager (Approver) - single selection only
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Manager (Approver)").font(.caption).foregroundColor(.secondary)
                    SingleSelectionPicker(
                        selectedUser: $viewModel.selectedProjectManager,
                        users: viewModel.allApprovers.filter { $0.isActive },
                        placeholder: "Select project manager"
                    )
                    
                    if let error = viewModel.projectManagersError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("projectManagers")

                // Team members
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Team Members").font(.caption).foregroundColor(.secondary)
                    SearchableDropdownView(
                        title: "Search name or phone number...",
                        searchText: $viewModel.projectTeamMemberSearchText,
                        items: viewModel.filteredProjectTeamMembers(),
                        itemContent: { user in Text("\(user.name) - \(user.phoneNumber)") },
                        onSelect: { member in
                            viewModel.selectedProjectTeamMembers.insert(member)
                            viewModel.projectTeamMemberSearchText = ""
                        }
                    )
                    if !viewModel.selectedProjectTeamMembers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack { ForEach(Array(viewModel.selectedProjectTeamMembers)) { member in
                                TagView(user: member, onRemove: { viewModel.selectedProjectTeamMembers.remove(member) })
                            } }
                            .padding(.top, 5)
                        }
                    }
                    
                    if let error = viewModel.projectTeamMembersError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("projectTeamMembers")
            }
            .padding(.vertical, DesignSystem.Spacing.small)
        } header: {
            SectionHeaderLabel(title: "Project Team", icon: "person.3.fill")
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
    
    // MARK: - ScrollView Compatible Sections
    
    private var projectDetailsSectionScrollView: some View {
        FormSectionView(header: SectionHeaderLabel(title: "Project Details", icon: "folder.badge.plus")) {
            VStack(spacing: DesignSystem.Spacing.medium) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Project Name")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter project name", text: $viewModel.projectName)
                        .font(DesignSystem.Typography.body)
                        .fieldStyle()
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                                .stroke(viewModel.projectNameError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                    
                    if let error = viewModel.projectNameError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("projectName")
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                
                Divider()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Client")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter client name", text: $viewModel.client)
                        .font(DesignSystem.Typography.body)
                        .fieldStyle()
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                                .stroke(viewModel.clientError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                    
                    if let error = viewModel.clientError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("client")
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                
                Divider()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Location")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter location", text: $viewModel.location)
                        .font(DesignSystem.Typography.body)
                        .fieldStyle()
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                                .stroke(viewModel.locationError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                    
                    if let error = viewModel.locationError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("location")
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                
                Divider()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Currency")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Picker("Currency", selection: $viewModel.currency) {
                        ForEach(currencies, id: \.1) { currency in
                            Text(currency.0).tag(currency.1)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                
                Divider()
                
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
                                .stroke(viewModel.projectDescriptionError != nil ? Color.red : Color(.separator), lineWidth: viewModel.projectDescriptionError != nil ? 1 : 0.5)
                        )
                    
                    if let error = viewModel.projectDescriptionError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("projectDescription")
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
            }
        }
    }
    
    private var phasesSectionScrollView: some View {
        FormSectionView(header: SectionHeaderLabel(title: "Project Phases", icon: "arrow.triangle.2.circlepath")) {
            VStack(spacing: DesignSystem.Spacing.large) {
                ForEach(viewModel.phases) { phase in
                    PhaseCardView(
                        phase: phaseBinding(for: phase.id),
                        phaseNumber: phase.phaseNumber,
                        canDelete: viewModel.phases.count > 1,
                        viewModel: viewModel,
                        onDelete: {
                            HapticManager.selection()
                            viewModel.removePhaseById(phase.id)
                        },
                        onAddDepartment: {
                            viewModel.addDepartment(to: phase.id)
                        }
                    )
                    .id(phase.id)
                }
                
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
            
            budgetFooterView
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.top, DesignSystem.Spacing.small)
        }
    }
    
    private var projectTeamSectionScrollView: some View {
        FormSectionView(header: SectionHeaderLabel(title: "Project Team", icon: "person.3.fill")) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Manager (Approver)").font(.caption).foregroundColor(.secondary)
                    SingleSelectionPicker(
                        selectedUser: $viewModel.selectedProjectManager,
                        users: viewModel.allApprovers.filter { $0.isActive },
                        placeholder: "Select project manager"
                    )
                    
                    if let error = viewModel.projectManagersError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("projectManagers")
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Team Members").font(.caption).foregroundColor(.secondary)
                    SearchableDropdownView(
                        title: "Search name or phone number...",
                        searchText: $viewModel.projectTeamMemberSearchText,
                        items: viewModel.filteredProjectTeamMembers(),
                        itemContent: { user in Text("\(user.name) - \(user.phoneNumber)") },
                        onSelect: { member in
                            viewModel.selectedProjectTeamMembers.insert(member)
                            viewModel.projectTeamMemberSearchText = ""
                        }
                    )
                    if !viewModel.selectedProjectTeamMembers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack { ForEach(Array(viewModel.selectedProjectTeamMembers)) { member in
                                TagView(user: member, onRemove: { viewModel.selectedProjectTeamMembers.remove(member) })
                            } }
                            .padding(.top, 5)
                        }
                    }
                    
                    if let error = viewModel.projectTeamMembersError {
                        InlineErrorMessage(message: error)
                    }
                }
                .id("projectTeamMembers")
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
            }
        }
    }
    
    private var templateOverridesSectionScrollView: some View {
        FormSectionView(header: SectionHeaderLabel(title: "Template Settings", icon: "doc.on.doc")) {
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
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
        }
    }
    
    private var submitSectionScrollView: some View {
        VStack {
            submitButton
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.medium)
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
            
            // Validate and find first invalid field
            if let firstInvalidField = viewModel.validateAndFindFirstInvalidField() {
                HapticManager.notification(.error)
                // Set the invalid field ID to trigger scroll
                viewModel.firstInvalidFieldId = firstInvalidField
            } else {
                // Form is valid, proceed to review screen
                showingReviewScreen = true
            }
        }) {
            HStack {
                Label("Review Project", systemImage: "doc.text.magnifyingglass")
                    .symbolRenderingMode(.hierarchical)
            }
            .font(DesignSystem.Typography.headline)
        }
        .primaryButton()
        .disabled(viewModel.isLoading)
        .animation(DesignSystem.Animation.standardSpring, value: viewModel.isFormValid)
    }
}

// MARK: - Phase Card View

struct PhaseCardView: View {
    @Binding var phase: PhaseItem
    let phaseNumber: Int
    let canDelete: Bool
    @ObservedObject var viewModel: CreateProjectViewModel
    let onDelete: () -> Void
    let onAddDepartment: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Phase Header
            HStack {
                Text("Phase \(phaseNumber)")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Delete Phase Button
                if canDelete {
                    Button(action: onDelete) {
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
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                            .stroke(viewModel.phaseNameError(for: phase.id) != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
                
                if let error = viewModel.phaseNameError(for: phase.id) {
                    InlineErrorMessage(message: error)
                }
            }
            .id("phase_\(phase.id)_name")

            // Timeline Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Timeline")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)

                // Start Date (Required)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Start Date", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    DatePicker("Select start date", selection: $phase.startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                .padding(.vertical, 4)

                // End Date (Required)
                VStack(alignment: .leading, spacing: 8) {
                    Label("End Date", systemImage: "calendar.badge.minus")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    DatePicker("Select end date", selection: $phase.endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                .padding(.vertical, 4)

                // Date Validation Warnings
                if let error = viewModel.phaseDateError(for: phase.id) {
                    InlineErrorMessage(message: error)
                }
                
                if let timelineError = viewModel.phaseTimelineError(for: phase.id) {
                    InlineErrorMessage(message: timelineError)
                        .id("phase_\(phase.id)_timeline")
                }
            }
            .id("phase_\(phase.id)_dates")

            // Manager & Team note
            VStack(alignment: .leading, spacing: 8) {
                Text("Manager & Team for this phase are inherited from Project Team section")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Departments
            VStack(alignment: .leading, spacing: 12) {
                Text("Departments")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)

                ForEach($phase.departments) { $dept in
                    DepartmentInputRow(
                        item: $dept,
                        errorMessage: viewModel.departmentNameError(for: phase.id, departmentId: dept.id)
                    )
                    .id("phase_\(phase.id)_dept_\(dept.id)_name")
                }

                Button(action: {
                    HapticManager.selection()
                    onAddDepartment()
                }) {
                    Label("Add Department", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.medium)
                }
                .buttonStyle(.plain)
                
                if let error = viewModel.phaseDepartmentsError(for: phase.id) {
                    InlineErrorMessage(message: error)
                }
            }
            .id("phase_\(phase.id)_departments")
            
            // Phase Budget Summary
            phaseBudgetView(for: phase.id)

            Divider()
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Phase Budget View
    
    private func phaseBudgetView(for phaseId: UUID) -> some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "indianrupeesign.circle.fill")
                .foregroundColor(.blue)
                .font(DesignSystem.Typography.callout)
                .symbolRenderingMode(.hierarchical)
            
            Text("Phase Budget:")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(viewModel.phaseBudgetFormatted(for: phaseId))
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .padding(.top, DesignSystem.Spacing.small)
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Reusable Helper Views

// Single Selection Picker for Manager Selection
struct SingleSelectionPicker: View {
    @Binding var selectedUser: User?
    let users: [User]
    let placeholder: String
    
    var body: some View {
        Menu {
            Button(action: {
                selectedUser = nil
            }) {
                HStack {
                    Text("None")
                    if selectedUser == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            ForEach(users.sorted(by: { $0.name < $1.name })) { user in
                Button(action: {
                    selectedUser = user
                }) {
                    HStack {
                        Text("\(user.name) - \(user.email ?? user.phoneNumber)")
                        if selectedUser?.phoneNumber == user.phoneNumber {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedUser?.name ?? placeholder)
                    .foregroundColor(selectedUser == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(DesignSystem.Spacing.medium)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.field)
        }
    }
}

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
    let errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                    Text("Department")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("e.g., Marketing", text: $item.name)
                        .font(DesignSystem.Typography.callout)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.small)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(DesignSystem.CornerRadius.field)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                                .stroke(errorMessage != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.extraSmall) {
                    Text("Budget")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("", text: $item.amount)
                        .keyboardType(.decimalPad)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.small)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(DesignSystem.CornerRadius.field)
                        .frame(width: 100)
                        .onSubmit {
                            if item.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                item.amount = "0"
                            }
                        }
                }
            }
            
            if let error = errorMessage {
                InlineErrorMessage(message: error)
            }
            
            Divider()
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .onAppear {
            if item.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                item.amount = ""
            }
        }
    }
}

// MARK: - Form Section View (ScrollView compatible)
struct FormSectionView<Content: View, Header: View>: View {
    let header: Header
    let content: Content
    
    init(header: Header, @ViewBuilder content: () -> Content) {
        self.header = header
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Header
            header
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.top, DesignSystem.Spacing.medium)
            
            // Content
            VStack(spacing: 0) {
                content
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .padding(.horizontal, DesignSystem.Spacing.medium)
        }
    }
}

// MARK: - Inline Error Message View
struct InlineErrorMessage: View {
    let message: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 14, weight: .medium))
            
            Text(message)
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.top, DesignSystem.Spacing.extraSmall)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Preview Provider
struct CreateProjectView_Previews: PreviewProvider {
    static var previews: some View {
        CreateProjectView()
    }
}
