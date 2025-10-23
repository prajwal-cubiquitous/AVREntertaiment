import SwiftUI

struct ExpenseApprovalRow: View {
    let expense: Expense
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    let onDetailTapped: () -> Void
    
    var body: some View {
        HStack {
            // Selection Checkbox
            Button {
                onSelectionChanged(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 20, weight: .medium))
            }
            .padding(.trailing, DesignSystem.Spacing.small)
            
            // Date
            Text(expense.date)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .leading)
            
            // Department
            Text(expense.department)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
            
            // Categories
            Text(expense.categories.joined(separator: ", "))
                .font(DesignSystem.Typography.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            
            // Submitted By
            Text(expense.submittedBy)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
            
            // Detail Button
            Button {
                onDetailTapped()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.system(size: 20, weight: .medium))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
    }
} 