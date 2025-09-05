import SwiftUI

// MARK: - Usage Examples
struct ButtonExamples: View {
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // MARK: - Individual Button Components
                VStack(alignment: .leading, spacing: 16) {
                    Text("Individual Button Components")
                        .font(.headline)
                    
                    PrimaryButton(title: "Sign In") {
                        print("Sign in tapped")
                    }
                    
                    SecondaryButton(title: "Cancel") {
                        print("Cancel tapped")
                    }
                    
                    DestructiveButton(title: "Delete Account") {
                        print("Delete account confirmed")
                    }
                    
                    PrimaryButton(
                        title: "Loading Example",
                        isLoading: isLoading
                    ) {
                        toggleLoading()
                    }
                }
                
                Divider()
                
                // MARK: - Styled Button Examples
                VStack(alignment: .leading, spacing: 16) {
                    Text("Generic Styled Buttons")
                        .font(.headline)
                    
                    StyledButton(
                        title: "Primary Style",
                        style: PrimaryButtonStyle()
                    ) {
                        print("Styled primary tapped")
                    }
                    
                    StyledButton(
                        title: "Secondary Style",
                        style: SecondaryButtonStyle()
                    ) {
                        print("Styled secondary tapped")
                    }
                    
                    StyledButton(
                        title: "Destructive Style",
                        style: DestructiveButtonStyle()
                    ) {
                        print("Styled destructive tapped")
                    }
                }
                
                Divider()
                
                // MARK: - Button States
                VStack(alignment: .leading, spacing: 16) {
                    Text("Button States")
                        .font(.headline)
                    
                    PrimaryButton(title: "Enabled", isEnabled: true) {
                        print("Enabled button tapped")
                    }
                    
                    PrimaryButton(title: "Disabled", isEnabled: false) {
                        print("This won't be called")
                    }
                    
                    PrimaryButton(title: "Loading", isLoading: true) {
                        print("Loading button tapped")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Button Examples")
    }
    
    private func toggleLoading() {
        isLoading.toggle()
        
        if isLoading {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationView {
        ButtonExamples()
    }
}