import SwiftUI

enum Theme {
    // Warm off-white background that's not pure white
    static let background = Color(red: 0.965, green: 0.960, blue: 0.953)   // #F6F5F3
    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.940, green: 0.935, blue: 0.925) // #F0EEE8
    static let surfaceElevated = Color(red: 1.0, green: 0.995, blue: 0.985) // slight warm white

    static let border = Color(red: 0.10, green: 0.09, blue: 0.07).opacity(0.08)
    static let borderStrong = Color(red: 0.10, green: 0.09, blue: 0.07).opacity(0.15)

    static let textPrimary = Color(red: 0.08, green: 0.07, blue: 0.06)      // near-black warm
    static let textSecondary = Color(red: 0.40, green: 0.37, blue: 0.33)
    static let textTertiary = Color(red: 0.62, green: 0.58, blue: 0.53)

    // Accent: deep, slightly warm dark (better than pure black)
    static let accent = Color(red: 0.11, green: 0.09, blue: 0.08)
    // Secondary accent: subtle terracotta — used sparingly
    static let highlight = Color(red: 0.85, green: 0.42, blue: 0.30)        // soft coral/terracotta
    static let highlightTint = Color(red: 0.95, green: 0.85, blue: 0.78)    // pale terracotta wash

    static let success = Color(red: 0.20, green: 0.55, blue: 0.30)
    static let warning = Color(red: 0.90, green: 0.55, blue: 0.10)
    static let danger = Color(red: 0.84, green: 0.30, blue: 0.25)
}

extension View {
    func cardStyle(radius: CGFloat = 16, padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.border, lineWidth: 1))
    }
}
