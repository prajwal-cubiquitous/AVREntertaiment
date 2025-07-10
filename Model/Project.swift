// Project.swift
import Foundation
import FirebaseFirestore

enum ProjectStatus: String, Codable, CaseIterable {
    case ACTIVE
    case INACTIVE
    case COMPLETED
}

struct Project: Identifiable, Codable, Equatable, Hashable {
    
    @DocumentID var id: String?
    
    let name: String
    let description: String
    let budget: Double // This remains the total budget stored in Firestore
    let status: String
    let startDate: String?
    let endDate: String?
    let teamMembers: [String]
    let managerId: String
    
    // MARK: - New Property for Department Breakdown
    // This dictionary holds the user-defined departments and their amounts.
    // Example: ["Casting": 10000, "Location Fees": 5000, "Catering": 3000]
    let departments: [String: Double]
    
    // Firestore Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    // ... (Computed Properties remain the same) ...
    var statusType: ProjectStatus { 
        ProjectStatus(rawValue: status) ?? .INACTIVE // Default to INACTIVE instead of UNKNOWN
    }
    
    var budgetFormatted: String {
        // This continues to work on the total budget
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: budget)) ?? "₹0.00"
    }

    var dateRangeFormatted: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "dd/MM/yyyy"
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        
        switch (startDate, endDate) {
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
        Project(id: "128YgC7uVnge9RLxVrgG",
                name: "Movie Production A",
                description: "Action thriller movie production...",
                // The total budget MUST match the sum of the categories
                budget: 50000,
                status: "ACTIVE",
                startDate: "01/06/2024",
                endDate: "31/12/2024",
                teamMembers: ["user1", "user2", "user3"],
                managerId: "manager1",
                // The new dictionary for department breakdown
                departments: [
                    "Casting": 15000,
                    "Location & Permits": 10000,
                    "Equipment Rental": 12000,
                    "Post-Production": 8000,
                    "Marketing": 5000
                ],
                createdAt: Timestamp(date: Date().addingTimeInterval(-86400 * 30)),
                updatedAt: Timestamp(date: Date().addingTimeInterval(-3600))),
        
        Project(id: "p9Fh3aKeLzBvY7j2NnQx",
                name: "Corporate Rebranding",
                description: "Complete visual and messaging overhaul...",
                budget: 120000,
                status: "COMPLETED",
                startDate: "01/01/2024",
                endDate: "31/05/2024",
                teamMembers: ["user1", "user4"],
                managerId: "manager2",
                departments: [
                    "Design Agency Fees": 75000,
                    "Market Research": 25000,
                    "Website Development": 20000
                ],
                createdAt: Timestamp(date: Date().addingTimeInterval(-86400 * 150)),
                updatedAt: Timestamp(date: Date().addingTimeInterval(-86400 * 10))),
    ]
}
