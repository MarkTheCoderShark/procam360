import SwiftUI
import UIKit

enum FVColors {
    static let primary = Color("Primary", bundle: .main)
    static let secondary = Color("Secondary", bundle: .main)
    static let accent = Color("Accent", bundle: .main)
    
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    static let groupedBackground = Color(UIColor.systemGroupedBackground)
    
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    static let quaternaryLabel = Color(UIColor.quaternaryLabel)
    
    static let separator = Color(UIColor.separator)
    static let opaqueSeparator = Color(UIColor.opaqueSeparator)
    
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    
    static let statusWalkthrough = Color.blue
    static let statusInProgress = Color.orange
    static let statusCompleted = Color.green
    
    enum Fallback {
        static let primary = Color(hex: "007AFF")
        static let secondary = Color(hex: "5856D6")
        static let accent = Color(hex: "FF9500")
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
