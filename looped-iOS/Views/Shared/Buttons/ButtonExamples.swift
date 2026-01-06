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
                    
                    PrimaryButton(title: "Sign In") { }
                    
                    SecondaryButton(title: "Cancel") { }
                    
                    DestructiveButton(title: "Delete Account") { }
                    
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
                    ) { }
                    
                    StyledButton(
                        title: "Secondary Style",
                        style: SecondaryButtonStyle()
                    ) { }
                    
                    StyledButton(
                        title: "Destructive Style",
                        style: DestructiveButtonStyle()
                    ) { }
                }
                
                Divider()
                
                // MARK: - Button States
                VStack(alignment: .leading, spacing: 16) {
                    Text("Button States")
                        .font(.headline)
                    
                    PrimaryButton(title: "Enabled", isEnabled: true) { }
                    
                    PrimaryButton(title: "Disabled", isEnabled: false) { }
                    
                    PrimaryButton(title: "Loading", isLoading: true) { }
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
