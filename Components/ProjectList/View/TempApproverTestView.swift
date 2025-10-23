import SwiftUI

@available(iOS 14.0, *)
struct TempApproverTestView: View {
    @StateObject private var tempApproverService = TempApproverService()
    @State private var testProject = Project.sampleData[0]
    @State private var testTempApprover = TempApprover(
        approverId: "9876543219",
        startDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
        endDate: Date().addingTimeInterval(86400 * 5), // 5 days from now
        status: .pending
    )
    @State private var showingApproval = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.large) {
                    // Test Project Card
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        Text("Test Project")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ProjectCell(
                            project: testProject,
                            role: .APPROVER,
                            tempApproverStatus: testTempApprover.status
                        )
                    }
                    .padding()
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Temp Approver Details
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        Text("Temp Approver Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            TestInfoRow(
                                icon: "person.badge.clock.fill",
                                label: "Status",
                                value: testTempApprover.statusDisplay,
                                iconColor: tempApproverService.getStatusColor(for: testTempApprover.status)
                            )
                            
                            TestInfoRow(
                                icon: "calendar.badge.clock",
                                label: "Start Date",
                                value: formatDate(testTempApprover.startDate),
                                iconColor: .green
                            )
                            
                            TestInfoRow(
                                icon: "calendar.badge.exclamationmark",
                                label: "End Date",
                                value: formatDate(testTempApprover.endDate),
                                iconColor: tempApproverService.isTempApproverExpired(testTempApprover) ? .red : .orange
                            )
                            
                            TestInfoRow(
                                icon: "clock.fill",
                                label: "Duration",
                                value: tempApproverService.getDurationText(
                                    from: testTempApprover.startDate,
                                    to: testTempApprover.endDate
                                ),
                                iconColor: .blue
                            )
                            
                            TestInfoRow(
                                icon: "exclamationmark.triangle.fill",
                                label: "Is Expired",
                                value: tempApproverService.isTempApproverExpired(testTempApprover) ? "Yes" : "No",
                                iconColor: tempApproverService.isTempApproverExpired(testTempApprover) ? .red : .green
                            )
                            
                            TestInfoRow(
                                icon: "checkmark.circle.fill",
                                label: "Is Active",
                                value: tempApproverService.isTempApproverActive(testTempApprover) ? "Yes" : "No",
                                iconColor: tempApproverService.isTempApproverActive(testTempApprover) ? .green : .gray
                            )
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // Test Buttons
                    VStack(spacing: DesignSystem.Spacing.medium) {
                        Button("Show Approval View") {
                            showingApproval = true
                        }
                        .primaryButton()
                        
                        Button("Test Expired Status") {
                            testTempApprover = TempApprover(
                                approverId: "9876543219",
                                startDate: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                                endDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago (expired)
                                status: .pending
                            )
                        }
                        .secondaryButton()
                        
                        Button("Test Active Status") {
                            testTempApprover = TempApprover(
                                approverId: "9876543219",
                                startDate: Date().addingTimeInterval(-86400 * 1), // 1 day ago
                                endDate: Date().addingTimeInterval(86400 * 3), // 3 days from now
                                status: .accepted
                            )
                        }
                        .secondaryButton()
                        
                        Button("Test Pending Status") {
                            testTempApprover = TempApprover(
                                approverId: "9876543219",
                                startDate: Date().addingTimeInterval(86400 * 1), // 1 day from now
                                endDate: Date().addingTimeInterval(86400 * 5), // 5 days from now
                                status: .pending
                            )
                        }
                        .secondaryButton()
                    }
                }
                .padding()
            }
            .compatibleNavigationTitle("Temp Approver Test")
            // .navigationBarTitleDisplayMode(.inline) // iOS 14+ only
        }
        .sheet(isPresented: $showingApproval) {
            TempApproverApprovalView(
                project: testProject,
                tempApprover: testTempApprover,
                onAccept: {
                    print("✅ Temp approver accepted")
                    testTempApprover = TempApprover(
                        approverId: testTempApprover.approverId,
                        startDate: testTempApprover.startDate,
                        endDate: testTempApprover.endDate,
                        status: .accepted,
                        approvedExpense: testTempApprover.approvedExpense
                    )
                },
                onReject: { reason in
                    print("❌ Temp approver rejected: \(reason)")
                    testTempApprover = TempApprover(
                        approverId: testTempApprover.approverId,
                        startDate: testTempApprover.startDate,
                        endDate: testTempApprover.endDate,
                        status: .rejected,
                        approvedExpense: testTempApprover.approvedExpense
                    )
                }
            )
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
private struct TestInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                // .symbolRenderingMode(.hierarchical) // iOS 15+ only
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    // .textCase(.uppercase) // iOS 14+ only
                    // .tracking(0.5) // iOS 16+ only
                
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

#Preview {
    TempApproverTestView()
}
