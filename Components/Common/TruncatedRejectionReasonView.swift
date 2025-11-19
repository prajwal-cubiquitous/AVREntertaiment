//
//  TruncatedRejectionReasonView.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import SwiftUI

// MARK: - Truncated Rejection Reason with Clickable Dots
struct TruncatedRejectionReasonView: View {
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
                .foregroundColor(.red)
            
            if needsTruncation {
                Text("...")
                    .font(DesignSystem.Typography.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .onTapGesture {
                        HapticManager.selection()
                        showFullReason = true
                    }
                    .popover(isPresented: $showFullReason, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            HStack(spacing: DesignSystem.Spacing.small) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                
                                Text("Rejection Reason")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.bottom, DesignSystem.Spacing.extraSmall)
                            
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.red)
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

