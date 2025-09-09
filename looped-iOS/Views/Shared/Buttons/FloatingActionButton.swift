import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 33, weight: .regular))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.loopedPrimary)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.loopedBackground
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingActionButton {
                    // Action placeholder
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100)
            }
        }
    }
}
