import CoreGraphics
import Foundation
import Testing
@testable import looped_iOS

struct PostedMediaLayoutMetricsTests {
    @Test
    func singleAspectRatio_usesAttachmentDimensionsWhenValid() {
        let attachment = MediaAttachment(
            type: .image,
            url: "https://example.com/photo.jpg",
            width: 1080,
            height: 1350
        )

        let ratio = PostedMediaLayoutMetrics.singleAspectRatio(for: attachment)

        #expect(approximatelyEqual(ratio, 0.8))
    }

    @Test
    func singleAspectRatio_fallsBackWhenDimensionsAreMissingOrInvalid() {
        let missingDimensions = MediaAttachment(
            type: .image,
            url: "https://example.com/photo-missing.jpg"
        )
        let invalidDimensions = MediaAttachment(
            type: .image,
            url: "https://example.com/photo-invalid.jpg",
            width: 0,
            height: 1200
        )

        #expect(
            PostedMediaLayoutMetrics.singleAspectRatio(for: missingDimensions)
                == PostedMediaLayoutMetrics.fallbackSingleAspectRatio
        )
        #expect(
            PostedMediaLayoutMetrics.singleAspectRatio(for: invalidDimensions)
                == PostedMediaLayoutMetrics.fallbackSingleAspectRatio
        )
    }

    @Test
    func singleMinimumHeight_appliesFloorAndCap() {
        #expect(approximatelyEqual(PostedMediaLayoutMetrics.singleMinimumHeight(maxHeight: 350), 157.5))
        #expect(approximatelyEqual(PostedMediaLayoutMetrics.singleMinimumHeight(maxHeight: 240), 120))
        #expect(approximatelyEqual(PostedMediaLayoutMetrics.singleMinimumHeight(maxHeight: 90), 90))
    }

    private func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
