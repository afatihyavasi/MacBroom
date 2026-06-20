import SwiftUI
import AppKit

// MacBroom v2 design system — a shadcn-inspired token set for SwiftUI.
//
// Colors are dynamic NSColors so they adapt to the macOS light/dark appearance
// automatically, anywhere they're used (no need to thread `colorScheme`). The
// palette follows shadcn's neutral "zinc" scale, with a restrained indigo
// accent for brand moments. Radii / spacing / typography mirror shadcn's scale.

extension NSColor {
    fileprivate convenience init(rgb: UInt) {
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    /// A color that resolves to `light` or `dark` based on the active appearance.
    static func token(_ light: UInt, _ dark: UInt) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
    }
}

/// Design tokens. Reference these everywhere instead of literal colors/sizes.
enum Theme {
    // Surfaces & text (zinc)
    static let background       = Color.token(0xFAFAFA, 0x09090B)
    static let foreground       = Color.token(0x09090B, 0xFAFAFA)
    static let card             = Color.token(0xFFFFFF, 0x18181B)
    static let cardForeground   = foreground
    static let muted            = Color.token(0xF4F4F5, 0x27272A)
    static let mutedForeground  = Color.token(0x71717A, 0xA1A1AA)
    static let border           = Color.token(0xE4E4E7, 0x27272A)
    static let input            = Color.token(0xE4E4E7, 0x3F3F46)

    // Primary (near-black ↔ near-white, shadcn's default action)
    static let primary            = Color.token(0x18181B, 0xFAFAFA)
    static let primaryForeground  = Color.token(0xFAFAFA, 0x18181B)

    // Secondary / accent surfaces
    static let secondary           = Color.token(0xF4F4F5, 0x27272A)
    static let secondaryForeground = Color.token(0x18181B, 0xFAFAFA)

    // Brand accent (indigo) + semantic colors
    static let accent           = Color.token(0x6366F1, 0x818CF8)
    static let accentForeground = Color.white
    static let destructive      = Color.token(0xEF4444, 0xF87171)
    static let destructiveFg    = Color.white
    static let success          = Color.token(0x16A34A, 0x4ADE80)
    static let warning          = Color.token(0xD97706, 0xFBBF24)
    static let ring             = accent

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let pill: CGFloat = 999
    }

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
}

extension Font {
    // shadcn-ish type ramp on the system font.
    static let shTitle    = Font.system(size: 16, weight: .semibold)
    static let shHeadline = Font.system(size: 13, weight: .semibold)
    static let shBody     = Font.system(size: 13, weight: .regular)
    static let shLabel    = Font.system(size: 12, weight: .medium)
    static let shCaption  = Font.system(size: 11, weight: .regular)
    static let shMono     = Font.system(size: 11, weight: .medium).monospacedDigit()
}
