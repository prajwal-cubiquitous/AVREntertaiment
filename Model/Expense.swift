import Foundation
import SwiftUI
import FirebaseFirestore

struct Expense: Identifiable, Codable {
    @DocumentID var id: String?
    
    let projectId: String
    let date: String // Format: "dd/MM/yyyy"
    let amount: Double
    let department: String
    let phaseId: String? // Phase ID for phase-based expenses
    let phaseName: String? // Phase name for phase-based expenses
    let categories: [String] // Array of category names
    let modeOfPayment: PaymentMode
    let description: String // Description of the expense
    let attachmentURL: String? // Firebase Storage URL
    let attachmentName: String? // Original file name
    let paymentProofURL: String? // Firebase Storage URL for payment proof (required for UPI and check)
    let paymentProofName: String? // Original file name for payment proof
    let submittedBy: String // User phone number
    let status: ExpenseStatus
    let remark: String? // Optional remark for approval/rejection
    let isAdmin: Bool // Whether this expense requires admin approval (default: false)
    let approvedBy: String? // User phone number who approved the expense
    let rejectedBy: String? // User phone number who rejected the expense
    
    // Anonymous Department Tracking
    let isAnonymous: Bool? // Whether this expense is in anonymous department
    let originalDepartment: String? // Original department name before it was deleted
    let departmentDeletedAt: Timestamp? // When the department was deleted
    
    // Firestore Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    // MARK: - Custom Decoder
    enum CodingKeys: String, CodingKey {
        case projectId, date, amount, department, phaseId, phaseName, categories
        case modeOfPayment, description, attachmentURL, attachmentName, paymentProofURL, paymentProofName, submittedBy
        case status, remark, isAdmin, isAnonymous, originalDepartment, departmentDeletedAt
        case approvedBy, rejectedBy
        case createdAt, updatedAt
    }
    
    // MARK: - Memberwise Initializer
    init(
        id: String? = nil,
        projectId: String,
        date: String,
        amount: Double,
        department: String,
        phaseId: String? = nil,
        phaseName: String? = nil,
        categories: [String],
        modeOfPayment: PaymentMode,
        description: String,
        attachmentURL: String? = nil,
        attachmentName: String? = nil,
        paymentProofURL: String? = nil,
        paymentProofName: String? = nil,
        submittedBy: String,
        status: ExpenseStatus,
        remark: String? = nil,
        isAdmin: Bool = false,
        isAnonymous: Bool? = nil,
        originalDepartment: String? = nil,
        departmentDeletedAt: Timestamp? = nil,
        approvedBy: String? = nil,
        rejectedBy: String? = nil,
        createdAt: Timestamp,
        updatedAt: Timestamp
    ) {
        self.id = id
        self.projectId = projectId
        self.date = date
        self.amount = amount
        self.department = department
        self.phaseId = phaseId
        self.phaseName = phaseName
        self.categories = categories
        self.modeOfPayment = modeOfPayment
        self.description = description
        self.attachmentURL = attachmentURL
        self.attachmentName = attachmentName
        self.paymentProofURL = paymentProofURL
        self.paymentProofName = paymentProofName
        self.submittedBy = submittedBy
        self.status = status
        self.remark = remark
        self.isAdmin = isAdmin
        self.isAnonymous = isAnonymous
        self.originalDepartment = originalDepartment
        self.departmentDeletedAt = departmentDeletedAt
        self.approvedBy = approvedBy
        self.rejectedBy = rejectedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectId = try container.decode(String.self, forKey: .projectId)
        date = try container.decode(String.self, forKey: .date)
        amount = try container.decode(Double.self, forKey: .amount)
        department = try container.decode(String.self, forKey: .department)
        phaseId = try container.decodeIfPresent(String.self, forKey: .phaseId)
        phaseName = try container.decodeIfPresent(String.self, forKey: .phaseName)
        categories = try container.decode([String].self, forKey: .categories)
        modeOfPayment = try container.decode(PaymentMode.self, forKey: .modeOfPayment)
        description = try container.decode(String.self, forKey: .description)
        attachmentURL = try container.decodeIfPresent(String.self, forKey: .attachmentURL)
        attachmentName = try container.decodeIfPresent(String.self, forKey: .attachmentName)
        paymentProofURL = try container.decodeIfPresent(String.self, forKey: .paymentProofURL)
        paymentProofName = try container.decodeIfPresent(String.self, forKey: .paymentProofName)
        submittedBy = try container.decode(String.self, forKey: .submittedBy)
        status = try container.decode(ExpenseStatus.self, forKey: .status)
        remark = try container.decodeIfPresent(String.self, forKey: .remark)
        isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false // Default to false if not present
        isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous)
        originalDepartment = try container.decodeIfPresent(String.self, forKey: .originalDepartment)
        departmentDeletedAt = try container.decodeIfPresent(Timestamp.self, forKey: .departmentDeletedAt)
        approvedBy = try container.decodeIfPresent(String.self, forKey: .approvedBy)
        rejectedBy = try container.decodeIfPresent(String.self, forKey: .rejectedBy)
        createdAt = try container.decode(Timestamp.self, forKey: .createdAt)
        updatedAt = try container.decode(Timestamp.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(date, forKey: .date)
        try container.encode(amount, forKey: .amount)
        try container.encode(department, forKey: .department)
        try container.encodeIfPresent(phaseId, forKey: .phaseId)
        try container.encodeIfPresent(phaseName, forKey: .phaseName)
        try container.encode(categories, forKey: .categories)
        try container.encode(modeOfPayment, forKey: .modeOfPayment)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(attachmentURL, forKey: .attachmentURL)
        try container.encodeIfPresent(attachmentName, forKey: .attachmentName)
        try container.encodeIfPresent(paymentProofURL, forKey: .paymentProofURL)
        try container.encodeIfPresent(paymentProofName, forKey: .paymentProofName)
        try container.encode(submittedBy, forKey: .submittedBy)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(remark, forKey: .remark)
        try container.encode(isAdmin, forKey: .isAdmin)
        try container.encodeIfPresent(isAnonymous, forKey: .isAnonymous)
        try container.encodeIfPresent(originalDepartment, forKey: .originalDepartment)
        try container.encodeIfPresent(departmentDeletedAt, forKey: .departmentDeletedAt)
        try container.encodeIfPresent(approvedBy, forKey: .approvedBy)
        try container.encodeIfPresent(rejectedBy, forKey: .rejectedBy)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
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
    case Card = "By Card"
    
    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .upi: return "qrcode"
        case .check: return "checkmark.rectangle"
        case .Card: return "creditcard"
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
            phaseId: "phase1",
            phaseName: "Phase 1",
            categories: ["Wages & Crew Payments", "Equipment Rental"],
            modeOfPayment: .cash,
            description: "Costume rentals for lead actors and supporting cast",
            attachmentURL: nil,
            attachmentName: nil,
            paymentProofURL: nil,
            paymentProofName: nil,
            submittedBy: "+919876543210",
            status: .pending,
            remark: nil, isAdmin: false,
            isAnonymous: false,
            originalDepartment: nil,
            departmentDeletedAt: nil,
            approvedBy: nil,
            rejectedBy: nil,
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )
    ]
} 
