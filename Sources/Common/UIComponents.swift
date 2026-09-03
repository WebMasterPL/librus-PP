import SwiftUI
import UIKit

// Shared visual building blocks so every screen reads as one app.

// MARK: - Cards

/// Elevated surface: hairline border + soft shadow, consistent padding & radius.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Space.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Color.appHairline.opacity(0.6), lineWidth: 0.5)
            )
            .cardShadow()
    }
}

/// Card with a title row (icon + heading + optional trailing accessory).
struct SectionCard<Content: View>: View {
    let title: String
    var systemImage: String?
    var trailing: AnyView?
    @ViewBuilder var content: Content

    init(_ title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = nil
        self.content = content()
    }

    init<T: View>(_ title: String, systemImage: String? = nil,
                  @ViewBuilder trailing: () -> T, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = AnyView(trailing())
        self.content = content()
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack(spacing: Theme.Space.sm) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    trailing
                }
                content
            }
        }
    }
}

// MARK: - Pills & chips

/// Solid rounded label used for grades and strong statuses.
struct Pill: View {
    let text: String
    var color: Color = .accentColor
    var prominent: Bool = true

    var body: some View {
        Text(text)
            .font(.footnote.weight(.bold))
            .fontDesign(.rounded)
            .monospacedDigit()
            .foregroundStyle(prominent ? .white : color)
            .padding(.horizontal, Theme.Space.sm)
            .padding(.vertical, Theme.Space.xxs + 1)
            .background(
                prominent ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.14)),
                in: Capsule()
            )
    }
}

/// Subtle chip for secondary metadata (weight, room, category…).
struct Chip: View {
    let text: String
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage).font(.caption2) }
            Text(text).font(.caption)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Space.sm)
        .padding(.vertical, 2)
        .background(Color.appFill, in: Capsule())
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    var color: Color = .primary
    var systemImage: String?

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Color.appHairline.opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Rows

struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).foregroundStyle(.secondary)
            Spacer(minLength: Theme.Space.lg)
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - States

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message { Text(message) }
        }
    }
}

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(message).font(.footnote)
                if let retry {
                    Button("Spróbuj ponownie", action: retry)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.md)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

// MARK: - Misc helpers

extension Color {
    /// "RRGGBB" hex from the Librus API (no leading #).
    init?(librusHex hex: String?) {
        guard let hex, hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension View {
    /// Standard screen scaffold: grouped background + comfortable content insets.
    func screenBackground() -> some View {
        background(Color.appGroupedBackground.ignoresSafeArea())
    }
}
