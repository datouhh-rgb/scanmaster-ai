import Foundation

enum ScanSaveError: LocalizedError {
    case noPages
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .noPages: return "至少需要一页扫描内容。"
        case .invalidImage: return "扫描图片无法处理，请重新拍摄。"
        }
    }
}

struct SaveScannedDocumentUseCase {
    let repository: DocumentRepository
    let fileManager: DocumentFileManaging
    let imageEnhancer: ImageEnhancing
    let pdfGenerator: PDFGenerating

    func execute(
        filename: String,
        pages: [CapturedPage],
        type: DocumentType = .document,
        compression: PDFCompression = .balanced
    ) throws -> ScannedDocument {
        guard !pages.isEmpty else { throw ScanSaveError.noPages }

        let documentID = UUID()
        let normalizedName = DocumentNamePolicy.normalized(filename)
        var storedPages: [ScannedPage] = []
        var processedPages: [Data] = []

        do {
            for (index, capture) in pages.enumerated() {
                let pageID = capture.id
                let originalPath = try fileManager.saveImage(
                    capture.imageData,
                    documentID: documentID,
                    pageID: pageID,
                    variant: .original
                )
                let processed = try autoreleasepool {
                    try imageEnhancer.process(
                        capture.imageData,
                        filter: capture.filter,
                        rotation: capture.rotation,
                        compression: compression
                    )
                }
                guard !processed.isEmpty else { throw ScanSaveError.invalidImage }
                let processedPath = try fileManager.saveImage(
                    processed,
                    documentID: documentID,
                    pageID: pageID,
                    variant: .processed
                )
                processedPages.append(processed)
                storedPages.append(
                    ScannedPage(
                        id: pageID,
                        documentID: documentID,
                        originalImagePath: originalPath,
                        processedImagePath: processedPath,
                        order: index,
                        rotation: capture.rotation,
                        filter: capture.filter
                    )
                )
            }

            let pdfURL = try fileManager.pdfURL(
                documentID: documentID,
                filename: normalizedName
            )
            try pdfGenerator.generatePDF(
                from: processedPages,
                at: pdfURL,
                compression: compression
            )

            let document = ScannedDocument(
                id: documentID,
                filename: normalizedName,
                type: type,
                pages: storedPages,
                pdfPath: fileManager.relativePath(for: pdfURL)
            )
            try repository.save(document)
            return document
        } catch {
            try? fileManager.removeFiles(documentID: documentID)
            throw error
        }
    }
}
