//
//  ProjectCell.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//


import SwiftUI

struct ProjectCell: View {
    let project: Project
    let role: UserRole?
    let tempApproverStatus: TempApproverStatus?
    let onReviewTap: (() -> Void)?
    let hasActivePhases: Bool? // Optional: if nil, will check project status only; if true/false, will use this value
    @State private var isPressed = false
    @State private var showFullNamePopup = false
    
    init(project: Project, role: UserRole?, tempApproverStatus: TempApproverStatus? = nil, onReviewTap: (() -> Void)? = nil, hasActivePhases: Bool? = nil) {
        self.project = project
        self.role = role
        self.tempApproverStatus = tempApproverStatus
        self.onReviewTap = onReviewTap
        self.hasActivePhases = hasActivePhases
    }
    
    // Computed property to determine displayed status
    private var displayedStatus: ProjectStatus {
        // If project is ACTIVE but has no active phases, show STANDBY in UI
        if project.statusType == .ACTIVE && project.isSuspended != true {
            // If hasActivePhases is explicitly provided, use it; otherwise assume true (default behavior)
            if let hasActivePhases = hasActivePhases, !hasActivePhases {
                return .STANDBY
            }
        }
        return project.statusType
    }
    
    private var daysRemainingText: String {
        guard let endDateStr = project.handoverDate else {
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
    
    // Computed property for timeline text (planned date to handover date)
    private var timelineText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        var startDateStr = "N/A"
        var endDateStr = "N/A"
        
        if let plannedDate = project.plannedDate, !plannedDate.isEmpty {
            startDateStr = plannedDate
        }
        
        if let handoverDate = project.handoverDate, !handoverDate.isEmpty {
            endDateStr = handoverDate
        }
        
        return "\(startDateStr) - \(endDateStr)"
    }
    
    // Check if project name is likely truncated (heuristic based on character count)
    private var isNameTruncated: Bool {
        // Estimate if name is likely to be truncated based on typical screen width
        // For title3 font, approximately 30-35 characters fit on iPhone in single line
        return project.name.count > 30
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Top row: Project name and status badges
            HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
                // Project name with truncation - clickable to show popup
                HStack(spacing: 4) {
                    Button(action: {
                        HapticManager.selection()
                        showFullNamePopup = true
                    }) {
                        Text(project.name)
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .buttonStyle(.plain)
                    
                    // Show "..." button if name is truncated
                    if isNameTruncated {
                        Button(action: {
                            HapticManager.selection()
                            showFullNamePopup = true
                        }) {
                            Text("")
                                .font(DesignSystem.Typography.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer(minLength: 8)
                
                // Status badges row
                HStack(spacing: DesignSystem.Spacing.extraSmall) {
                    if project.isSuspended == true {
                        SuspendedStatusView(suspendedDate: project.suspendedDate)
                    } else if displayedStatus == .SUSPENDED && project.statusType == .ACTIVE {
                        StatusView(status: .SUSPENDED)
                    } else {
                        StatusView(status: project.statusType)
                    }
                    
                    if let tempStatus = tempApproverStatus {
                        TempApproverStatusView(status: tempStatus)
                    }
                    
                    if role == .APPROVER && project.statusType == .IN_REVIEW {
                        Button(action: {
                            HapticManager.selection()
                            onReviewTap?()
                        }) {
                            Image(systemName: "eye.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if role == .ADMIN && project.status != ProjectStatus.DECLINED.rawValue{
                        NavigationLink(destination: AdminProjectDetailView(project: project)) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Description (if available)
            if !project.description.isEmpty {
                Text(project.description)
                    .font(DesignSystem.Typography.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            
            // Middle row: Budget, Members, Days Left on left | Location, Client, Timeline on right
            HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
                // Left side: Budget, Members, Days Left
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(
                        icon: "indianrupeesign.circle.fill",
                        text: project.budgetFormatted,
                        color: .green
                    )
                    
                    InfoRow(
                        icon: "person.2.circle.fill",
                        text: "\(project.teamMembers.count) members",
                        color: .purple
                    )
                    
                    if project.handoverDate != nil && project.statusType == .ACTIVE && project.isSuspended != true {
                        Text(daysRemainingText)
                            .font(DesignSystem.Typography.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(getDaysRemainingColor())
                            .padding(.leading, 20)
                    }
                }
                
                Spacer()
                
                // Right side: Location, Client, Timeline
                VStack(alignment: .trailing, spacing: 6) {
                    if !project.location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 12, height: 12)
                            Text(project.location)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    
                    if !project.client.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 12, height: 12)
                            Text(project.client)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    
                    if project.plannedDate != nil || project.handoverDate != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 12, height: 12)
                            Text(timelineText)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .padding(.top, 4)
            
            // Bottom: Suspension/Rejection reasons
            if project.isSuspended == true, let reason = project.suspensionReason, !reason.isEmpty {
                HStack(spacing: DesignSystem.Spacing.extraSmall) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    TruncatedSuspensionReasonView(reason: reason)
                }
                .padding(.top, 4)
            }
            
            if project.statusType == .DECLINED, let reason = project.rejectionReason, !reason.isEmpty {
                HStack(spacing: DesignSystem.Spacing.extraSmall) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    TruncatedRejectionReasonView(reason: reason)
//                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(shadow: isPressed ? DesignSystem.Shadow.small : DesignSystem.Shadow.medium)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.interactiveSpring, value: isPressed)
        .id("\(project.id ?? "")-\(project.status)") // Force view update when status changes
        .zIndex(showFullNamePopup ? 1000 : 0) // Ensure popover appears above all cells
        .popover(isPresented: $showFullNamePopup, attachmentAnchor: .point(.center), arrowEdge: .top) {
            ProjectNamePopoverView(
                projectName: project.name,
                status: displayedStatus
            )
            .presentationCompactAdaptation(.popover)
            .zIndex(1001) // Ensure popover content is above everything
        }
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

// A reusable view for the Suspended status tag with suspended date
struct SuspendedStatusView: View {
    let suspendedDate: String?
    
    private var formattedDate: String {
        guard let dateStr = suspendedDate, !dateStr.isEmpty else {
            return "No date set"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        guard let date = dateFormatter.date(from: dateStr) else {
            return dateStr // Return original if parsing fails
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        return displayFormatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: DesignSystem.Spacing.extraSmall) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.red.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("SUSPENDED")
                    .font(DesignSystem.Typography.caption1)
                    .fontWeight(.semibold)
            }
            
            // Show suspended date if available
            if let dateStr = suspendedDate, !dateStr.isEmpty {
                Text(formattedDate)
                    .font(DesignSystem.Typography.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                )
        )
        .foregroundColor(Color.red.darker(by: 20))
    }
}

// A reusable view for the Temp Approver Status tag
struct TempApproverStatusView: View {
    let status: TempApproverStatus
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.extraSmall) {
            Image(systemName: statusIcon)
                .font(.caption2)
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
                .symbolRenderingMode(.hierarchical)
            
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
        case .COMPLETED: return .blue
        case .IN_REVIEW: return .cyan
        case .LOCKED: return .indigo
        case .SUSPENDED: return .red
        case .STANDBY: return .orange
        case .DECLINED: return .red
        case .MAINTENANCE: return .purple
        case .ARCHIVE: return .gray
        }
    }
    
    var displayText: String {
        switch self {
        case .ACTIVE: return "ACTIVE"
        case .COMPLETED: return "COMPLETED"
        case .IN_REVIEW: return "IN REVIEW"
        case .LOCKED: return "LOCKED"
        case .SUSPENDED: return "SUSPENDED"
        case .STANDBY: return "STANDBY"
        case .DECLINED: return "DECLINED"
        case .MAINTENANCE: return "MAINTENANCE"
        case .ARCHIVE: return "ARCHIVE"
        }
    }
}

// Custom extension for a darker color
extension Color {
    func darker(by percentage: Double = 30.0) -> Color {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return self
        }
        let r = components[0] - (percentage / 100)
        let g = components[1] - (percentage / 100)
        let b = components[2] - (percentage / 100)
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Project Name Popover View
struct ProjectNamePopoverView: View {
    let projectName: String
    let status: ProjectStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Status indicator with label
            HStack(spacing: DesignSystem.Spacing.small) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                
                Text(status.displayText)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Divider()
                .padding(.vertical, DesignSystem.Spacing.extraSmall)
            
            // Project Name label and value
            HStack {
                Text("Project Name")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(projectName)
                .font(DesignSystem.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: min(280, UIScreen.main.bounds.width - 40))
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview{
    ProjectCell(project: Project.sampleData[0], role: .ADMIN, tempApproverStatus: .pending)
}
