import SwiftUI
import FirebaseFirestore

struct TempApproverApprovalView: View {
    let project: Project
    let tempApprover: TempApprover
    @State private var isProcessing = false
    @State private var showingRejectionSheet = false
    @State private var rejectionReason = ""
    @Environment(\.dismiss) private var dismiss
    
    let onAccept: () async -> Void
    let onReject: (String) async -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.large) {
                    // Header Section
                    headerSection
                    
                    // Project Information Card
                    projectInfoCard
                    
                    // Temp Approver Details Card
                    tempApproverDetailsCard
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding(DesignSystem.Spacing.medium)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Temporary Approver Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingRejectionSheet) {
            rejectionSheet
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Icon
            Image(systemName: "person.badge.clock.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .symbolRenderingMode(.hierarchical)
            
            // Title and Description
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Temporary Approver Assignment")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("You have been assigned as a temporary approver for this project. Please review the details and decide whether to accept or reject this role.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .padding(.top, DesignSystem.Spacing.medium)
    }
    
    // MARK: - Project Information Card
    private var projectInfoCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Project Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: DesignSystem.Spacing.small) {
                TempApproverInfoRow(
                    icon: "textformat.abc",
                    label: "Project Name",
                    value: project.name,
                    iconColor: .blue
                )
                
                TempApproverInfoRow(
                    icon: "indianrupeesign.circle.fill",
                    label: "Total Budget",
                    value: project.budgetFormatted,
                    iconColor: .green
                )
                
                TempApproverInfoRow(
                    icon: "calendar.circle.fill",
                    label: "Project Timeline",
                    value: project.dateRangeFormatted,
                    iconColor: .purple
                )
                
                TempApproverInfoRow(
                    icon: "person.2.circle.fill",
                    label: "Team Members",
                    value: "\(project.teamMembers.count) members",
                    iconColor: .mint
                )
            }
        }
        .cardStyle()
    }
    
    // MARK: - Temp Approver Details Card
    private var tempApproverDetailsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: "person.badge.clock.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("Approval Period")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Status Badge
                statusBadge
            }
            
            VStack(spacing: DesignSystem.Spacing.small) {
                TempApproverInfoRow(
                    icon: "calendar.badge.clock",
                    label: "Start Date",
                    value: formatDate(tempApprover.startDate),
                    iconColor: .green
                )
                
                TempApproverInfoRow(
                    icon: "calendar.badge.exclamationmark",
                    label: "End Date",
                    value: formatDate(tempApprover.endDate),
                    iconColor: isExpired ? .red : .orange
                )
                
                TempApproverInfoRow(
                    icon: "clock.fill",
                    label: "Duration",
                    value: durationText,
                    iconColor: .blue
                )
                
                if isExpired {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Text("This approval period has expired")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    .padding(.top, DesignSystem.Spacing.small)
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Accept Button
            Button(action: {
                Task {
                    isProcessing = true
                    await onAccept()
                    isProcessing = false
                    dismiss()
                }
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    
                    Text(isProcessing ? "Accepting..." : "Accept Role")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.medium)
            }
            .primaryButton()
            .disabled(isProcessing)
            
            // Reject Button
            Button(action: {
                showingRejectionSheet = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                    
                    Text("Reject Role")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.medium)
            }
            .secondaryButton()
            .disabled(isProcessing)
        }
    }
    
    // MARK: - Rejection Sheet
    private var rejectionSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.large) {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "person.badge.clock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Reject Temporary Approver Role")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Please provide a reason for rejecting this temporary approver role. This will help us understand your decision.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Reason for Rejection")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your reason...", text: $rejectionReason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Spacer()
                
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Button("Cancel") {
                        showingRejectionSheet = false
                        rejectionReason = ""
                    }
                    .secondaryButton()
                    
                    Button("Confirm Rejection") {
                        Task {
                            isProcessing = true
                            await onReject(rejectionReason)
                            isProcessing = false
                            showingRejectionSheet = false
                            dismiss()
                        }
                    }
                    .primaryButton()
                    .disabled(rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                }
            }
            .padding(DesignSystem.Spacing.large)
            .navigationTitle("Reject Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingRejectionSheet = false
                        rejectionReason = ""
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views and Properties
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        if isExpired {
            return .red
        } else if tempApprover.status == .pending {
            return .orange
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if isExpired {
            return "EXPIRED"
        } else if tempApprover.status == .pending {
            return "PENDING"
        } else {
            return "ACTIVE"
        }
    }
    
    private var isExpired: Bool {
        Date() > tempApprover.endDate
    }
    
    private var durationText: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour], from: tempApprover.startDate, to: tempApprover.endDate)
        
        if let days = components.day, days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "Less than 1 hour"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Row Component
private struct TempApproverInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(value)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}

// MARK: - Card Style Extension
private extension View {
    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(
                        color: DesignSystem.Shadow.small.color,
                        radius: DesignSystem.Shadow.small.radius,
                        x: DesignSystem.Shadow.small.x,
                        y: DesignSystem.Shadow.small.y
                    )
            )
    }
}

// MARK: - Preview
struct TempApproverApprovalView_Previews: PreviewProvider {
    static var previews: some View {
        TempApproverApprovalView(
            project: Project.sampleData[0],
            tempApprover: TempApprover(
                approverId: "9876543219",
                startDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                endDate: Date().addingTimeInterval(86400 * 5), // 5 days from now
                status: .pending
            ),
            onAccept: { },
            onReject: { _ in }
        )
    }
}
