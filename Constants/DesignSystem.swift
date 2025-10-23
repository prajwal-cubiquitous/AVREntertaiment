import SwiftUI

// MARK: - Apple Design System
struct DesignSystem {
    
    // MARK: - Spacing (Apple's 8pt Grid System)
    struct Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
        static let jumbo: CGFloat = 48
    }
    
    // MARK: - Corner Radius (Apple's Consistent Radii)
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let card: CGFloat = 16
        static let button: CGFloat = 12
        static let field: CGFloat = 10
    }
    
    // MARK: - Shadows (Apple's Elevation System)
    struct Shadow {
        static let small = ShadowStyle(
            color: .black.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let medium = ShadowStyle(
            color: .black.opacity(0.12),
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let large = ShadowStyle(
            color: .black.opacity(0.16),
            radius: 16,
            x: 0,
            y: 8
        )
        
        static let button = ShadowStyle(
            color: .black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Animation Durations (Apple's Standard Timings)
    struct Animation {
        static let fast: Double = 0.15
        static let standard: Double = 0.25
        static let slow: Double = 0.35
        static let interactive: Double = 0.1
        
        static let fastSpring = SwiftUI.Animation.easeInOut(duration: fast)
        static let standardSpring = SwiftUI.Animation.easeInOut(duration: standard)
        static let slowSpring = SwiftUI.Animation.easeInOut(duration: slow)
        static let interactiveSpring = SwiftUI.Animation.easeInOut(duration: interactive)
    }
    
    // MARK: - Typography Scale (Apple's Type System)
    struct Typography {
        static let largeTitle = Font.compatibleLargeTitle.weight(.bold)
        static let title1 = Font.compatibleTitle.weight(.semibold)
        static let title2 = Font.compatibleTitle2.weight(.semibold)
        static let title3 = Font.compatibleTitle3.weight(.medium)
        static let headline = Font.compatibleHeadline.weight(.semibold)
        static let body = Font.body
        static let callout = Font.compatibleCallout
        static let subheadline = Font.compatibleSubheadline
        static let footnote = Font.compatibleFootnote
        static let caption1 = Font.compatibleCaption
        static let caption2 = Font.compatibleCaption2
    }
}

// MARK: - Shadow Style Helper
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Modifiers for Consistent Styling
struct CardStyle: ViewModifier {
    let shadowLevel: ShadowStyle
    
    init(shadow: ShadowStyle = DesignSystem.Shadow.medium) {
        self.shadowLevel = shadow
    }
    
    func body(content: Content) -> some View {
        content
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.card)
            .shadow(
                color: shadowLevel.color,
                radius: shadowLevel.radius,
                x: shadowLevel.x,
                y: shadowLevel.y
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let isDestructive: Bool
    let isSecondary: Bool
    
    init(isDestructive: Bool = false, isSecondary: Bool = false) {
        self.isDestructive = isDestructive
        self.isSecondary = isSecondary
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(foregroundColor)
            .padding(.vertical, DesignSystem.Spacing.medium)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.button)
            .shadow(
                color: shadowColor,
                radius: DesignSystem.Shadow.button.radius,
                x: DesignSystem.Shadow.button.x,
                y: DesignSystem.Shadow.button.y
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(DesignSystem.Animation.interactiveSpring, value: configuration.isPressed)
    }
    
    private var backgroundColor: Color {
        if isSecondary {
            return Color(UIColor.secondarySystemGroupedBackground)
        } else if isDestructive {
            return .red
        } else {
            return .accentColor
        }
    }
    
    private var foregroundColor: Color {
        if isSecondary {
            return .accentColor
        } else {
            return Color(Constants.PrimaryOppositeColor)
        }
    }
    
    private var shadowColor: Color {
        if isSecondary {
            return .clear
        } else {
            return DesignSystem.Shadow.button.color
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.callout)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.accentColor)
            .padding(.vertical, DesignSystem.Spacing.small)
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.small)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.interactiveSpring, value: configuration.isPressed)
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.medium)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.field)
    }
}

struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.secondary)
            // .textCase(.uppercase) // iOS 14+ only
            // .tracking(0.5) // iOS 16+ only
    }
}

// MARK: - View Extensions for Easy Use
extension View {
    func cardStyle(shadow: ShadowStyle = DesignSystem.Shadow.medium) -> some View {
        self.modifier(CardStyle(shadow: shadow))
    }
    
    func fieldStyle() -> some View {
        self.modifier(FieldStyle())
    }
    
    func sectionHeaderStyle() -> some View {
        self.modifier(SectionHeaderStyle())
    }
    
    func primaryButton(isDestructive: Bool = false, isSecondary: Bool = false) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isDestructive: isDestructive, isSecondary: isSecondary))
    }
    
    func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
}

// MARK: - Haptic Feedback Helper
struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(type)
    }
    
    static func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
} 