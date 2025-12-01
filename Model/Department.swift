//
//  Department.swift
//  AVREntertainment
//
//  Created by Auto on 12/29/25.
//

import Foundation
import FirebaseFirestore

struct Department: Identifiable, Codable {
    @DocumentID var id: String?
    
    let name: String
    let contractorMode: String // "Labour-Only" or "Turnkey"
    let lineItems: [DepartmentLineItemData]
    let phaseId: String // Reference to parent phase
    let projectId: String // Reference to parent project
    
    // Firestore Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    // MARK: - Computed Properties
    
    var totalBudget: Double {
        lineItems.reduce(0) { $0 + $1.total }
    }
    
    var budgetFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: totalBudget)) ?? "₹0.00"
    }
}

// MARK: - Department Line Item Data (for Firestore)
struct DepartmentLineItemData: Codable {
    var itemType: String
    var item: String
    var spec: String
    var quantity: Double
    var unitPrice: Double
    
    var total: Double {
        quantity * unitPrice
    }
    
    init(itemType: String = "", item: String = "", spec: String = "", quantity: Double = 0, unitPrice: Double = 0) {
        self.itemType = itemType
        self.item = item
        self.spec = spec
        self.quantity = quantity
        self.unitPrice = unitPrice
    }
}

