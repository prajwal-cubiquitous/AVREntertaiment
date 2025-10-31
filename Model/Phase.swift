//
//  Phase.swift
//  AVREntertainment
//
//  Created by Auto on 10/29/25.
//

import Foundation
import FirebaseFirestore

struct Phase: Identifiable, Codable {
    @DocumentID var id: String?
    
    let phaseName: String
    let phaseNumber: Int // Order of the phase (1, 2, 3, etc.)
    let startDate: String? // Format: "dd/MM/yyyy"
    let endDate: String? // Format: "dd/MM/yyyy"
    let departments: [String: Double] // Departments with their budgets
    let categories: [String] // Categories for this phase
    let isEnabled: Bool? // Whether this phase is enabled (default true)
    
    // Firestore Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    // MARK: - Computed Properties
    
    var totalBudget: Double {
        departments.values.reduce(0, +)
    }
    
    var budgetFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: totalBudget)) ?? "₹0.00"
    }
    
    var dateRangeFormatted: String {
        guard let start = startDate, let end = endDate else {
            return "Dates not set"
        }
        return "\(start) - \(end)"
    }
    
    // Default to true when the field is absent in Firestore
    var isEnabledValue: Bool { isEnabled ?? true }
}

