//
//  ProjectReviewScreen.swift
//  AVREntertainment
//
//  Created for project review before creation
//

import SwiftUI

struct ProjectReviewScreen: View {
    let viewModel: CreateProjectViewModel
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onEdit: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }
    
    private var currencySymbol: String {
        switch viewModel.currency {
        case "INR":
            return "₹"
        default:
            return "₹"
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return currencySymbol + formatted
    }
    
    var body: some View {
        Form {
            // Project Basics Section
            Section {
                projectBasicsContent
            } header: {
                ReviewSectionHeader(title: "Project Basics", icon: "info.circle.fill")
            }
            
            // Description Section
            if !viewModel.projectDescription.isEmpty {
                Section {
                    Text(viewModel.projectDescription)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.primary)
                        .padding(.vertical, DesignSystem.Spacing.extraSmall)
                } header: {
                    Text("Description")
                        .textCase(nil)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Project Team Section
            Section {
                projectTeamContent
            } header: {
                Text("Project Team")
                    .textCase(nil)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Phases Section
            Section {
                ForEach(viewModel.phases) { phase in
                    PhaseReviewCard(phase: phase, currencySymbol: currencySymbol)
                }
            } header: {
                ReviewSectionHeader(title: "Project Phases", icon: "arrow.triangle.2.circlepath")
            }
        }
        .navigationTitle("Review Project")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Edit") {
                    HapticManager.selection()
                    onEdit()
                }
                .foregroundColor(.accentColor)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirm") {
                    HapticManager.impact(.medium)
                    onConfirm()
                }
                .fontWeight(.semibold)
                .disabled(viewModel.isLoading)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Creating project...")
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Project Basics Content
    private var projectBasicsContent: some View {
        Group {
            ReviewInfoRow(label: "Project Name", value: viewModel.projectName.isEmpty ? "Not provided" : viewModel.projectName)
            ReviewInfoRow(label: "Client", value: viewModel.client.isEmpty ? "Not provided" : viewModel.client)
            ReviewInfoRow(label: "Location", value: viewModel.location.isEmpty ? "Not provided" : viewModel.location)
            ReviewInfoRow(label: "Currency", value: currencySymbol + " " + viewModel.currency)
            ReviewInfoRow(label: "Total Budget", value: formatAmount(viewModel.totalBudget))
        }
    }
    
    // MARK: - Project Team Content
    private var projectTeamContent: some View {
        Group {
            // Manager (Single)
            if let manager = viewModel.selectedProjectManager {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Manager")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                    .padding(.top, DesignSystem.Spacing.extraSmall)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 6, height: 6)
                        Text(manager.name)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.primary)
                    }
                    .padding(.leading, 12)
                }
                .padding(.vertical, DesignSystem.Spacing.extraSmall)
            }
            
            // Team Members
            if !viewModel.selectedProjectTeamMembers.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Team Members (\(viewModel.selectedProjectTeamMembers.count))")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                    .padding(.top, viewModel.selectedProjectManager == nil ? DesignSystem.Spacing.extraSmall : DesignSystem.Spacing.small)
                    
                    ForEach(Array(viewModel.selectedProjectTeamMembers), id: \.id) { member in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 6, height: 6)
                            Text(member.name)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 12)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.extraSmall)
            }
        }
    }
}

// MARK: - Phase Review Card
struct PhaseReviewCard: View {
    let phase: PhaseItem
    let currencySymbol: String
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }
    
    private var phaseBudget: Double {
        phase.departments.compactMap { Double(removeFormatting(from: $0.amount)) }.reduce(0, +)
    }
    
    // Helper to remove formatting (commas, spaces, etc.)
    private func removeFormatting(from value: String) -> String {
        return value.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return currencySymbol + formatted
    }
    
    private var timelineText: String {
        let startDate = dateFormatter.string(from: phase.startDate)
        let endDate = dateFormatter.string(from: phase.endDate)
        return "Start: \(startDate) • End: \(endDate)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Phase Header
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phase \(phase.phaseNumber)")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(.primary)
                        
                        Text(phase.phaseName.isEmpty ? "Unnamed Phase" : phase.phaseName)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatAmount(phaseBudget))
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.accentColor)
                }
                
                // Timeline
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(timelineText)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                }
            }
            
            // Departments
            if !phase.departments.isEmpty && !phase.departments.allSatisfy({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("DEPARTMENTS")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(phase.departments) { dept in
                        if !dept.name.trimmingCharacters(in: .whitespaces).isEmpty {
                            HStack {
                                Text(dept.name)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(formatAmount(Double(removeFormatting(from: dept.amount)) ?? 0))
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            } else {
                Text("No departments added")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small)
    }
}

// MARK: - Supporting Views
private struct ReviewSectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(DesignSystem.Typography.callout)
                .symbolRenderingMode(.hierarchical)
            
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.secondary)
        }
        .textCase(nil)
    }
}

private struct ReviewInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

