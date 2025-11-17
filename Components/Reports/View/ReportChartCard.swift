//
//  ReportChartCard.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import SwiftUI

struct ReportChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let totalValue: String?
    let chartId: String
    @Binding var expandedChartId: String?
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        let isExpanded = expandedChartId == chartId
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Header with expand button
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.small) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: DesignSystem.Spacing.small) {
                    if let totalValue = totalValue {
                        Text(totalValue)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, DesignSystem.Spacing.small + 2)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                    }
                    
                    // Expand/Collapse button
                    Button {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            expandedChartId = isExpanded ? nil : chartId
                        }
                    } label: {
                        Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                    .accessibilityLabel(isExpanded ? "Collapse chart" : "Expand chart")
                }
            }
            
            // Chart content with dynamic height
            content()
                .frame(minHeight: isExpanded ? 400 : 220, maxHeight: isExpanded ? .infinity : 350)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
                .accessibilityElement(children: .contain)
        }
        .padding(DesignSystem.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(
                    color: isExpanded ? .black.opacity(0.1) : .black.opacity(0.04),
                    radius: isExpanded ? 12 : 8,
                    x: 0,
                    y: isExpanded ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(
                    isExpanded ? Color.accentColor.opacity(0.3) : Color(.separator).opacity(0.15),
                    lineWidth: isExpanded ? 1 : 0.5
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

