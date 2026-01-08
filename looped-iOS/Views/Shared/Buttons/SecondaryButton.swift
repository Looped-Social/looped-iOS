import SwiftUI

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    let isLoading: Bool
    
    init(
        title: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .loopedSecondary))
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(.loopedCustom(.semibold, size: 16))
                    .foregroundColor(isEnabled ? .loopedSecondary : .loopedGray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isEnabled ? Color.loopedSecondary : Color.loopedGray, lineWidth: 2)
            )
        }
        .disabled(!isEnabled || isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        SecondaryButton(title: "Cancel") { }
        
        SecondaryButton(title: "Disabled", isEnabled: false) { }
        
        SecondaryButton(title: "Loading", isLoading: true) { }
    }
    .padding()
}
