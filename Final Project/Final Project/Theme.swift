import SwiftUI

// MARK: - Hex Color Helper (single definition)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Theme (single definition)
struct Theme {
    // Core palette
    static let text = Color(hex: "#5C4B51")
    static let background = Color(hex: "#F2EBBF")
    static let accentTeal = Color(hex: "#8CBEB2")
    static let accentGold = Color(hex: "#F3B562")
    static let accentRed = Color(hex: "#F06060")

    // Derived colors for components/animations
    static let splashGradient: [Color] = [
        Theme.accentGold.opacity(0.6),
        Theme.accentTeal.opacity(0.6),
        Theme.accentRed.opacity(0.6)
    ]

    // Shelves & loading search page helpers
    static let shelfBackground = Theme.background
    static let shelfBorder = Theme.text.opacity(0.15)
    static let loadingSpinner = Theme.accentTeal
    static let loadingBackground = Theme.background
}

// MARK: - Poppins Fonts
extension Font {
    static func poppinsLight(size: CGFloat) -> Font { .custom("Poppins-Light", size: size) }
    static func poppinsRegular(size: CGFloat) -> Font { .custom("Poppins-Regular", size: size) }
    static func poppinsMedium(size: CGFloat) -> Font { .custom("Poppins-Medium", size: size) }
    static func poppinsBold(size: CGFloat) -> Font { .custom("Poppins-Bold", size: size) }
}

// MARK: - Text Styles
struct TextStylesModifier: ViewModifier {
    enum Kind { case body, subheadline, headline }
    let kind: Kind

    func body(content: Content) -> some View {
        switch kind {
        case .body:
            content
                .font(.poppinsRegular(size: 16))
                .foregroundStyle(Theme.text)
        case .subheadline:
            content
                .font(.poppinsLight(size: 14))
                .foregroundStyle(Theme.text.opacity(0.8))
        case .headline:
            content
                .font(.poppinsMedium(size: 20))
                .foregroundStyle(Theme.text)
        }
    }
}

extension View {
    func bodyText() -> some View { modifier(TextStylesModifier(kind: .body)) }
    func subheadlineText() -> some View { modifier(TextStylesModifier(kind: .subheadline)) }
    func headlineText() -> some View { modifier(TextStylesModifier(kind: .headline)) }
}

// MARK: - Legacy compatibility mapping (if other files used Theme1)
// You can remove Theme1 elsewhere and reference Theme directly.
enum Theme1 {
    static let primaryMint = Theme.accentTeal
    static let primaryPeach = Theme.accentGold
    static let primarySand = Theme.background
    static let accentPink = Theme.accentRed
    static let accentTeal = Theme.accentTeal
}

// MARK: - Button Style
struct ThemedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.poppinsMedium(size: 16))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.accentRed.opacity(configuration.isPressed ? 0.85 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Opening/Splash Background
struct SplashBackground: View {
    var body: some View {
        LinearGradient(colors: Theme.splashGradient,
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
        .ignoresSafeArea()
    }
}

