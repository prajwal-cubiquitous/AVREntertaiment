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
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                // Project Basics Section
                projectBasicsSection
                
                // Phases/Stages Section
                phasesSection
            }
            .padding(DesignSystem.Spacing.medium)
        }
        .navigationTitle("Review Project")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.secondary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
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
    
    // MARK: - Project Basics Section
    private var projectBasicsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            ReviewSectionHeader(title: "Project Basics", icon: "info.circle.fill")
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                ReviewInfoRow(label: "Project Name", value: viewModel.projectName.isEmpty ? "Not provided" : viewModel.projectName)
                ReviewInfoRow(label: "Client", value: viewModel.client.isEmpty ? "Not provided" : viewModel.client)
                ReviewInfoRow(label: "Location", value: viewModel.location.isEmpty ? "Not provided" : viewModel.location)
                ReviewInfoRow(label: "Currency", value: currencySymbol + " " + viewModel.currency)
                ReviewInfoRow(label: "Total Budget", value: formatAmount(viewModel.totalBudget))
            }
            
            if !viewModel.projectDescription.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Description")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text(viewModel.projectDescription)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // Project Team Summary
            Divider()
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Project Team")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Label("\(viewModel.selectedProjectManagers.count) Manager\(viewModel.selectedProjectManagers.count == 1 ? "" : "s")", systemImage: "person.badge.key.fill")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                    
                    Label("\(viewModel.selectedProjectTeamMembers.count) Member\(viewModel.selectedProjectTeamMembers.count == 1 ? "" : "s")", systemImage: "person.2.fill")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Phases Section
    private var phasesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            ReviewSectionHeader(title: "Project Phases", icon: "arrow.triangle.2.circlepath")
            
            ForEach(viewModel.phases) { phase in
                PhaseReviewCard(phase: phase, currencySymbol: currencySymbol)
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
        phase.departments.compactMap { Double($0.amount) }.reduce(0, +)
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
        var parts: [String] = []
        if phase.hasStartDate {
            parts.append("Start: \(dateFormatter.string(from: phase.startDate))")
        }
        if phase.hasEndDate {
            parts.append("End: \(dateFormatter.string(from: phase.endDate))")
        }
        if parts.isEmpty {
            return "No timeline specified"
        }
        return parts.joined(separator: " • ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Phase Header
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                HStack {
                    Text("Phase \(phase.phaseNumber)")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatAmount(phaseBudget))
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.accentColor)
                }
                
                Text(phase.phaseName.isEmpty ? "Unnamed Phase" : phase.phaseName)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                
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
            
            Divider()
            
            // Departments
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Departments")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                if phase.departments.isEmpty || phase.departments.allSatisfy({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    Text("No departments added")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(phase.departments) { dept in
                        if !dept.name.trimmingCharacters(in: .whitespaces).isEmpty {
                            HStack {
                                Text(dept.name)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(formatAmount(Double(dept.amount) ?? 0))
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 4)
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

// MARK: - Supporting Views
private struct ReviewSectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(DesignSystem.Typography.callout)
            
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.primary)
        }
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

