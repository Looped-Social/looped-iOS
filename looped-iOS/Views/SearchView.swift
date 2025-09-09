import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Search")
                    .font(.largeTitle)
                    .foregroundColor(.loopedTextPrimary)
                
                Spacer()
            }
            .background(Color.loopedBackground)
            .navigationTitle("Search")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    SearchView()
}