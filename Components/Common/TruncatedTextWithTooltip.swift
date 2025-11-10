//
//  TruncatedTextWithTooltip.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import SwiftUI

// MARK: - Truncated Text with Tooltip Component
struct TruncatedTextWithTooltip: View {
    let text: String
    let font: Font
    let fontWeight: Font.Weight?
    let foregroundColor: Color
    let lineLimit: Int
    let alignment: TextAlignment
    let truncationLength: Int
    
    @State private var isTooltipVisible = false
    
    init(
        _ text: String,
        font: Font = .body,
        fontWeight: Font.Weight? = nil,
        foregroundColor: Color = .primary,
        lineLimit: Int = 1,
        alignment: TextAlignment = .leading,
        truncationLength: Int = 10
    ) {
        self.text = text
        self.font = font
        self.fontWeight = fontWeight
        self.foregroundColor = foregroundColor
        self.lineLimit = lineLimit
        self.alignment = alignment
        self.truncationLength = truncationLength
    }
    
    // Truncate to specified length
    private var truncatedText: String {
        if text.count > truncationLength {
            return String(text.prefix(truncationLength)) + "..."
        }
        return text
    }
    
    // Check if text needs truncation
    private var needsTruncation: Bool {
        text.count > truncationLength
    }
    
    var body: some View {
        Text(truncatedText)
            .font(font)
            .fontWeight(fontWeight)
            .foregroundColor(foregroundColor)
            .lineLimit(lineLimit)
            .multilineTextAlignment(alignment)
            .onTapGesture {
                // Only show popover if text is truncated
                if needsTruncation {
                    HapticManager.selection()
                    isTooltipVisible = true
                }
            }
            .popover(isPresented: $isTooltipVisible, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(text)
                        .font(font)
                        .fontWeight(fontWeight)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: min(320, UIScreen.main.bounds.width - 40))
                .presentationCompactAdaptation(.popover)
            }
    }
}


