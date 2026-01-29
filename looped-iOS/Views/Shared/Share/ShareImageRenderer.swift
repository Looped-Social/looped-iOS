import SwiftUI
import UIKit

@MainActor
enum ShareImageRenderer {
    static func render<Content: View>(
        _ view: Content,
        size: CGSize,
        scale: CGFloat = 3
    ) -> UIImage? {
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
            renderer.scale = scale
            return renderer.uiImage
        }

        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
