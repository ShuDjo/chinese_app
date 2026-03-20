import SwiftUI

// MARK: - Theme

enum Theme {
    static let red  = Color(red: 0.78, green: 0.08, blue: 0.08)
    static let gold = Color(red: 0.92, green: 0.72, blue: 0.18)
    static let jade = Color(red: 0.15, green: 0.52, blue: 0.32)
    static let warmBg = Color(red: 0.98, green: 0.96, blue: 0.93)
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius))
    }
}
