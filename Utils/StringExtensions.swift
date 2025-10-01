import Foundation

extension String {
    var formatPhoneNumber: String {
        if self.hasPrefix("+91") {
            let cleanedPhone = String(self.dropFirst(3))
            return cleanedPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        }
        return self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
}

// MARK: - Number Extensions
extension Int {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "₹0"
    }
} 