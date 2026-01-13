import SwiftUI
import UIKit

struct GroupedBubbleShape: Shape {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomLeft: CGFloat
    let bottomRight: CGFloat

    init(
        topLeft: CGFloat,
        topRight: CGFloat,
        bottomLeft: CGFloat,
        bottomRight: CGFloat
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    func path(in rect: CGRect) -> Path {
        let topLeft = min(topLeft, min(rect.width, rect.height) / 2)
        let topRight = min(topRight, min(rect.width, rect.height) / 2)
        let bottomLeft = min(bottomLeft, min(rect.width, rect.height) / 2)
        let bottomRight = min(bottomRight, min(rect.width, rect.height) / 2)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(
                withCenter: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                radius: topRight,
                startAngle: CGFloat(-Double.pi / 2),
                endAngle: 0,
                clockwise: true
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(
                withCenter: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                radius: bottomRight,
                startAngle: 0,
                endAngle: CGFloat(Double.pi / 2),
                clockwise: true
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(
                withCenter: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                radius: bottomLeft,
                startAngle: CGFloat(Double.pi / 2),
                endAngle: CGFloat(Double.pi),
                clockwise: true
            )
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(
                withCenter: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                radius: topLeft,
                startAngle: CGFloat(Double.pi),
                endAngle: CGFloat(3 * Double.pi / 2),
                clockwise: true
            )
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        path.close()

        return Path(path.cgPath)
    }
}

struct ChatBubbleShape: Shape {
    let isFromCurrentUser: Bool
    let isGroupStart: Bool
    let isGroupEnd: Bool

    private let outerRadius: CGFloat = 18
    private let innerRadius: CGFloat = 8
    private let tailCornerRadius: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        if isFromCurrentUser {
            let topRight = isGroupStart ? outerRadius : innerRadius
            let bottomRight = isGroupEnd ? tailCornerRadius : innerRadius
            let bottomLeft = isGroupEnd ? outerRadius : outerRadius
            let topLeft = outerRadius
            return GroupedBubbleShape(
                topLeft: topLeft,
                topRight: topRight,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight
            ).path(in: rect)
        } else {
            let topLeft = isGroupStart ? outerRadius : innerRadius
            let bottomLeft = isGroupEnd ? tailCornerRadius : innerRadius
            let bottomRight = outerRadius
            let topRight = outerRadius
            return GroupedBubbleShape(
                topLeft: topLeft,
                topRight: topRight,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight
            ).path(in: rect)
        }
    }
}

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
            .font(.loopedBodyScaled)
            .foregroundColor(.loopedBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.loopedWhite)
            .clipShape(TailCornerShape(isFromCurrentUser: true, showTail: true))
            .shadow(color: .loopedBlack.opacity(0.1), radius: 2, x: 0, y: 1)
            .frame(maxWidth: .infinity, alignment: .trailing)

        // Received message with tail corner
        Text("Japan looks amazing!")
            .font(.loopedBodyScaled)
            .foregroundColor(.loopedBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.loopedMessageColor)
            .clipShape(TailCornerShape(isFromCurrentUser: false, showTail: true))
            .frame(maxWidth: .infinity, alignment: .leading)

        // Messages without tail
        Text("Normal message")
            .font(.loopedBodyScaled)
            .foregroundColor(.loopedBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.loopedWhite)
            .clipShape(TailCornerShape(isFromCurrentUser: true, showTail: false))
            .shadow(color: .loopedBlack.opacity(0.1), radius: 2, x: 0, y: 1)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding()
    .background(Color.loopedMutedBackground)
}
