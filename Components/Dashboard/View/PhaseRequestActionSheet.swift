//
//  PhaseRequestActionSheet.swift
//  AVREntertainment
//
//  Created by Auto on 1/2/25.
//

import SwiftUI
import FirebaseFirestore

struct PhaseRequestActionSheet: View {
    let request: PhaseRequestItem
    let projectId: String
    let customerId: String?
    let onAccept: () -> Void
    let onReject: () -> Void
    let onDismiss: () -> Void
    @Binding var reasonToReact: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var processingAction: RequestAction? = nil // Track which action is processing
    @FocusState private var isReasonFocused: Bool
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }
    
    private var requestDate: String {
        request.createdAt.dateValue().formatted(date: .abbreviated, time: .omitted)
    }
    
    // Reason is now optional, so buttons are always enabled when not processing
    private var canAccept: Bool {
        !isProcessing
    }
    
    private var canReject: Bool {
        !isProcessing
    }
    
    private var isAcceptProcessing: Bool {
        isProcessing && processingAction == .accept
    }
    
    private var isRejectProcessing: Bool {
        isProcessing && processingAction == .reject
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Request Information Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Phase Name
                        HStack {
                            Text("Phase")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(request.phaseName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Divider()
                        
                        // User Information
                        if let userName = request.userName, !userName.isEmpty {
                            HStack {
                                Text("Requested By")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(userName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    if let phoneNumber = request.userPhoneNumber, !phoneNumber.isEmpty {
                                        Text(phoneNumber)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Divider()
                        }
                        
                        // Extension Date
                        HStack {
                            Text("Extend To")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(request.extendedDate)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                        
                        // Request Date
                        HStack {
                            Text("Requested On")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(requestDate)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Reason/Description
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reason")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(request.reason)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Request Details")
                }
                
                // Reason to React Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason for Accept/Reject")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $reasonToReact)
                            .frame(minHeight: 100)
                            .focused($isReasonFocused)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isReasonFocused ? Color.blue : Color(.systemGray4), lineWidth: isReasonFocused ? 2 : 1)
                            )
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Your Response")
                } footer: {
                    Text("Reason is optional but recommended")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Action Buttons Section
                Section {
                    HStack(spacing: 12) {
                        // Accept Button (Left)
                        Button(action: {
                            guard !isProcessing else { return }
                            isProcessing = true
                            processingAction = .accept
                            HapticManager.impact(.medium)
                            onAccept()
                        }) {
                            HStack(spacing: 6) {
                                if isAcceptProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Accept")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canAccept ? Color.green : Color.gray)
                            .cornerRadius(10)
                        }
                        .disabled(!canAccept || isProcessing)
                        
                        // Reject Button (Right)
                        Button(action: {
                            guard !isProcessing else { return }
                            isProcessing = true
                            processingAction = .reject
                            HapticManager.impact(.medium)
                            onReject()
                        }) {
                            HStack(spacing: 6) {
                                if isRejectProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Reject")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canReject ? Color.red : Color.gray)
                            .cornerRadius(10)
                        }
                        .disabled(!canReject || isProcessing)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Phase Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                isReasonFocused = true
            }
        }
    }
}

#Preview {
    PhaseRequestActionSheet(
        request: PhaseRequestItem(
            id: "test",
            phaseId: "phase1",
            phaseName: "Phase 1",
            reason: "Need more time",
            extendedDate: "31/12/2025",
            userID: "1234567890",
            userName: "John Doe",
            userPhoneNumber: "1234567890",
            createdAt: Timestamp()
        ),
        projectId: "project1",
        customerId: "customer1",
        onAccept: {},
        onReject: {},
        onDismiss: {},
        reasonToReact: .constant("")
    )
}
