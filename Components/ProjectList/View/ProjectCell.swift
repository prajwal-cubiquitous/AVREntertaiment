//
//  ProjectCell.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//


import SwiftUI

@available(iOS 14.0, *)
struct ProjectCell: View {
    let project: Project
    let role: UserRole?
    let tempApproverStatus: TempApproverStatus?
    @State private var isPressed = false
    
    private var daysRemainingText: String {
        guard let endDateStr = project.endDate else {
            return "No end date"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        guard let endDate = dateFormatter.date(from: endDateStr) else {
            return "Invalid date"
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: endDate)
        
        let components = calendar.dateComponents([.day], from: today, to: end)
        guard let days = components.day else {
            return "Invalid date"
        }
        
        if days < 0 {
            return "Overdue by \(abs(days)) days"
        } else if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "1 day left"
        } else {
            return "\(days) days left"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Header with project name and status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                    Text(project.name)
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer(minLength: DesignSystem.Spacing.small)
                
                HStack(spacing: DesignSystem.Spacing.small) {
                    StatusView(status: project.statusType)
                    
                    // Temp Approver Status Indicator
                    if let tempStatus = tempApproverStatus {
                        TempApproverStatusView(status: tempStatus)
                    }
                    
                    // Edit button for Admin role
                    if role == .ADMIN {
                        NavigationLink(destination: AdminProjectDetailView(project: project)) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.blue)
                                // .symbolRenderingMode(.hierarchical) // iOS 15+ only
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Project details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                // Budget and timeline
                HStack {
                    InfoRow(
                        icon: "indianrupeesign.circle.fill",
                        text: project.budgetFormatted,
                        color: .green
                    )
                    
                    Spacer()
                    
                    if project.startDate != nil || project.endDate != nil {
                        InfoRow(
                            icon: "calendar.circle.fill",
                            text: project.dateRangeFormatted,
                            color: .blue
                        )
                    }
                }
                
                // Team and days remaining
                HStack {
                    InfoRow(
                        icon: "person.2.circle.fill",
                        text: "\(project.teamMembers.count) members",
                        color: .purple
                    )
                    
                    Spacer()
                    
                    if project.endDate != nil && project.statusType == .ACTIVE {
                        Text(daysRemainingText)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(getDaysRemainingColor())
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(shadow: isPressed ? DesignSystem.Shadow.small : DesignSystem.Shadow.medium)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.interactiveSpring, value: isPressed)
        .id("\(project.id ?? "")-\(project.status)") // Force view update when status changes
    }
    
    private func getDaysRemainingColor() -> Color {
        guard let endDateStr = project.endDate else {
            return .secondary.opacity(0.6)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        guard let endDate = dateFormatter.date(from: endDateStr) else {
            return .secondary.opacity(0.6)
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: endDate)
        let components = calendar.dateComponents([.day], from: today, to: end)
        guard let days = components.day else {
            return .secondary.opacity(0.6)
        }
        
        if days < 0 {
            return .red
        } else if days <= 7 {
            return .orange
        } else if days <= 30 {
            return .yellow
        } else {
            return .green
        }
    }
    
}

// MARK: - Helper Subviews

// A reusable view for the Status tag
struct StatusView: View {
    let status: ProjectStatus
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.extraSmall) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .shadow(color: status.color.opacity(0.3), radius: 2, x: 0, y: 1)
            
            Text(status.displayText)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .background(
            Capsule()
                .fill(status.color.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(status.color.opacity(0.3), lineWidth: 0.5)
                )
        )
        .foregroundColor(status.color.darker(by: 20))
    }
}

// A reusable view for the Temp Approver Status tag
struct TempApproverStatusView: View {
    let status: TempApproverStatus
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.extraSmall) {
            Image(systemName: statusIcon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(DesignSystem.Typography.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(statusColor.opacity(0.3), lineWidth: 0.5)
                )
        )
        .foregroundColor(statusColor.darker(by: 20))
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        case .active: return .blue
        case .expired: return .gray
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .pending: return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .active: return "person.badge.clock.fill"
        case .expired: return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusText: String {
        switch status {
        case .pending: return "Temp Pending"
        case .accepted: return "Temp Accepted"
        case .rejected: return "Temp Rejected"
        case .active: return "Temp Active"
        case .expired: return "Temp Expired"
        }
    }
}

// A reusable view for the info rows (Budget, Dates, etc.)
struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.extraSmall) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.footnote)
                .foregroundColor(color)
                .frame(width: 16, alignment: .center)
                // .symbolRenderingMode(.hierarchical) // iOS 15+ only
            
            Text(text)
                .font(DesignSystem.Typography.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}


// MARK: - Extensions and Previews

extension ProjectStatus {
    var color: Color {
        switch self {
        case .ACTIVE: return .green
        case .INACTIVE: return .gray
        case .COMPLETED: return .blue
        }
    }
    
    var displayText: String {
        switch self {
        case .ACTIVE: return "Active"
        case .INACTIVE: return "Inactive"
        case .COMPLETED: return "Completed"
        }
    }
}

// Custom extension for a darker color
extension Color {
    func darker(by percentage: Double = 30.0) -> Color {
        if #available(iOS 14.0, *) {
            guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
                return self
            }
            let r = components[0] - (percentage / 100)
            let g = components[1] - (percentage / 100)
            let b = components[2] - (percentage / 100)
            return Color(red: r, green: g, blue: b)
        } else {
            return self
        }
    }
}

#Preview{
    ProjectCell(project: Project.sampleData[0], role: .ADMIN, tempApproverStatus: .pending)
}
