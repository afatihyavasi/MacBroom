import SwiftUI

// Reusable shadcn-style building blocks. Keep views declarative: compose these
// instead of re-styling primitives inline.

// MARK: - Card

private struct CardModifier: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    /// A bordered, rounded surface (shadcn `Card`).
    func shCard(padding: CGFloat = Theme.Space.md) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Buttons

/// Sizes shared across button styles.
enum SHSize { case sm, md
    var vPad: CGFloat { self == .sm ? 5 : 8 }
    var hPad: CGFloat { self == .sm ? 10 : 14 }
    var font: Font { self == .sm ? .shLabel : .shHeadline }
}

/// Shared chrome for every button variant. Lives in a ViewModifier (a real view
/// context) so hover/press/disabled state actually tracks — and so the hover
/// effect is shadcn's fill-alpha shift, which works on near-black/near-white
/// fills where `.brightness` would be invisible.
private struct SHButtonBackground: ViewModifier {
    let idleFill: Color
    let hoverFill: Color
    let fg: Color
    let border: Color?
    let size: SHSize
    let isPressed: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .font(size.font)
            .foregroundStyle(fg)
            .padding(.vertical, size.vPad)
            .padding(.horizontal, size.hPad)
            .frame(minHeight: size == .sm ? 24 : 30)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(hovering && isEnabled ? hoverFill : idleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(border ?? .clear, lineWidth: border == nil ? 0 : 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(isPressed ? 0.97 : 1)
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .contentShape(Rectangle())
    }
}

struct SHPrimaryButton: ButtonStyle {
    var size: SHSize = .md
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(SHButtonBackground(
            idleFill: Theme.primary, hoverFill: Theme.primary.opacity(0.9),
            fg: Theme.primaryForeground, border: nil, size: size, isPressed: configuration.isPressed))
    }
}

struct SHSecondaryButton: ButtonStyle {
    var size: SHSize = .md
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(SHButtonBackground(
            idleFill: Theme.secondary, hoverFill: Theme.secondary.opacity(0.8),
            fg: Theme.secondaryForeground, border: nil, size: size, isPressed: configuration.isPressed))
    }
}

struct SHOutlineButton: ButtonStyle {
    var size: SHSize = .md
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(SHButtonBackground(
            idleFill: Theme.card, hoverFill: Theme.muted,
            fg: Theme.foreground, border: Theme.border, size: size, isPressed: configuration.isPressed))
    }
}

struct SHDestructiveButton: ButtonStyle {
    var size: SHSize = .md
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(SHButtonBackground(
            idleFill: Theme.destructive, hoverFill: Theme.destructive.opacity(0.9),
            fg: Theme.destructiveFg, border: nil, size: size, isPressed: configuration.isPressed))
    }
}

struct SHGhostButton: ButtonStyle {
    var size: SHSize = .md
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(SHButtonBackground(
            idleFill: .clear, hoverFill: Theme.muted,
            fg: Theme.foreground, border: nil, size: size, isPressed: configuration.isPressed))
    }
}

extension ButtonStyle where Self == SHPrimaryButton {
    static var shPrimary: SHPrimaryButton { .init() }
    static func shPrimary(_ size: SHSize) -> SHPrimaryButton { .init(size: size) }
}
extension ButtonStyle where Self == SHSecondaryButton {
    static var shSecondary: SHSecondaryButton { .init() }
}
extension ButtonStyle where Self == SHOutlineButton {
    static var shOutline: SHOutlineButton { .init() }
    static func shOutline(_ size: SHSize) -> SHOutlineButton { .init(size: size) }
}
extension ButtonStyle where Self == SHDestructiveButton {
    static var shDestructive: SHDestructiveButton { .init() }
    static func shDestructive(_ size: SHSize) -> SHDestructiveButton { .init(size: size) }
}
extension ButtonStyle where Self == SHGhostButton {
    static var shGhost: SHGhostButton { .init() }
    static func shGhost(_ size: SHSize) -> SHGhostButton { .init(size: size) }
}

/// A borderless square icon button (header actions).
struct SHIconButton: View {
    let system: String
    var help: String = ""
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.mutedForeground)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(hovering ? Theme.muted : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
        .help(help)
        .accessibilityLabel(help.isEmpty ? Text("") : Text(help))
    }
}

