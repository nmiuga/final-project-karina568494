import SwiftUI

struct ThemeBackground: View {
    var body: some View {
        // A subtle, adaptive gradient background that works across light/dark
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemBackground).opacity(0.95),
                Color(.secondarySystemBackground).opacity(0.95)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            ThemeBackground()
            content
        }
    }
}

extension View {
    func themedBackground() -> some View {
        self.modifier(ThemedBackground())
    }
}
