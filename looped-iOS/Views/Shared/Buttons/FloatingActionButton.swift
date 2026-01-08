import SwiftUI

enum FloatingActionButtonType {
    case addPost
    case sendMessage
}

struct FloatingActionButton: View {
    let type: FloatingActionButtonType
    let action: () -> Void
    @AppStorage("anonymousMode") private var isAnonymousMode = false

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
                        .font(.loopedCustom(.regular, size: 33))
                        .foregroundColor(.loopedWhite)
                case .sendMessage:
                    Image("send-icon-fab")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.loopedWhite)
                }
            }
            .frame(width: 56, height: 56)
            .background(backgroundColor)
            .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        switch type {
        case .addPost:
            return Color.loopedAccent(isAnonymousMode: isAnonymousMode)
        case .sendMessage:
            return .loopedPrimary
        }
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
                Spacer()
                FloatingActionButton(
                    type: .sendMessage
                ){
                }
            }
        }
    }
}
