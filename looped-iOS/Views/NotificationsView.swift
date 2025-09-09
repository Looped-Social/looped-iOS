import SwiftUI

struct NotificationsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Notifications")
                    .font(.largeTitle)
                    .foregroundColor(.loopedTextPrimary)
                
                Spacer()
            }
            .background(Color.loopedBackground)
            .navigationTitle("Notifications")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    NotificationsView()
}