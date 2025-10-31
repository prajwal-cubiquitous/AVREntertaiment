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
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Project Information
                projectDetailsSection
                
                // MARK: - Phases Section
                phasesSection
                
                // MARK: - Project Team Section
                projectTeamSection

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
                
                // Client
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Client")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter client name", text: $viewModel.client)
                        .font(DesignSystem.Typography.body)
                        .fieldStyle()
                }
                
                // Location
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Location")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter location", text: $viewModel.location)
                        .font(DesignSystem.Typography.body)
                        .fieldStyle()
                }
                
                // Currency Picker (currently only INR)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Currency")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Picker("Currency", selection: $viewModel.currency) {
                        Text("₹ Indian Rupee").tag("INR")
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
                // Use the phase ID for stable identification
                ForEach(viewModel.phases) { phase in
                    PhaseCardView(
                        phase: phaseBinding(for: phase.id),
                        phaseNumber: phase.phaseNumber,
                        canDelete: viewModel.phases.count > 1,
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
                // Managers (Approvers) - allow multiple
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Managers (Approvers)").font(.caption).foregroundColor(.secondary)
                    if !viewModel.selectedProjectManagers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(viewModel.selectedProjectManagers, id: \.self) { manager in
                                HStack {
                                    Text(manager.name).fontWeight(.bold)
                                    Spacer()
                                    Button(action: {
                                        viewModel.selectedProjectManagers.removeAll { $0 == manager }
                                    }) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
                                }
                                .padding(10).background(Color.blue.opacity(0.08)).cornerRadius(8)
                            }
                        }
                    }
                    SearchableDropdownView(
                        title: "Search manager name/email/phone",
                        searchText: $viewModel.projectManagerSearchText,
                        items: viewModel.filteredProjectManagers(),
                        itemContent: { user in Text("\(user.name) - \(user.email ?? user.phoneNumber)") },
                        onSelect: { user in
                            if !viewModel.selectedProjectManagers.contains(user) { viewModel.selectedProjectManagers.append(user) }
                            viewModel.projectManagerSearchText = ""
                        }
                    )
                }

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
                }
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
            showingReviewScreen = true
        }) {
            HStack {
                Label("Review Project", systemImage: "doc.text.magnifyingglass")
                    .symbolRenderingMode(.hierarchical)
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
    let phaseNumber: Int
    let canDelete: Bool
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
            }

            // Timeline Section
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
            }

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
                    DepartmentInputRow(item: $dept)
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
            }

            Divider()
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
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
                        .onSubmit {
                            if item.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                item.amount = "0"
                            }
                        }
                }
            }
            
            Divider()
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .onAppear {
            if item.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                item.amount = "0"
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
