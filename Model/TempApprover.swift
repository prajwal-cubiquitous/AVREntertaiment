// TempApprover.swift
import Foundation
import FirebaseFirestore

enum TempApproverStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}

struct TempApprover: Identifiable, Codable, Equatable, Hashable {
    @DocumentID var id: String?
    
    let approverId: String // Mobile number of the approver
    let startDate: Date
    let endDate: Date
    let updatedAt: Date
    let status: TempApproverStatus
    let approvedExpense: [String] // List of approved expense IDs
    
    init(approverId: String, startDate: Date, endDate: Date, status: TempApproverStatus = .pending, approvedExpense: [String] = []) {
        self.approverId = approverId
        self.startDate = startDate
        self.endDate = endDate
        self.updatedAt = Date.now
        self.status = status
        self.approvedExpense = approvedExpense
    }
    
    // Computed property for date range display
    var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    // Computed property for status display
    var statusDisplay: String {
        switch status {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .rejected:
            return "Rejected"
        }
    }
    
    // Computed property for approved expenses count
    var approvedExpenseCount: Int {
        return approvedExpense.count
    }
    
    // Computed property for approved expenses display
    var approvedExpenseDisplay: String {
        if approvedExpense.isEmpty {
            return "No expenses approved"
        } else if approvedExpense.count == 1 {
            return "1 expense approved"
        } else {
            return "\(approvedExpense.count) expenses approved"
        }
    }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TempApprover, rhs: TempApprover) -> Bool {
        lhs.id == rhs.id
    }
}
