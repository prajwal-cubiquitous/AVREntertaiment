//
//  PhaseRequestNotificationFloatingView.swift
//  AVREntertainment
//
//  Created by Auto on 1/2/25.
//

import SwiftUI
import FirebaseFirestore

struct PhaseRequestNotificationFloatingView: View {
    let requests: [PhaseRequestItem]
    let onRequestTap: (PhaseRequestItem) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phase Requests")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if !requests.isEmpty {
                        Text("\(requests.count) pending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Content
            if requests.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("No Pending Requests")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("All phase extension requests have been processed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemBackground))
            } else {
                // Requests list with ScrollView
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(requests) { request in
                            PhaseRequestItemRow(
                                request: request,
                                onTap: {
                                    onRequestTap(request)
                                }
                            )
                            
                            if request.id != requests.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

private struct PhaseRequestItemRow: View {
    let request: PhaseRequestItem
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }
    
    private var requestDate: String {
        request.createdAt.dateValue().formatted(date: .abbreviated, time: .omitted)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Status icon
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Phase name
                    Text(request.phaseName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // User name and phone number - Make it more prominent
                    if let userName = request.userName, !userName.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .symbolRenderingMode(.hierarchical)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(userName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if let phoneNumber = request.userPhoneNumber, !phoneNumber.isEmpty {
                                    Text(phoneNumber)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    } else if let phoneNumber = request.userPhoneNumber, !phoneNumber.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .symbolRenderingMode(.hierarchical)
                            
                            Text(phoneNumber)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // Reason/Description
                    Text(request.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Extension date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Extend to: \(request.extendedDate)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    // Request date
                    Text(requestDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PhaseRequestNotificationFloatingView(
        requests: [],
        onRequestTap: { _ in },
        onDismiss: {}
    )
}

