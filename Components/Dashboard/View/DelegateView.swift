//
//  DelegateView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import SwiftUI
import FirebaseFirestore

struct DelegateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DelegateViewModel()
    
    var project: Project
    let currentUserRole: UserRole
    @Binding var showingDelegate: Bool
    @State private var showingDatePicker = false
    @State private var selectedDateType: DateType = .startDate
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingTempApproverSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Loading delegate details...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            // Header Card
                            headerCard
                            
                            // Delegate Details Card
                            if let tempApprover = viewModel.tempApprover {
                                delegateDetailsCard(tempApprover)
                            } else {
                                noDelegateCard
                            }
                            
                            // Action Buttons
                            if viewModel.tempApprover != nil {
                                actionButtonsCard
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Delegate Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.tempApprover != nil {
                        Button("Save") {
                            saveDelegateDetails()
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                        .disabled(viewModel.isSaving)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadDelegateDetails(for: project)
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Delegate details updated successfully!")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedDate: selectedDateType == .startDate ? $viewModel.startDate : $viewModel.endDate,
                dateType: selectedDateType
            )
        }
        .sheet(isPresented: $showingTempApproverSheet) {
            TempApproverSheet(
                allApprovers: viewModel.allApprovers,
                onSet: { newTempApprover in
                    Task {
                        await viewModel.updateTempApprover(newTempApprover, for: project)
                        showingDelegate = false
                    }
                }
            )
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.badge.clock.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delegate Management")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Manage temporary approver details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let tempApprover = viewModel.tempApprover {
                HStack {
                    StatusBadge(status: tempApprover.currentStatus)
                    Spacer()
                    Text("Last updated: \(tempApprover.updatedAt, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Delegate Details Card
    private func delegateDetailsCard(_ tempApprover: TempApprover) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Delegate Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Basic Information
            VStack(spacing: 16) {
                DelegateInfoRow(
                    icon: "person.fill",
                    title: "Name",
                    value: viewModel.approverUser?.name ?? "Loading...",
                    isEditable: false
                )
                
                DelegateInfoRow(
                    icon: "phone.fill",
                    title: "Phone Number",
                    value: tempApprover.approverId,
                    isEditable: false
                )
                
            }
            
            Divider()
                .background(Color.secondary.opacity(0.2))
            
            // Date Information
            VStack(spacing: 16) {
                DateRow(
                    icon: "calendar.badge.plus",
                    title: "Start Date & Time",
                    date: viewModel.startDate,
                    isEditable: true
                ) {
                    selectedDateType = .startDate
                    showingDatePicker = true
                }
                
                DateRow(
                    icon: "calendar.badge.minus",
                    title: "End Date & Time",
                    date: viewModel.endDate,
                    isEditable: true
                ) {
                    selectedDateType = .endDate
                    showingDatePicker = true
                }
            }
            
            Divider()
                .background(Color.secondary.opacity(0.2))
            
            // Status Information
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("Current Status")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    StatusBadge(status: tempApprover.currentStatus)
                }
                
                if tempApprover.needsStatusUpdate {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Status needs to be updated based on current dates")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - No Delegate Card
    private var noDelegateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Delegate Assigned")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("This project doesn't have a temporary approver assigned yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Action Buttons Card
    private var actionButtonsCard: some View {
        VStack(spacing: 16) {
            // Change Temp Approver Button
            Button(action: {
                showingTempApproverSheet = true
            }) {
                HStack {
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 16, weight: .medium))
                    Text("Change Temp Approver")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
            .disabled(viewModel.isSaving)
            
            Button(action: {
                // Refresh delegate details
                viewModel.loadDelegateDetails(for: project)
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                    Text("Refresh Details")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            .disabled(viewModel.isSaving)
            
            if viewModel.isSaving {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Saving changes...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Methods
    private func saveDelegateDetails() {
        Task {
            do {
                try await viewModel.saveDelegateDetails(for: project)
                await MainActor.run {
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Supporting Views
struct DelegateInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let isEditable: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            if isEditable {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DateRow: View {
    let icon: String
    let title: String
    let date: Date
    let isEditable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(date, formatter: dateTimeFormatter)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if isEditable {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(!isEditable)
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct StatusBadge: View {
    let status: TempApproverStatus
    
    var body: some View {
        Text(statusDisplay)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor)
            )
    }
    
    private var statusDisplay: String {
        switch status {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .rejected:
            return "Rejected"
        case .active:
            return "Active"
        case .expired:
            return "Expired"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .active:
            return .green
        case .expired:
            return .red
        case .accepted:
            return .blue
        case .rejected:
            return .gray
        }
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let dateType: DateType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select \(dateType.rawValue)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.top, 20)
                
                DatePicker(
                    "Date & Time",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

enum DateType: String {
    case startDate = "Start Date"
    case endDate = "End Date"
}

// MARK: - View Model
class DelegateViewModel: ObservableObject {
    @Published var tempApprover: TempApprover?
    @Published var approverUser: User?
    @Published var startDate = Date()
    @Published var endDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days from now
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var tempDocumentId = ""
    @Published var allApprovers: [User] = []
    
    private let db = Firestore.firestore()
    
    func loadDelegateDetails(for project: Project) {
        self.tempApprover = nil
        guard let projectId = project.id,
              let tempApproverID = project.tempApproverID else { return }
        isLoading = true
        let currentDate = Date()
        
        Task {
            do {
                // Load all approvers first
                await loadAllApprovers()
                
                // Fetch temp approver details from subcollection
                let tempApproverDoc = try await db.collection("projects_ios")
                    .document(projectId)
                    .collection("tempApprover")
                    .whereField("approverId", isEqualTo: tempApproverID)
                    .whereField("status", isNotEqualTo: "Expired")
//                    .whereField("endDate", isGreaterThanOrEqualTo: Timestamp(date: currentDate))
//                    .whereField("startDate", isLessThanOrEqualTo: Timestamp(date: currentDate))
                    .getDocuments()
                
                if let tempApproverDoc = tempApproverDoc.documents.first {
                    let documentId = tempApproverDoc.documentID
                    if let tempApprover = try? tempApproverDoc.data(as: TempApprover.self) {
                        // Fetch user details using tempApproverID (which is the user's phone number)
                        let userQuery = try await db.collection("users_ios")
                            .whereField("phoneNumber", isEqualTo: tempApproverID)
                            .getDocuments()
                        
                        let approverUser: User? = {
                            if let userDoc = userQuery.documents.first {
                                return try? userDoc.data(as: User.self)
                            }
                            return nil
                        }()
                        
                        await MainActor.run {
                            self.tempDocumentId = documentId
                            self.tempApprover = tempApprover
                            self.approverUser = approverUser
                            self.startDate = tempApprover.startDate
                            self.endDate = tempApprover.endDate
                            self.isLoading = false
                        }
                    } else {
                        await MainActor.run {
                            self.isLoading = false
                        }
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func loadAllApprovers() async {
        do {
            let query = try await db.collection("users_ios")
                .whereField("role", isEqualTo: "APPROVER")
                .getDocuments()
            
            let approvers = query.documents.compactMap { doc in
                try? doc.data(as: User.self)
            }
            
            await MainActor.run {
                self.allApprovers = approvers
            }
        } catch {
            print("Error loading approvers: \(error)")
        }
    }
    
    func updateTempApprover(_ newTempApprover: TempApprover, for project: Project) async {
        guard let projectId = project.id else { return }
        
        await MainActor.run {
            isSaving = true
        }
        
        
        do {
            
            try await db.collection("projects_ios")
                .document(projectId)
                .collection("tempApprover")
                .document(tempDocumentId) // the known document ID
                .updateData([
                    "status": "Expired"  // replace with the actual field and value
                ])
            
            // Update the project's tempApproverID
            try await db.collection("projects_ios")
                .document(projectId)
                .updateData([
                    "tempApproverID": newTempApprover.approverId
                ])
            
            // Create new temp approver document
            try await db.collection("projects_ios")
                .document(projectId)
                .collection("tempApprover")
                .addDocument(data: [
                    "approvedExpense": [],
                    "approverId": newTempApprover.approverId,
                    "startDate": newTempApprover.startDate,
                    "endDate": newTempApprover.endDate,
                    "status": "pending",
                    "updatedAt": Date()
                ])
            
//            project.tempApproverID = newTempApprover.approverId
            
            
            await MainActor.run {
                isSaving = false
                // Reload delegate details
                loadDelegateDetails(for: project)
            }
        } catch {
            await MainActor.run {
                isSaving = false
            }
            print("Error updating temp approver: \(error)")
        }
    }
    
    func saveDelegateDetails(for project: Project) async throws {
        guard let projectId = project.id,
              let tempApproverID = project.tempApproverID else {
            throw NSError(domain: "DelegateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No project ID or temporary approver ID found"])
        }
        
        await MainActor.run {
            isSaving = true
        }
        
        do {
            try await db.collection("projects_ios")
                .document(projectId)
                .collection("tempApprover")
                .document(tempDocumentId)
                .updateData([
                    "startDate": startDate,
                    "endDate": endDate,
                    "updatedAt": Date(),
                    "status": "pending"
                ])
            
            await MainActor.run {
                isSaving = false
            }
        } catch {
            await MainActor.run {
                isSaving = false
            }
            throw error
        }
    }
}

#Preview {
    DelegateView(
        project: Project(
            id: "preview",
            name: "Sample Project",
            description: "A sample project for preview",
            budget: 50000,
            status: "ACTIVE",
            startDate: "2024-01-01",
            endDate: "2024-12-31",
            teamMembers: ["member1", "member2"],
            managerId: "manager123",
            tempApproverID: "temp123",
            departments: ["Casting": 10000, "Location": 5000],
            createdAt: Timestamp(date: Date()),
            updatedAt: Timestamp(date: Date())
        ),
        currentUserRole: .ADMIN, showingDelegate: .constant(false)
    )
}
