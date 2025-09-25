import SwiftUI

struct TailCornerShape: Shape {
    let isFromCurrentUser: Bool
    let showTail: Bool
    let cornerRadius: CGFloat

    init(isFromCurrentUser: Bool, showTail: Bool = true, cornerRadius: CGFloat = 18) {
        self.isFromCurrentUser = isFromCurrentUser
        self.showTail = showTail
        self.cornerRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if showTail {
            // Determine which corner should be square (no radius)
            let topLeft = cornerRadius
            let topRight = cornerRadius
            let bottomLeft = isFromCurrentUser ? cornerRadius : 0  // Square corner for received messages
            let bottomRight = isFromCurrentUser ? 0 : cornerRadius  // Square corner for sent messages

            // Create path with selective corner rounding
            path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))

            // Top edge
            path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))

            // Top-right corner
            if topRight > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: rect.minY + topRight),
                    control: CGPoint(x: rect.maxX, y: rect.minY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            }

            // Right edge
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))

            // Bottom-right corner
            if bottomRight > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }

            // Bottom edge
            path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))

            // Bottom-left corner
            if bottomLeft > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            }

            // Left edge
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))

            // Top-left corner
            if topLeft > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX + topLeft, y: rect.minY),
                    control: CGPoint(x: rect.minX, y: rect.minY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            }
        } else {
            // No tail - just a regular rounded rectangle
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }

        return path
    }
}

#Preview("Simple Tail Corners") {
    VStack(spacing: 20) {
        // Sent message with tail corner
        Text("Good morning!")
            .font(.body)
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(TailCornerShape(isFromCurrentUser: true, showTail: true))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .frame(maxWidth: .infinity, alignment: .trailing)

        // Received message with tail corner
        Text("Japan looks amazing!")
            .font(.body)
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.7, green: 0.9, blue: 0.9))
            .clipShape(TailCornerShape(isFromCurrentUser: false, showTail: true))
            .frame(maxWidth: .infinity, alignment: .leading)

        // Messages without tail
        Text("Normal message")
            .font(.body)
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(TailCornerShape(isFromCurrentUser: true, showTail: false))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}