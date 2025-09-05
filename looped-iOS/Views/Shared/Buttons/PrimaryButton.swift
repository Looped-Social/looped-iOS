import SwiftUI

struct PrimaryButton: View {
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
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? Color.loopedPrimary : Color.gray)
            )
        }
        .disabled(!isEnabled || isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue") {
            print("Primary button tapped")
        }
        
        PrimaryButton(title: "Disabled", isEnabled: false) {
            print("Won't be called")
        }
        
        PrimaryButton(title: "Loading", isLoading: true) {
            print("Loading button tapped")
        }
    }
    .padding()
}