import SwiftUI

// MARK: - Button Style Protocol
protocol LoopedButtonStyle {
    var backgroundColor: Color { get }
    var foregroundColor: Color { get }
    var cornerRadius: CGFloat { get }
    var height: CGFloat { get }
    var borderColor: Color? { get }
    var borderWidth: CGFloat { get }
}

// MARK: - Button Style Implementations
struct PrimaryButtonStyle: LoopedButtonStyle {
    let backgroundColor: Color = .loopedPrimary
    let foregroundColor: Color = .white
    let cornerRadius: CGFloat = 12
    let height: CGFloat = 50
    let borderColor: Color? = nil
    let borderWidth: CGFloat = 0
}

struct SecondaryButtonStyle: LoopedButtonStyle {
    let backgroundColor: Color = .clear
    let foregroundColor: Color = .loopedPrimary
    let cornerRadius: CGFloat = 12
    let height: CGFloat = 50
    let borderColor: Color? = .loopedPrimary
    let borderWidth: CGFloat = 2
}

struct DestructiveButtonStyle: LoopedButtonStyle {
    let backgroundColor: Color = .loopedDestructive
    let foregroundColor: Color = .white
    let cornerRadius: CGFloat = 12
    let height: CGFloat = 50
    let borderColor: Color? = nil
    let borderWidth: CGFloat = 0
}

// MARK: - Generic Styled Button
struct StyledButton<Style: LoopedButtonStyle>: View {
    let title: String
    let style: Style
    let action: () -> Void
    let isEnabled: Bool
    let isLoading: Bool
    
    init(
        title: String,
        style: Style,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isEnabled ? style.foregroundColor : .gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: style.height)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(isEnabled ? style.backgroundColor : Color.gray.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .stroke(
                                style.borderColor ?? Color.clear,
                                lineWidth: style.borderWidth
                            )
                    )
            )
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Convenience Extensions
extension View {
    func primaryButtonStyle() -> some View {
        self.buttonStyle(PlainButtonStyle())
    }
    
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(PlainButtonStyle())
    }
}