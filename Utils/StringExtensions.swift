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