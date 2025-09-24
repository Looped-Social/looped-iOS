import SwiftUI

enum FloatingActionButtonType {
    case addPost
    case sendMessage
}

struct FloatingActionButton: View {
    let type: FloatingActionButtonType
    let action: () -> Void

    init(type: FloatingActionButtonType = .addPost, action: @escaping () -> Void) {
        self.type = type
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                switch type {
                case .addPost:
                    Image(systemName: "plus")
                        .font(.system(size: 33, weight: .regular))
                        .foregroundColor(.white)
                case .sendMessage:
                    Image("send-icon")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.loopedBackground)
                }
            }
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
