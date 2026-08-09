import UIKit

enum PDFGenerationError: LocalizedError {
    case noPages
    case invalidPage

    var errorDescription: String? {
        switch self {
        case .noPages: return "PDF 至少需要一页。"
        case .invalidPage: return "PDF 中有无法读取的页面。"
        }
    }
}

final class PDFGenerator: PDFGenerating {
    private let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
    private let margin: CGFloat = 24

    func generatePDF(
        from pageData: [Data],
        at outputURL: URL,
        compression: PDFCompression
    ) throws {
        guard !pageData.isEmpty else { throw PDFGenerationError.noPages }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "ScanMaster AI",
            kCGPDFContextTitle as String: "Scanned Document"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
        let temporaryURL = outputURL
            .deletingLastPathComponent()
            .appendingPathComponent(".scanmaster-\(UUID().uuidString).pdf")
        var renderingError: PDFGenerationError?

        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try renderer.writePDF(to: temporaryURL) { context in
            for data in pageData {
                guard renderingError == nil else { break }
                autoreleasepool {
                    guard let image = UIImage(data: data) else {
                        renderingError = .invalidPage
                        return
                    }
                    context.beginPage()
                    UIColor.white.setFill()
                    context.fill(pageBounds)
                    image.draw(in: aspectFitRect(for: image.size))
                }
            }
        }

        if let renderingError {
            throw renderingError
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            _ = try fileManager.replaceItemAt(outputURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: outputURL)
        }
    }

    private func aspectFitRect(for imageSize: CGSize) -> CGRect {
        let available = pageBounds.insetBy(dx: margin, dy: margin)
        let scale = min(
            available.width / imageSize.width,
            available.height / imageSize.height
        )
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: available.midX - size.width / 2,
            y: available.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
