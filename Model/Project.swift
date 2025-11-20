// Project.swift
import Foundation
import FirebaseFirestore

enum ProjectStatus: String, Codable, CaseIterable {
    case IN_REVIEW
    case LOCKED
    case ACTIVE
    case SUSPENDED
    case STANDBY
    case COMPLETED
    case DECLINED
    case MAINTENANCE
    case ARCHIVE
}

struct Project: Identifiable, Codable, Equatable, Hashable {
    
    @DocumentID var id: String?
    
    let name: String
    let description: String
    let client: String
    let location: String
    let currency: String
    let budget: Double // This remains the total budget stored in Firestore
    let estimatedBudget: Double? // Original estimated budget when project was created (constant, never changes)
    let status: String
    let startDate: String?
    let endDate: String?
    let plannedDate: String? // Planned start date - project becomes ACTIVE when this date arrives
    let handoverDate: String? // Highest end date among all phases - automatically calculated
    let initialHandOverDate: String? // Initial handover date - same as handoverDate on creation, only changes when status is LOCKED or IN_REVIEW
    let maintenanceDate: String? // Maintenance period end date - project becomes COMPLETED when this date arrives
    let isSuspended: Bool? // Whether the project is currently suspended
    let suspendedDate: String? // Date until which the project is suspended
    let suspensionReason: String? // Reason for suspension
    let rejectionReason: String? // Reason for rejection when status is DECLINED
    let rejectedBy: String? // User who rejected the project
    let rejectedAt: Timestamp? // Timestamp when project was rejected
    let teamMembers: [String]
    let managerIds: [String] // Project approvers/managers
    var tempApproverID: String?
    
    // Allow template overrides
    let Allow_Template_Overrides: Bool?
    
    // Firestore Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    // ... (Computed Properties remain the same) ...
    var statusType: ProjectStatus { 
        ProjectStatus(rawValue: status) ?? .LOCKED // Default to LOCKED if status is unknown
    }
    
    var budgetFormatted: String {
        // This continues to work on the total budget
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        // Fallback to INR until multiple currencies are supported in UI
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: budget)) ?? "₹0.00"
    }

    var dateRangeFormatted: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "dd/MM/yyyy"
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        
        switch (plannedDate, handoverDate) {
        case let (start?, end?):
            guard let startDateObj = inputFormatter.date(from: start),
                  let endDateObj = inputFormatter.date(from: end) else { 
                return "Invalid Dates" 
            }
            return "\(outputFormatter.string(from: startDateObj)) - \(outputFormatter.string(from: endDateObj))"
        case let (start?, nil):
            guard let startDateObj = inputFormatter.date(from: start) else { return "Invalid Date" }
            return "From \(outputFormatter.string(from: startDateObj))"
        case let (nil, end?):
            guard let endDateObj = inputFormatter.date(from: end) else { return "Invalid Date" }
            return "Until \(outputFormatter.string(from: endDateObj))"
        case (nil, nil):
            return "No timeline set"
        }
    }
    
    var lastUpdatedDate: Date { updatedAt.dateValue() }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Updated Sample Data
extension Project {
    static let sampleData: [Project] = [
        Project(id: "128YgC7uVnge9RLxVfisdhihfrgG",
                name: "",
                description: "",
                client: "",
                location: "",
                currency: "INR",
                // The total budget MUST match the sum of the categories
                budget: 0000,
                estimatedBudget: nil,
                status: "ACTIVE",
                startDate: "",
                endDate: "",
                plannedDate: nil,
                handoverDate: nil,
                initialHandOverDate: nil,
                maintenanceDate: nil,
                isSuspended: nil,
                suspendedDate: nil,
                suspensionReason: nil,
                rejectionReason: nil,
                rejectedBy: nil,
                rejectedAt: nil,
                teamMembers: ["user1", "user2", "user3"],
                managerIds: ["manager1"],
                tempApproverID: nil,
                Allow_Template_Overrides: false,
                createdAt: Timestamp(date: Date().addingTimeInterval(-86400 * 30)),
                updatedAt: Timestamp(date: Date().addingTimeInterval(-3600))),
        Project(id: "128YgC7uVnge9RLxVrgG",
                name: "Movie Production A",
                description: "Action thriller movie production...",
                client: "Client A",
                location: "Mumbai",
                currency: "INR",
                // The total budget MUST match the sum of the categories
                budget: 50000,
                estimatedBudget: 50000,
                status: "ACTIVE",
                startDate: "01/06/2024",
                endDate: "31/12/2024",
                plannedDate: "01/06/2024",
                handoverDate: "31/12/2024",
                initialHandOverDate: "31/12/2024",
                maintenanceDate: "31/01/2025",
                isSuspended: nil,
                suspendedDate: nil,
                suspensionReason: nil,
                rejectionReason: nil,
                rejectedBy: nil,
                rejectedAt: nil,
                teamMembers: ["user1", "user2", "user3"],
                managerIds: ["manager1"],
                tempApproverID: nil,
                Allow_Template_Overrides: false,
                createdAt: Timestamp(date: Date().addingTimeInterval(-86400 * 30)),
                updatedAt: Timestamp(date: Date().addingTimeInterval(-3600))),
        
        Project(id: "p9Fh3aKeLzBvY7j2NnQx",
                name: "Corporate Rebranding",
                description: "Complete visual and messaging overhaul...",
                client: "Client B",
                location: "Bengaluru",
                currency: "INR",
                budget: 120000,
                estimatedBudget: 120000,
                status: "COMPLETED",
                startDate: "01/01/2024",
                endDate: "31/05/2024",
                plannedDate: "01/01/2024",
                handoverDate: "31/05/2024",
                initialHandOverDate: "31/05/2024",
                maintenanceDate: "30/06/2024",
                isSuspended: nil,
                suspendedDate: nil,
                suspensionReason: nil,
                rejectionReason: nil,
                rejectedBy: nil,
                rejectedAt: nil,
                teamMembers: ["user1", "user4"],
                managerIds: ["manager2"],
                tempApproverID: nil,
                Allow_Template_Overrides: false,
                createdAt: Timestamp(date: Date().addingTimeInterval(-86400 * 150)),
                updatedAt: Timestamp(date: Date().addingTimeInterval(-86400 * 10))),
    ]
}
