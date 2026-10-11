import SwiftUI
import UIKit

// Same palette as the Waterline web app: cool chart paper, deep ink, mineral teal,
// and an eight-step sequential ramp for the metabolic phases.

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

enum Theme {
    static let paper = Color.adaptive(0xEDF2F3, 0x0B1419)
    static let surface = Color.adaptive(0xFFFFFF, 0x121F26)
    static let surface2 = Color.adaptive(0xF4F8F9, 0x17282F)
    static let ink = Color.adaptive(0x0F2530, 0xE1EBEE)
    static let ink2 = Color.adaptive(0x3C5460, 0xB4C5CC)
    static let muted = Color.adaptive(0x647A85, 0x8399A3)
    static let line = Color.adaptive(0xD2DDE1, 0x263842)
    static let accent = Color.adaptive(0x16708A, 0x62BAD2)
    static let accentInk = Color.adaptive(0xFFFFFF, 0x062330)
    static let accentSoft = Color.adaptive(0xD7EBF1, 0x163742)

    static let ok = Color.adaptive(0x23704A, 0x62C891)
    static let okSoft = Color.adaptive(0xE0F1E7, 0x132F20)
    static let warn = Color.adaptive(0x9A5B00, 0xE8AA4E)
    static let warnSoft = Color.adaptive(0xFBEDD5, 0x33270F)
    static let stop = Color.adaptive(0xB3261E, 0xF37A6F)
    static let stopSoft = Color.adaptive(0xFBE2DF, 0x3B1815)

    static let bands: [Color] = [
        .adaptive(0xD3E8EE, 0x173842), .adaptive(0xB7DAE4, 0x1C4A58),
        .adaptive(0x93C6D5, 0x225D6E), .adaptive(0x6BADC1, 0x2B7287),
        .adaptive(0x4791A9, 0x3A88A0), .adaptive(0x2B7690, 0x529FB6),
        .adaptive(0x1A5B71, 0x74B8CB), .adaptive(0x0F3F50, 0x9ED2E0),
    ]

    static func color(_ level: Level) -> Color {
        switch level {
        case .ok: return ok
        case .caution: return warn
        case .stop: return stop
        }
    }

    static func soft(_ level: Level) -> Color {
        switch level {
        case .ok: return okSoft
        case .caution: return warnSoft
        case .stop: return stopSoft
        }
    }

    static func symbol(_ level: Level) -> String {
        switch level {
        case .ok: return "checkmark.circle"
        case .caution: return "exclamationmark.triangle"
        case .stop: return "xmark.octagon"
        }
    }

    static func display(_ style: Font.TextStyle = .title2) -> Font { .system(style, design: .serif) }
}
