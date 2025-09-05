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
                        .progressViewStyle(CircularProgressViewStyle(tint: .loopedPrimary))
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isEnabled ? .loopedPrimary : .gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isEnabled ? Color.loopedPrimary : Color.gray, lineWidth: 2)
            )
        }
        .disabled(!isEnabled || isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        SecondaryButton(title: "Cancel") {
            print("Secondary button tapped")
        }
        
        SecondaryButton(title: "Disabled", isEnabled: false) {
            print("Won't be called")
        }
        
        SecondaryButton(title: "Loading", isLoading: true) {
            print("Loading button tapped")
        }
    }
    .padding()
}