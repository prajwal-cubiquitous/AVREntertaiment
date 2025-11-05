//
//  PhaseRequestNotificationView.swift
//  AVREntertainment
//
//  Created by Auto on 1/2/25.
//

import SwiftUI

struct PhaseRequestNotificationView: View {
    let requests: [PhaseRequest]
    let onRequestTap: (PhaseRequest) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.1)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Notification popup
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Phase Requests")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Requests list
                if requests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("No Pending Requests")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("All phase requests have been processed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(.systemBackground))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(requests) { request in
                                PhaseRequestRow(
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
            .frame(width: 320, height: min(500, CGFloat(requests.count) * 100 + 100))
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
}

private struct PhaseRequestRow: View {
    let request: PhaseRequest
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
                    
                    // Requested by
                    Text("Requested by: \(request.requestedBy)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Requested date
                    Text("Extend to: \(request.requestedExtensionDate)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
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
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PhaseRequestNotificationView(
        requests: [],
        onRequestTap: { _ in },
        onDismiss: {}
    )
}

