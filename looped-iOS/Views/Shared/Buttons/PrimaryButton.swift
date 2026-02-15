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
        let isStyledAsEnabled = isEnabled || isLoading
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .loopedWhite))
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(.loopedCustom(.semibold, size: 16))
                    .foregroundColor(isStyledAsEnabled ? .loopedWhite : .loopedGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
	            .background(
	                RoundedRectangle(cornerRadius: 12)
	                    .fill(isStyledAsEnabled ? Color.loopedPrimary : Color.loopedMutedBackground)
	            )
	        }
	        .disabled(!isEnabled || isLoading)
	    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue") { }
        
        PrimaryButton(title: "Disabled", isEnabled: false) { }
        
        PrimaryButton(title: "Loading", isLoading: true) { }
    }
    .padding()
}
