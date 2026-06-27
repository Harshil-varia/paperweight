import SwiftUI

/// Gruvbox Dark theme tokens and design system
struct Theme {
    // MARK: - Gruvbox Dark Palette

    // Backgrounds
    static let bg0 = Color(red: 0x28 / 255.0, green: 0x28 / 255.0, blue: 0x28 / 255.0)      // #282828
    static let bg0Hard = Color(red: 0x1d / 255.0, green: 0x20 / 255.0, blue: 0x21 / 255.0) // #1d2021
    static let bg1 = Color(red: 0x3c / 255.0, green: 0x38 / 255.0, blue: 0x36 / 255.0)      // #3c3836
    static let bg2 = Color(red: 0x50 / 255.0, green: 0x49 / 255.0, blue: 0x45 / 255.0)      // #504945
    static let bg3 = Color(red: 0x66 / 255.0, green: 0x5c / 255.0, blue: 0x54 / 255.0)      // #665c54

    // Foreground
    static let fg = Color(red: 0xeb / 255.0, green: 0xdb / 255.0, blue: 0xb2 / 255.0)       // #ebdbb2
    static let fg2 = Color(red: 0xd5 / 255.0, green: 0xc4 / 255.0, blue: 0xa1 / 255.0)      // #d5c4a1
    static let fg4 = Color(red: 0xa8 / 255.0, green: 0x99 / 255.0, blue: 0x84 / 255.0)      // #a89984
    static let gray = Color(red: 0x92 / 255.0, green: 0x83 / 255.0, blue: 0x74 / 255.0)     // #928374

    // Accents
    static let yellow = Color(red: 0xfa / 255.0, green: 0xbd / 255.0, blue: 0x2d / 255.0)   // #fabd2d
    static let green = Color(red: 0xb8 / 255.0, green: 0xbb / 255.0, blue: 0x26 / 255.0)    // #b8bb26
    static let aqua = Color(red: 0x8e / 255.0, green: 0xc0 / 255.0, blue: 0x7c / 255.0)     // #8ec07c
    static let orange = Color(red: 0xfe / 255.0, green: 0x80 / 255.0, blue: 0x19 / 255.0)   // #fe8019
    static let blue = Color(red: 0x83 / 255.0, green: 0xa5 / 255.0, blue: 0x98 / 255.0)     // #83a598

    // MARK: - Typography

    /// JetBrains Mono is bundled in Resources/Fonts and registered at launch by
    /// `FontRegistrar.registerBundledFonts()`. We select faces by their exact
    /// PostScript name because the Medium/SemiBold weights ship as their own
    /// families, so `Font.custom("JetBrains Mono").weight(.medium)` would not
    /// pick them up.
    private static func postScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium:
            return "JetBrainsMono-Medium"
        case .semibold:
            return "JetBrainsMono-SemiBold"
        case .bold, .heavy, .black:
            return "JetBrainsMono-Bold"
        default:
            return "JetBrainsMono-Regular"
        }
    }

    // MARK: - Font Styles

    /// JetBrains Mono at the given size/weight. If registration failed, SwiftUI's
    /// `Font.custom` falls back to the system font, so the UI degrades gracefully.
    static func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard FontRegistrar.isJetBrainsMonoAvailable else {
            return Font.system(size: size, weight: weight, design: .monospaced)
        }
        return Font.custom(postScriptName(for: weight), fixedSize: size)
    }

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    // MARK: - Corner Radius

    static let cornerRadiusSmall: CGFloat = 6
    static let cornerRadiusMedium: CGFloat = 10
    static let cornerRadiusLarge: CGFloat = 14

    // MARK: - Shadows

    static let shadowSmall = Shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    static let shadowMedium = Shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 4)
    static let shadowLarge = Shadow(color: Color.black.opacity(0.55), radius: 48, x: 0, y: 16)

    // MARK: - Component Styles

    struct Button {
        static let height: CGFloat = 32
        static let paddingHorizontal: CGFloat = 12
        static let paddingVertical: CGFloat = 8
    }

    struct Slider {
        static let height: CGFloat = 18
        static let trackHeight: CGFloat = 5
        static let knobDiameter: CGFloat = 18
    }

    struct Swatch {
        static let size: CGFloat = 60
        static let borderWidth: CGFloat = 0.5
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Apply Gruvbox-themed button styling
    func gruvboxButton() -> some View {
        self
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundColor(Theme.fg2)
            .padding(.vertical, Theme.spacingS)
            .padding(.horizontal, Theme.spacingM)
            .background(Theme.bg1)
            .border(Theme.bg2, width: 0.5)
            .cornerRadius(Theme.cornerRadiusSmall)
    }

    /// Apply Gruvbox-themed panel background
    func gruvboxPanel() -> some View {
        self
            .background(Theme.bg0)
            .border(Theme.bg2, width: 0.5)
            .cornerRadius(Theme.cornerRadiusMedium)
    }
}

// MARK: - Shadow Model

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}
