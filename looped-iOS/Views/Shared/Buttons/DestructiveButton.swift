import SwiftUI

struct DestructiveButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    let isLoading: Bool
    let requiresConfirmation: Bool
    
    @State private var showingAlert = false
    
    init(
        title: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        requiresConfirmation: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.requiresConfirmation = requiresConfirmation
        self.action = action
    }
    
    var body: some View {
        Button(action: handleTap) {
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
        .alert("Are you sure?", isPresented: $showingAlert) {
            Button("Cancel", role: .cancel) { }
            Button(title, role: .destructive, action: action)
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func handleTap() {
        if requiresConfirmation {
            showingAlert = true
        } else {
            action()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DestructiveButton(title: "Delete Account") {
            print("Destructive action confirmed")
        }
        
        DestructiveButton(
            title: "Delete (No Confirmation)",
            requiresConfirmation: false
        ) {
            print("Immediate destructive action")
        }
        
        DestructiveButton(title: "Disabled", isEnabled: false) {
            print("Won't be called")
        }
    }
    .padding()
}
