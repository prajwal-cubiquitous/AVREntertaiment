//
//  CreateProjectView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

// CreateProjectView.swift

import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import AVFoundation

struct CreateProjectView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var viewModel = CreateProjectViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingReviewScreen = false
    @State private var showingFileViewer = false
    @State private var showingCamera = false
    @State private var expandedPhaseIds: Set<UUID> = [] // Track which phases are expanded
    @State private var showingClearFormConfirmation = false
    
    let projectToEdit: Project? // Optional project for editing
    
    init(projectToEdit: Project? = nil) {
        self.projectToEdit = projectToEdit
    }
    
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
                    VStack(spacing: DesignSystem.Spacing.medium) {
                        // MARK: - Draft Management Section
                        draftManagementSection
                        
                        // MARK: - Project Information
                        projectDetailsSectionScrollView
                        
                        // MARK: - Phases Section
                        phasesSectionScrollView
                        
                        // MARK: - Project Team Section
                        projectTeamSectionScrollView
                        
                        // MARK: - Attachment Section
//                        attachmentSectionScrollView
                        
                        // MARK: - Submit Action
                        submitSectionScrollView
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.medium)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(projectToEdit != nil ? "Edit Project" : "New Project")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        // Clear saved data button (only when saved data exists)
                        if viewModel.hasSavedLocalData {
                            Button(action: {
                                HapticManager.selection()
                                showingClearFormConfirmation = true
                            }) {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .foregroundColor(.orange)
                                    .symbolRenderingMode(.hierarchical)
                            }
                            .help("Clear saved form data")
                        }
                        
                        // Save Draft button (only when there's any data)
                        if viewModel.hasAnyData {
                            Button(action: {
                                HapticManager.selection()
                                viewModel.saveDraft()
                            }) {
                                if viewModel.isSavingDraft {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Label("Save Draft", systemImage: "square.and.arrow.down")
                                }
                            }
                            .disabled(viewModel.isSavingDraft)
                        }
                    }
                }
                .onAppear {
                    viewModel.setAuthService(authService)
                    
                    // Load project for editing if provided
                    if let project = projectToEdit {
                        Task {
                            await viewModel.loadProjectForEditing(project)
                            // Expand all phases when editing
                            expandedPhaseIds = Set(viewModel.phases.map { $0.id })
                        }
                    } else {
                        // Restore expanded phases from saved state
                        if !viewModel.restoredExpandedPhaseIds.isEmpty {
                            expandedPhaseIds = viewModel.restoredExpandedPhaseIds.filter { id in
                                viewModel.phases.contains { $0.id == id }
                            }
                        }
                        // If no phases are expanded, expand the first one by default
                        if expandedPhaseIds.isEmpty, let firstPhaseId = viewModel.phases.first?.id {
                            expandedPhaseIds = [firstPhaseId]
                        }
                        // Load drafts
                        Task {
                            await viewModel.loadDrafts()
                        }
                    }
                }
                .onChange(of: expandedPhaseIds) { oldValue, newValue in
                    // Save expanded phase state when it changes
                    viewModel.saveFormState(expandedPhaseIds: newValue)
                }
                .onChange(of: viewModel.phases.count) { oldCount, newCount in
                    // When a new phase is added, collapse all and expand the new one
                    if newCount > oldCount, let newPhaseId = viewModel.phases.last?.id {
                        withAnimation(DesignSystem.Animation.standardSpring) {
                            expandedPhaseIds = [newPhaseId]
                        }
                    } else if newCount < oldCount {
                        // When a phase is removed, update expanded set
                        expandedPhaseIds = expandedPhaseIds.filter { id in
                            viewModel.phases.contains { $0.id == id }
                        }
                        // If no phases are expanded, expand the first one
                        if expandedPhaseIds.isEmpty, let firstPhaseId = viewModel.phases.first?.id {
                            expandedPhaseIds = [firstPhaseId]
                        }
                    }
                }
                .onChange(of: viewModel.restoredExpandedPhaseIds) { oldValue, newValue in
                    // Reset expanded phases when form is cleared (restoredExpandedPhaseIds becomes empty)
                    if newValue.isEmpty && !oldValue.isEmpty {
                        // Form was reset, expand first phase
                        if let firstPhaseId = viewModel.phases.first?.id {
                            expandedPhaseIds = [firstPhaseId]
                        } else {
                            expandedPhaseIds = []
                        }
                    }
                }
                .onChange(of: viewModel.firstInvalidFieldId) { fieldId in
                    if let fieldId = fieldId {
                        print("🔄 Attempting to scroll to field: \(fieldId)")
                        
                        // Extract phase ID from field ID (format: "phase_{uuid}_name" or "phase_{uuid}_dates", etc.)
                        if fieldId.hasPrefix("phase_") {
                            // Remove "phase_" prefix
                            let withoutPrefix = String(fieldId.dropFirst(6)) // "phase_".count = 6
                            // Find the next underscore to get the UUID
                            if let underscoreIndex = withoutPrefix.firstIndex(of: "_") {
                                let uuidString = String(withoutPrefix[..<underscoreIndex])
                                if let phaseId = UUID(uuidString: uuidString) {
                                    // Expand the phase that has the error
                                    withAnimation(DesignSystem.Animation.standardSpring) {
                                        expandedPhaseIds.insert(phaseId)
                                    }
                                }
                            }
                        }
                        
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
                .confirmationDialog("Clear Form", isPresented: $showingClearFormConfirmation, titleVisibility: .visible) {
                    Button("Clear Form", role: .destructive) {
                        HapticManager.impact(.medium)
                        viewModel.clearFormAndLocalStorage()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will clear all form fields and remove auto-saved data from local storage. This action cannot be undone.")
                }
                .confirmationDialog("Select Attachment", isPresented: $viewModel.showingAttachmentOptions, titleVisibility: .visible) {
                    Button("Camera") {
                        showingCamera = true
                    }
                    
                    Button("Select from Photos") {
                        viewModel.showingImagePicker = true
                    }
                    
                    Button("Select from Files") {
                        viewModel.showingDocumentPicker = true
                    }
                    
                    Button("Cancel", role: .cancel) { }
                }
                .sheet(isPresented: $viewModel.showingImagePicker) {
                    ProjectImagePicker(selectedImage: Binding(
                        get: { nil },
                        set: { image in
                            viewModel.handleImageSelection(image)
                        }
                    ))
                }
                .sheet(isPresented: $showingCamera) {
                    ProjectCameraPicker(
                        selectedImage: Binding(
                            get: { nil },
                            set: { image in
                                viewModel.handleImageSelection(image)
                            }
                        ),
                        onDismiss: {
                            showingCamera = false
                        }
                    )
                }
                .sheet(isPresented: $viewModel.showingDocumentPicker) {
                    ProjectDocumentPicker(
                        allowedTypes: [.pdf, .image],
                        onDocumentPicked: viewModel.handleDocumentSelection
                    )
                }
                .sheet(isPresented: $showingFileViewer) {
                    if let urlString = viewModel.attachmentURL,
                       let url = URL(string: urlString) {
                        FileViewerSheet(fileURL: url, fileName: viewModel.attachmentName)
                    }
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
                .sheet(isPresented: $viewModel.showDraftList) {
                    DraftProjectListView(viewModel: viewModel)
                }
            }
        }
    }
    
    // MARK: - Draft Management Section
    
    @ViewBuilder
    private var draftManagementSection: some View {
        if !viewModel.drafts.isEmpty || viewModel.hasAnyData {
            VStack(spacing: DesignSystem.Spacing.small) {
                // View Drafts Button (only show if drafts exist)
                if !viewModel.drafts.isEmpty {
                    Button(action: {
                        HapticManager.selection()
                        viewModel.showDraftList = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("View Draft Project Creations")
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.vertical, DesignSystem.Spacing.small)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                }
                
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.top, DesignSystem.Spacing.small)
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
                
                // Planned Date
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Planned Date")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        DatePicker("Select planned start date", selection: $viewModel.plannedDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(DesignSystem.CornerRadius.field)
                    
                    Text("Project will be in LOCKED status until this date, then automatically become ACTIVE")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .id("plannedDate")
                
                // Currency Picker
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(DesignSystem.CornerRadius.field)
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
                        totalPhases: viewModel.phases.count,
                        isExpanded: expandedPhaseIds.contains(phase.id),
                        canDelete: viewModel.phases.count > 1,
                        viewModel: viewModel,
                        onToggleExpand: {
                            withAnimation(DesignSystem.Animation.standardSpring) {
                                if expandedPhaseIds.contains(phase.id) {
                                    expandedPhaseIds.remove(phase.id)
                                } else {
                                    expandedPhaseIds.insert(phase.id)
                                }
                            }
                        },
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
                        itemContent: { user in
                            TruncatedTextWithTooltip(
                                "\(user.name) - \(user.phoneNumber)",
                                font: .body,
                                foregroundColor: .primary,
                                lineLimit: 1
                            )
                        },
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
                    
                    HStack {
                        TextField("Enter project name", text: $viewModel.projectName)
                            .font(DesignSystem.Typography.body)
                            .fieldStyle()
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.field)
                                    .stroke(viewModel.projectNameError != nil ? Color.red : Color.clear, lineWidth: 1)
                            )
                            .onChange(of: viewModel.projectName) { oldValue, newValue in
                                // Debounced check for duplicate project names
                                viewModel.debouncedCheckProjectName()
                            }
                        
                        // Loading indicator while checking
                        if viewModel.isCheckingProjectName {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.leading, 8)
                        }
                    }
                    
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
                    Text("Planned Start Date")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        DatePicker("Select planned start date", selection: $viewModel.plannedDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(DesignSystem.CornerRadius.field)
                    
                    Text("Project will be in LOCKED status until this date, then automatically become ACTIVE")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .id("plannedDate")
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(DesignSystem.CornerRadius.field)
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
                        totalPhases: viewModel.phases.count,
                        isExpanded: expandedPhaseIds.contains(phase.id),
                        canDelete: viewModel.phases.count > 1,
                        viewModel: viewModel,
                        onToggleExpand: {
                            withAnimation(DesignSystem.Animation.standardSpring) {
                                if expandedPhaseIds.contains(phase.id) {
                                    expandedPhaseIds.remove(phase.id)
                                } else {
                                    expandedPhaseIds.insert(phase.id)
                                }
                            }
                        },
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
                        itemContent: { user in
                            TruncatedTextWithTooltip(
                                "\((user.name.count > 25 ? String(user.name.prefix(25)) + "..." : user.name)) - \(user.phoneNumber)",
                                font: .body,
                                foregroundColor: .primary,
                                lineLimit: 1
                            )
                        },
                        onSelect: { member in
                            HapticManager.selection()
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
    
    
//    private var attachmentSectionScrollView: some View {
//        FormSectionView(header: SectionHeaderLabel(title: "Project Attachment", icon: "paperclip")) {
//            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
//                if let attachmentName = viewModel.attachmentName {
//                    // Show attached file
//                    HStack(spacing: 12) {
//                        // File info - not clickable
//                        HStack {
//                            Image(systemName: fileIcon(for: attachmentName))
//                                .font(.title3)
//                                .foregroundColor(.blue)
//                            
//                            VStack(alignment: .leading, spacing: 4) {
//                                TruncatedTextWithTooltip(
//                                    attachmentName,
//                                    font: .subheadline,
//                                    fontWeight: .medium,
//                                    foregroundColor: .primary,
//                                    lineLimit: 1
//                                )
//                                
//                                Text("Tap preview to view")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                            }
//                            
//                            Spacer()
//                        }
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(Color.blue.opacity(0.1))
//                        .cornerRadius(8)
//                        
//                        // Preview button - separate icon button
//                        Button(action: {
//                            HapticManager.selection()
//                            showingFileViewer = true
//                        }) {
//                            Image(systemName: "eye.fill")
//                                .font(.title3)
//                                .foregroundColor(.blue)
//                                .frame(width: 44, height: 44)
//                                .background(Color.blue.opacity(0.1))
//                                .clipShape(Circle())
//                                .contentShape(Circle())
//                        }
//                        .buttonStyle(.plain)
//                        
//                        // Remove button - separate action
//                        Button(action: {
//                            HapticManager.selection()
//                            withAnimation(.easeInOut) {
//                                viewModel.removeAttachment()
//                            }
//                        }) {
//                            Image(systemName: "trash.fill")
//                                .font(.title3)
//                                .foregroundColor(.red)
//                                .frame(width: 44, height: 44)
//                                .background(Color.red.opacity(0.1))
//                                .clipShape(Circle())
//                                .contentShape(Circle())
//                        }
//                        .buttonStyle(.plain)
//                    }
//                } else {
//                    // Add attachment button
//                    Button(action: {
//                        viewModel.showingAttachmentOptions = true
//                    }) {
//                        HStack {
//                            Image(systemName: "paperclip")
//                                .font(.title3)
//                            Text("Add Attachment")
//                                .fontWeight(.medium)
//                            Spacer()
//                        }
//                        .foregroundColor(.blue)
//                        .padding()
//                        .background(Color(UIColor.tertiarySystemFill))
//                        .cornerRadius(8)
//                    }
//                    .buttonStyle(.plain)
//                }
//                
//                // Upload progress
//                if viewModel.isUploading {
//                    VStack(spacing: 8) {
//                        ProgressView(value: viewModel.uploadProgress)
//                            .progressViewStyle(LinearProgressViewStyle())
//                        Text("Uploading... \(Int(viewModel.uploadProgress * 100))%")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                }
//            }
//            .padding(.horizontal, DesignSystem.Spacing.medium)
//            .padding(.vertical, DesignSystem.Spacing.small)
//        }
//    }
    
    private var submitSectionScrollView: some View {
        VStack {
            submitButton
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.medium)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fileIcon(for fileName: String) -> String {
        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".pdf") {
            return "doc.fill"
        } else if lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".jpeg") {
            return "photo.fill"
        } else if lowercased.hasSuffix(".png") {
            return "photo.fill"
        } else {
            return "doc.fill"
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
    let totalPhases: Int
    let isExpanded: Bool
    let canDelete: Bool
    @ObservedObject var viewModel: CreateProjectViewModel
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onAddDepartment: () -> Void
    
    // Check if phase has required fields filled
    private var hasRequiredFields: Bool {
        !phase.phaseName.trimmingCharacters(in: .whitespaces).isEmpty &&
        phase.endDate > phase.startDate &&
        !phase.departments.isEmpty &&
        phase.departments.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Phase Header - Always visible, clickable to expand/collapse
            Button(action: {
                HapticManager.selection()
                onToggleExpand()
            }) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    HStack {
                        // Phase number with total (e.g., "Phase 1/2")
                        Text("Phase \(phaseNumber)/\(totalPhases)")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Completion indicator
                        if hasRequiredFields {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 18))
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                                .font(.system(size: 18))
                        }
                        
                        // Expand/Collapse chevron
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        
                        // Delete Phase Button
                        if canDelete {
                            Button(action: {
                                HapticManager.selection()
                                onDelete()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, DesignSystem.Spacing.small)
                        }
                    }
                    
                    // Phase Budget - Always visible in collapsed state
                    HStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "indianrupeesign.circle.fill")
                            .foregroundColor(.blue)
                            .font(DesignSystem.Typography.caption1)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text("Budget:")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.phaseBudgetFormatted(for: phase.id))
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(DesignSystem.Spacing.medium)
            
            // Expandable Content
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Divider()
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                    
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
                    .padding(.horizontal, DesignSystem.Spacing.medium)

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
                            
                            DatePicker("Select start date", selection: $phase.startDate, in: viewModel.plannedDate..., displayedComponents: .date)
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
                    .padding(.horizontal, DesignSystem.Spacing.medium)

                    // Manager & Team note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manager & Team for this phase are inherited from Project Team section")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)

                    // Departments
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Departments")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(.secondary)

                        ForEach($phase.departments) { $dept in
                            DepartmentInputRow(
                                item: $dept,
                                errorMessage: viewModel.departmentNameError(for: phase.id, departmentId: dept.id),
                                viewModel: viewModel,
                                canDelete: phase.departments.count > 1,
                                onDelete: {
                                    viewModel.removeDepartmentById(from: phase.id, departmentId: dept.id)
                                }
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
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    
                    // Phase Budget Summary
                    phaseBudgetView(for: phase.id)
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.top, DesignSystem.Spacing.small)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, DesignSystem.Spacing.medium)
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
                    HapticManager.selection()
                    selectedUser = user
                }) {
                    HStack {
                        let truncatedName = user.name.count > 25 ? String(user.name.prefix(25)) + "..." : user.name
                        TruncatedTextWithTooltip(
                            "\(truncatedName) - \(user.email ?? user.phoneNumber)",
                            font: .body,
                            foregroundColor: .primary,
                            lineLimit: 1
                        )
                        if selectedUser?.phoneNumber == user.phoneNumber {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                if let selectedUser = selectedUser {
                    let truncatedName = selectedUser.name.count > 25 ? String(selectedUser.name.prefix(25)) + "..." : selectedUser.name
                    TruncatedTextWithTooltip(
                        truncatedName,
                        font: .body,
                        foregroundColor: .primary,
                        lineLimit: 1
                    )
                } else {
                    Text(placeholder)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
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

struct SearchableDropdownView<Content: View>: View {
    let title: String
    @Binding var searchText: String
    let items: [User]
    let itemContent: (User) -> Content
    let onSelect: (User) -> Void
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField(title, text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isSearchFocused)
                .overlay(alignment: .trailing) {
                    if !searchText.isEmpty {
                        Button(action: { 
                            searchText = ""
                            isSearchFocused = true
                        }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }.padding(.trailing, 8)
                    }
                }
                .onTapGesture {
                    isSearchFocused = true
                }
            
            // Show dropdown when focused or when there's search text
            if !items.isEmpty && (isSearchFocused || !searchText.isEmpty) {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            Button(action: { 
                                HapticManager.selection()
                                onSelect(item)
                                isSearchFocused = false
                            }) {
                                HStack {
                                    itemContent(item)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color.clear)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(1000)
            }
        }
    }
}

struct TagView: View {
    let user: User
    let onRemove: () -> Void
    
    private var truncatedName: String {
        user.name.count > 25 ? String(user.name.prefix(25)) + "..." : user.name
    }
    
    var body: some View {
        HStack(spacing: 4) {
            TruncatedTextWithTooltip(
                truncatedName,
                font: .caption,
                foregroundColor: .primary,
                lineLimit: 1
            )
            Button(action: {
                HapticManager.selection()
                onRemove()
            }) {
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
    @ObservedObject var viewModel: CreateProjectViewModel
    let canDelete: Bool
    let onDelete: () -> Void
    @State private var rawAmountInput: String = ""
    
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
                    HStack{
                        Text("Budget")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        if canDelete {
                            Button(action: {
                                HapticManager.selection()
                                onDelete()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.system(size: 8))
                                    .frame(width: 16, height: 16)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete department")
                            .accessibilityHint("Removes this department from the phase")
                        }
                    }
                    
                    TextField("", text: Binding(
                        get: { rawAmountInput.isEmpty ? item.amount : rawAmountInput },
                        set: { newValue in
                            // Store raw input
                            rawAmountInput = newValue
                            // Format and update the item
                            let formatted = viewModel.formatAmountInput(newValue)
                            item.amount = formatted
                            // Update raw input to show formatted value
                            rawAmountInput = formatted
                        }
                    ))
                        .keyboardType(.decimalPad)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Spacing.small)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(DesignSystem.CornerRadius.field)
                        .frame(width: 100)
                        .onAppear {
                            // Initialize raw input with current amount
                            rawAmountInput = item.amount
                        }
                        .onChange(of: item.amount) { oldValue, newValue in
                            // Sync raw input when item.amount changes externally
                            if rawAmountInput != newValue {
                                rawAmountInput = newValue
                            }
                        }
                        .onSubmit {
                            if item.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                item.amount = "0"
                                rawAmountInput = "0"
                            }
                        }
                }
                
                // Delete Button - Following Apple's design guidelines for destructive actions
//                if canDelete {
//                    Button(action: {
//                        HapticManager.selection()
//                        onDelete()
//                    }) {
//                        Image(systemName: "trash")
//                            .foregroundColor(.red)
//                            .font(.system(size: 16))
//                            .frame(width: 32, height: 32)
//                            .contentShape(Rectangle())
//                    }
//                    .buttonStyle(.plain)
//                    .accessibilityLabel("Delete department")
//                    .accessibilityHint("Removes this department from the phase")
//                }
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

// MARK: - Project Document Picker
struct ProjectDocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onDocumentPicked: (Result<[URL], Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ProjectDocumentPicker
        
        init(_ parent: ProjectDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentPicked(.success(urls))
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation if needed
        }
    }
}

// MARK: - Project Image Picker
struct ProjectImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ProjectImagePicker
        
        init(_ parent: ProjectImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error loading image: \(error.localizedDescription)")
                            return
                        }
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Project Camera Picker
struct ProjectCameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ProjectCameraPicker
        
        init(_ parent: ProjectCameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Extract image on main thread
            DispatchQueue.main.async {
                if let editedImage = info[.editedImage] as? UIImage {
                    self.parent.selectedImage = editedImage
                } else if let originalImage = info[.originalImage] as? UIImage {
                    self.parent.selectedImage = originalImage
                }
            }
            
            // Dismiss the picker first
            picker.dismiss(animated: true) {
                // After picker dismisses, dismiss the sheet
                DispatchQueue.main.async {
                    self.parent.onDismiss()
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                // After picker dismisses, dismiss the sheet
                DispatchQueue.main.async {
                    self.parent.onDismiss()
                }
            }
        }
    }
}

// MARK: - Preview Provider
struct CreateProjectView_Previews: PreviewProvider {
    static var previews: some View {
        CreateProjectView()
    }
}
