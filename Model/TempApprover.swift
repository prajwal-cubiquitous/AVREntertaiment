// TempApprover.swift
import Foundation
import FirebaseFirestore

enum TempApproverStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    case active = "active"
    case expired = "expired"
}

@available(iOS 14.0, *)
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
        self.updatedAt = Date()
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
        case .active:
            return "Active"
        case .expired:
            return "Expired"
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
    
    // Computed property to determine current status based on dates
    var currentStatus: TempApproverStatus {
        let now = Date()
        
        // If already rejected, keep it rejected
        if status == .rejected {
            return .rejected
        }
        
        // If not yet accepted, check if it's expired
        if status == .pending {
            if now > endDate {
                return .expired
            }
            return .pending
        }
        
        // If accepted, check if it's within the active period
        if status == .accepted {
            if now >= startDate && now <= endDate {
                return .active
            } else if now > endDate {
                return .expired
            } else {
                return .accepted // Not yet started
            }
        }
        
        // If already active or expired, check current state
        if status == .active {
            if now > endDate {
                return .expired
            } else {
                return .active
            }
        }
        
        if status == .expired {
            return .expired
        }
        
        return status
    }
    
    // Computed property to check if the temp approver period is currently active
    var isCurrentlyActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate && (status == .accepted || status == .active)
    }
    
    // Computed property to check if the temp approver period has expired
    var hasExpired: Bool {
        let now = Date()
        return now > endDate
    }
    
    // Computed property to check if the temp approver period is pending (not yet started)
    var isPending: Bool {
        let now = Date()
        return now < startDate && status == .accepted
    }
    
    // Helper method to check if status needs to be updated
    var needsStatusUpdate: Bool {
        return currentStatus != status
    }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TempApprover, rhs: TempApprover) -> Bool {
        lhs.id == rhs.id
    }
}
