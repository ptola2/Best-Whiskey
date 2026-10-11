import SwiftUI
import UIKit

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

enum NoticeTone {
    case ok, caution, stop, info

    var background: Color {
        switch self {
        case .ok: return Theme.okSoft
        case .caution: return Theme.warnSoft
        case .stop: return Theme.stopSoft
        case .info: return Theme.accentSoft
        }
    }
}

struct Notice<Content: View>: View {
    var tone: NoticeTone
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
        }
        .font(.subheadline)
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
    }
}

struct CardTitle: View {
    let text: String
    var style: Font.TextStyle = .title2

    var body: some View {
        Text(text)
            .font(Theme.display(style))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Para: View {
    let text: String
    var font: Font = .body
    var color: Color = Theme.ink

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct StatusPill: View {
    let level: Level
    var text: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: Theme.symbol(level))
                .foregroundStyle(Theme.color(level))
            Text(text ?? level.label)
                .foregroundStyle(Theme.ink)
        }
        .font(.footnote.weight(.semibold))
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(Theme.soft(level), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct NoteList: View {
    let notes: [Note]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: Theme.symbol(note.level))
                        .foregroundStyle(Theme.color(note.level))
                    Para(text: note.text, font: .subheadline)
                }
            }
        }
    }
}

struct Bullets: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\u{2022}").foregroundStyle(Theme.muted)
                    Para(text: item, font: .subheadline)
                }
            }
        }
    }
}

struct WLButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger, quiet }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, kind: kind)
    }

    private struct StyledButton: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.body.weight(.semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(border, lineWidth: 1))
                .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
        }

        private var foreground: Color {
            switch kind {
            case .primary: return Theme.accentInk
            case .secondary: return Theme.ink
            case .danger: return Theme.stop
            case .quiet: return Theme.accent
            }
        }

        private var background: Color {
            switch kind {
            case .primary: return Theme.accent
            case .secondary: return Theme.surface
            case .danger, .quiet: return Color.clear
            }
        }

        private var border: Color {
            switch kind {
            case .primary: return Theme.accent
            case .secondary: return Theme.line
            case .danger: return Theme.stop
            case .quiet: return Color.clear
            }
        }
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .strikethrough(!isEnabled)
                .font(.callout.monospaced())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .foregroundStyle(selected ? Theme.surface : Theme.ink)
                .background(selected ? Theme.ink : Theme.surface2, in: Capsule())
                .overlay(Capsule().stroke(selected ? Theme.ink : Theme.line, lineWidth: 1))
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct YesNoControl: View {
    let value: Bool?
    let onSet: (Bool) -> Void

    var body: some View {
        HStack(spacing: 0) {
            segment("Yes", selected: value == true) { onSet(true) }
            Rectangle().fill(Theme.line).frame(width: 1, height: 34)
            segment("No", selected: value == false) { onSet(false) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .frame(width: 52, height: 34)
                .foregroundStyle(selected ? Theme.surface : Theme.ink2)
                .background(selected ? Theme.ink : Theme.surface2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A text field for an optional number, with its unit beside the label.
struct NumberField: View {
    let label: String
    var unit: String = ""
    @Binding var value: Double?
    var decimals = true

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(label).font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink2)
                if !unit.isEmpty {
                    Text(unit).font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            TextField("", text: $text)
                .keyboardType(decimals ? .decimalPad : .numberPad)
                .font(.body.monospaced())
                .focused($focused)
                .padding(10)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(focused ? Theme.accent : Theme.line, lineWidth: 1))
                .accessibilityLabel(unit.isEmpty ? label : "\(label), \(unit)")
        }
        .onAppear { text = Self.format(value) }
        .onChange(of: text) { _, newText in
            let parsed = Self.parse(newText)
            if parsed != value { value = parsed }
        }
        .onChange(of: value) { _, newValue in
            if !focused && Self.parse(text) != newValue { text = Self.format(newValue) }
        }
    }

    static func parse(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let v = Double(cleaned), v.isFinite else { return nil }
        return v
    }

    static func format(_ v: Double?) -> String {
        guard let v else { return "" }
        return Fmt.trimmed(v)
    }
}

struct KeyValueRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 10)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

/// Wraps children onto new rows, used for symptom chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// The Waterline mark: a circle with a waterline across it.
struct BrandMark: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let lineWidth = s * 0.05
            let r = s / 2 - lineWidth
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            context.stroke(circle, with: .color(Theme.accent), lineWidth: lineWidth)

            var wave = Path()
            let startX = c.x - r * 0.88
            let endX = c.x + r * 0.88
            let baseY = c.y + s * 0.07
            for i in 0...48 {
                let t = CGFloat(i) / 48
                let x = startX + (endX - startX) * t
                let y = baseY + sin(t * .pi * 4) * s * 0.035
                if i == 0 { wave.move(to: CGPoint(x: x, y: y)) } else { wave.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(wave, with: .color(Theme.accent), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            var lines = Path()
            lines.move(to: CGPoint(x: c.x - r * 0.72, y: c.y + s * 0.2))
            lines.addLine(to: CGPoint(x: c.x + r * 0.72, y: c.y + s * 0.2))
            lines.move(to: CGPoint(x: c.x - r * 0.5, y: c.y + s * 0.31))
            lines.addLine(to: CGPoint(x: c.x + r * 0.5, y: c.y + s * 0.31))
            context.stroke(lines, with: .color(Theme.accent.opacity(0.55)), style: StrokeStyle(lineWidth: lineWidth * 0.75, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Adds a Done button above number keyboards, which have no return key.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    func screenBackground() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }
}
