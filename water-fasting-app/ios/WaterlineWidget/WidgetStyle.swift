import SwiftUI
import UIKit

/// The app's palette (Theme.swift), for the widget and the Live Activity.
enum WidgetStyle {
    static let accent = adaptive(0x16708A, 0x62BAD2)
    static let ink = adaptive(0x0F2530, 0xE1EBEE)
    static let muted = adaptive(0x647A85, 0x8399A3)
    static let paper = adaptive(0xEDF2F3, 0x0B1419)
    static let surface = adaptive(0xFFFFFF, 0x121F26)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}
