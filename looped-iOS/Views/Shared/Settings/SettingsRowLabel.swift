import SwiftUI

enum IconSource {
    case system(String)
    case asset(String)
}

struct SettingsIconView: View {
    let icon: IconSource
    var tint: Color = .loopedTextSecondary
    var size: CGFloat = 20
    var fontSize: CGFloat = 16
    var rendersAsTemplate: Bool = true

    var body: some View {
        iconView
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.loopedCustom(.medium, size: fontSize))
                .foregroundColor(tint)
                .frame(width: size, height: size)
        case .asset(let name):
            if rendersAsTemplate {
                Image(name)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(tint)
                    .frame(width: size, height: size)
            } else {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            }
        }
    }
}

struct SettingsRowLabel: View {
    let icon: IconSource
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconView(icon: icon)
            labelText
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var labelText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
            subtitleText
        }
    }

    private var subtitleText: AnyView {
        guard let subtitle else {
            return AnyView(EmptyView())
        }
        return AnyView(
            Text(subtitle)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        )
    }
}

