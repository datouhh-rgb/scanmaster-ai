import CoreImage
import UIKit

enum ImageProcessingError: LocalizedError {
    case unreadableImage
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "无法读取扫描图片。"
        case .renderingFailed: return "图像增强失败。"
        }
    }
}

final class CoreImageEnhancer: ImageEnhancing {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func process(
        _ imageData: Data,
        filter: ScanFilter,
        rotation: QuarterTurn,
        compression: PDFCompression
    ) throws -> Data {
        guard let image = UIImage(data: imageData),
              var input = CIImage(
                image: image,
                options: [.applyOrientationProperty: true]
              ) else {
            throw ImageProcessingError.unreadableImage
        }

        input = rotate(input, by: rotation)
        let filtered = apply(filter, to: input)
        let resized = resize(filtered, maximumDimension: compression.maximumDimension)
        guard let output = context.createCGImage(resized, from: resized.extent) else {
            throw ImageProcessingError.renderingFailed
        }
        let rendered = UIImage(cgImage: output)
        guard let jpeg = rendered.jpegData(
            compressionQuality: CGFloat(compression.jpegQuality)
        ) else {
            throw ImageProcessingError.renderingFailed
        }
        return jpeg
    }

    private func apply(_ filter: ScanFilter, to image: CIImage) -> CIImage {
        switch filter {
        case .original:
            return image
        case .enhanced:
            let lifted = applying(
                "CIHighlightShadowAdjust",
                to: image,
                values: ["inputShadowAmount": 0.65, "inputHighlightAmount": 0.9]
            )
            let contrasted = applying(
                "CIColorControls",
                to: lifted,
                values: ["inputSaturation": 0.85, "inputContrast": 1.18, "inputBrightness": 0.025]
            )
            return applying("CISharpenLuminance", to: contrasted, values: ["inputSharpness": 0.55])
        case .blackAndWhite:
            let noir = applying("CIPhotoEffectNoir", to: image)
            return applying(
                "CIColorControls",
                to: noir,
                values: ["inputContrast": 1.28, "inputBrightness": 0.035]
            )
        case .grayscale:
            return applying("CIPhotoEffectMono", to: image)
        case .receipt:
            let monochrome = applying(
                "CIColorControls",
                to: image,
                values: ["inputSaturation": 0, "inputContrast": 1.72, "inputBrightness": 0.08]
            )
            let exposed = applying("CIExposureAdjust", to: monochrome, values: ["inputEV": 0.35])
            return applying("CISharpenLuminance", to: exposed, values: ["inputSharpness": 0.8])
        }
    }

    private func applying(
        _ name: String,
        to input: CIImage,
        values: [String: Any] = [:]
    ) -> CIImage {
        guard let filter = CIFilter(name: name) else { return input }
        filter.setValue(input, forKey: kCIInputImageKey)
        values.forEach { filter.setValue($0.value, forKey: $0.key) }
        return filter.outputImage ?? input
    }

    private func rotate(_ image: CIImage, by rotation: QuarterTurn) -> CIImage {
        guard rotation != .zero else { return image }
        let radians = CGFloat(rotation.rawValue) * .pi / 180
        let rotated = image.transformed(by: CGAffineTransform(rotationAngle: -radians))
        return rotated.transformed(
            by: CGAffineTransform(
                translationX: -rotated.extent.origin.x,
                y: -rotated.extent.origin.y
            )
        )
    }

    private func resize(_ image: CIImage, maximumDimension: Double) -> CIImage {
        let longest = max(image.extent.width, image.extent.height)
        let maximum = CGFloat(maximumDimension)
        guard longest > maximum else { return image }
        let scale = maximum / longest
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
}
