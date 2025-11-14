//
//  TruncatedSuspensionReasonView.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import SwiftUI

// MARK: - Truncated Suspension Reason with Clickable Dots
struct TruncatedSuspensionReasonView: View {
    let reason: String
    let maxLength: Int = 15
    
    @State private var showFullReason = false
    
    private var truncatedReason: String {
        if reason.count > maxLength {
            return String(reason.prefix(maxLength))
        }
        return reason
    }
    
    private var needsTruncation: Bool {
        reason.count > maxLength
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Text(truncatedReason)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
            
            if needsTruncation {
                Text("...")
                    .font(DesignSystem.Typography.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        HapticManager.selection()
                        showFullReason = true
                    }
                    .popover(isPresented: $showFullReason, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            HStack(spacing: DesignSystem.Spacing.small) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                Text("Suspension Reason")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.bottom, DesignSystem.Spacing.extraSmall)
                            
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(DesignSystem.Spacing.medium)
                        .frame(maxWidth: min(300, UIScreen.main.bounds.width - 40))
                        .presentationCompactAdaptation(.popover)
                    }
            }
        }
    }
}

