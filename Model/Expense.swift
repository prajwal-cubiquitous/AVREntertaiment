import Foundation
import SwiftUI
import FirebaseFirestore

struct Expense: Identifiable, Codable {
    @DocumentID var id: String?
    
    let projectId: String
    let date: String // Format: "dd/MM/yyyy"
    let amount: Double
    let department: String
    let categories: [String] // Array of category names
    let modeOfPayment: PaymentMode
    let description: String // Description of the expense
    let attachmentURL: String? // Firebase Storage URL
    let attachmentName: String? // Original file name
    let submittedBy: String // User phone number
    let status: ExpenseStatus
    let remark: String? // Optional remark for approval/rejection
    
    // Firestore Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    // MARK: - Computed Properties
    var amountFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0.00"
    }
    
    var dateFormatted: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "dd/MM/yyyy"
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        
        guard let dateObj = inputFormatter.date(from: date) else {
            return "Invalid Date"
        }
        return outputFormatter.string(from: dateObj)
    }
    
    var categoriesString: String {
        categories.joined(separator: ", ")
    }
}

// MARK: - Supporting Enums
enum PaymentMode: String, Codable, CaseIterable {
    case cash = "By cash"
    case upi = "By UPI"
    case check = "By check"
    
    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .upi: return "creditcard"
        case .check: return "doc.text"
        }
    }
}

enum ExpenseStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .approved: return "checkmark.circle"
        case .rejected: return "xmark.circle"
        }
    }
}

// MARK: - Sample Data
extension Expense {
    static let sampleData: [Expense] = [
        Expense(
            id: "expense1",
            projectId: "128YgC7uVnge9RLxVrgG",
            date: "15/04/2024",
            amount: 8000,
            department: "Costumes",
            categories: ["Wages & Crew Payments", "Equipment Rental"],
            modeOfPayment: .cash,
            description: "Costume rentals for lead actors and supporting cast",
            attachmentURL: nil,
            attachmentName: nil,
            submittedBy: "+919876543210",
            status: .pending,
            remark: nil,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    ]
} 
