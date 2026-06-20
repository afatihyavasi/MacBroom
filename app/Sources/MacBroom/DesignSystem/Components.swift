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

private struct SHButtonBackground: ViewModifier {
    let fill: Color
    let fg: Color
    let border: Color?
    let size: SHSize
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
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(border ?? .clear, lineWidth: border == nil ? 0 : 1)
                    )
            )
            .brightness(hovering ? 0.04 : 0)
            .onHover { hovering = $0 }
            .contentShape(Rectangle())
    }
}

struct SHPrimaryButton: ButtonStyle {
    var size: SHSize = .md
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(SHButtonBackground(fill: Theme.primary, fg: Theme.primaryForeground, border: nil, size: size))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SHSecondaryButton: ButtonStyle {
    var size: SHSize = .md
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(SHButtonBackground(fill: Theme.secondary, fg: Theme.secondaryForeground, border: nil, size: size))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SHOutlineButton: ButtonStyle {
    var size: SHSize = .md
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(SHButtonBackground(fill: Theme.card, fg: Theme.foreground, border: Theme.border, size: size))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SHDestructiveButton: ButtonStyle {
    var size: SHSize = .md
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(SHButtonBackground(fill: Theme.destructive, fg: Theme.destructiveFg, border: nil, size: size))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SHGhostButton: ButtonStyle {
    var size: SHSize = .md
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(Theme.foreground)
            .padding(.vertical, size.vPad)
            .padding(.horizontal, size.hPad)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(hovering ? Theme.muted : .clear)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .onHover { hovering = $0 }
            .contentShape(Rectangle())
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
        .help(help)
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
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Theme.Space.sm) {
                box(configuration.isOn ? .on : .off)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

/// A standalone tri-state checkbox (for "select all" headers).
struct SHTriCheckbox: View {
    let state: Bool?   // true=all, false=none, nil=mixed
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            SHCheckboxStyle().box(state == true ? .on : (state == nil ? .mixed : .off))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tabs (shadcn TabsList / TabsTrigger)

struct SHTabs<T: Hashable>: View {
    @Binding var selection: T
    let items: [(value: T, label: String)]
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.value) { item in
                let isSel = item.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.18)) { selection = item.value }
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
    }
}