// MARK: - Badge

struct SHBadge: View {
    let text: String
    var tint: Color = Theme.mutedForeground
    var body: some View {
        Text(text)
            .font(.shMono)
            .foregroundStyle(tint)
            .padding(.vertical, 2)
            .padding(.horizontal, 7)
            .background(
                Capsule(style: .continuous).fill(Theme.muted)
            )
    }
}

// MARK: - Separator

struct SHSeparator: View {
    var body: some View { Rectangle().fill(Theme.border).frame(height: 1) }
}

// MARK: - Row hover highlight

private struct HoverHighlight: ViewModifier {
    var radius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(hovering ? Theme.muted.opacity(0.6) : .clear)
            )
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
    }
}

extension View {
    /// Subtle muted fill on hover — for whole-row clickable list items.
    func shRowHover(_ radius: CGFloat = Theme.Radius.md) -> some View {
        modifier(HoverHighlight(radius: radius))
    }
}

// MARK: - Section header (icon + title)

struct SHSectionHeader: View {
    let title: String
    let systemImage: String
    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mutedForeground)
            Text(title).font(.shHeadline).foregroundStyle(Theme.foreground)
        }
    }
}

// MARK: - Checkbox (shadcn-style square)

struct SHCheckboxStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Theme.Space.sm) {
                box(configuration.isOn ? .on : .off)
                    .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: configuration.isOn)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
    }

    enum BoxState { case on, off, mixed }

    @ViewBuilder func box(_ state: BoxState) -> some View {
        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            .fill(state == .off ? Color.clear : Theme.primary)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(state == .off ? Theme.input : Theme.primary, lineWidth: 1)
            )
            .overlay(
                Group {
                    if state == .on {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.primaryForeground)
                    } else if state == .mixed {
                        Image(systemName: "minus").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.primaryForeground)
                    }
                }
            )
            .frame(width: 16, height: 16)
    }
}

/// A "select all / deselect all" header control: a tri-state checkbox plus a
/// label that flips to the deselect title once everything is selected. One click
/// toggles the whole set.
struct SHSelectAllToggle: View {
    let state: Bool?           // true=all, nil=mixed, false=none
    let selectTitle: String
    let deselectTitle: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.sm) {
                SHCheckboxStyle().box(state == true ? .on : (state == nil ? .mixed : .off))
                    .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: state)
                Text(state == true ? deselectTitle : selectTitle).font(.shLabel)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(state == true ? deselectTitle : selectTitle))
        .accessibilityValue(Text(state == true ? "all" : (state == nil ? "mixed" : "none")))
        .accessibilityAddTraits(.isButton)
    }
}

/// A standalone tri-state checkbox (for "select all" headers).
struct SHTriCheckbox: View {
    let state: Bool?   // true=all, false=none, nil=mixed
    var label: String = "Select all"
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: action) {
            SHCheckboxStyle().box(state == true ? .on : (state == nil ? .mixed : .off))
                .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: state)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(state == true ? "all" : (state == nil ? "mixed" : "none")))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Tabs (shadcn TabsList / TabsTrigger)

struct SHTabs<T: Hashable>: View {
    @Binding var selection: T
    let items: [(value: T, label: String)]
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.value) { item in
                let isSel = item.value == selection
                Button {
                    if reduceMotion {
                        selection = item.value
                    } else {
                        withAnimation(.snappy(duration: 0.18)) { selection = item.value }
                    }
                } label: {
                    Text(item.label)
                        .font(.shLabel)
                        .foregroundStyle(isSel ? Theme.foreground : Theme.mutedForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            ZStack {
                                if isSel {
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                        .fill(Theme.card)
                                        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                                        .matchedGeometryEffect(id: "tab", in: ns)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.label))
                .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.muted)
        )
    }
}

// MARK: - Progress

/// A thin themed progress track (0...1).
struct SHProgressBar: View {
    var value: Double
    var tint: Color = Theme.primary
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.muted)
                Capsule().fill(tint)
                    .frame(width: max(2, geo.size.width * CGFloat(min(max(value, 0), 1))))
            }
        }
        .frame(height: 6)
        .accessibilityValue(Text("\(Int(min(max(value, 0), 1) * 100)) percent"))
    }
}
