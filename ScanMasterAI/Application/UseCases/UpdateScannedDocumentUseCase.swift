import Foundation

struct UpdateScannedDocumentUseCase {
    let repository: DocumentRepository
    let fileManager: DocumentFileManaging
    let imageEnhancer: ImageEnhancing
    let pdfGenerator: PDFGenerating

    func execute(
        document: ScannedDocument,
        filename: String,
        pages: [CapturedPage],
        compression: PDFCompression = .balanced
    ) throws -> ScannedDocument {
        guard !pages.isEmpty else { throw ScanSaveError.noPages }

        let normalizedName = DocumentNamePolicy.normalized(filename)
        var storedPages: [ScannedPage] = []
        var processedPages: [Data] = []

        for (index, capture) in pages.enumerated() {
            let originalPath = try fileManager.saveImage(
                capture.imageData,
                documentID: document.id,
                pageID: capture.id,
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
                documentID: document.id,
                pageID: capture.id,
                variant: .processed
            )
            processedPages.append(processed)
            storedPages.append(
                ScannedPage(
                    id: capture.id,
                    documentID: document.id,
                    originalImagePath: originalPath,
                    processedImagePath: processedPath,
                    order: index,
                    rotation: capture.rotation,
                    filter: capture.filter
                )
            )
        }

        let pdfURL = try fileManager.pdfURL(
            documentID: document.id,
            filename: normalizedName
        )
        try pdfGenerator.generatePDF(
            from: processedPages,
            at: pdfURL,
            compression: compression
        )

        let updated = ScannedDocument(
            id: document.id,
            filename: normalizedName,
            type: document.type,
            createdAt: document.createdAt,
            updatedAt: Date(),
            pages: storedPages,
            pdfPath: fileManager.relativePath(for: pdfURL),
            ocrText: document.ocrText,
            tags: document.tags
        )
        try repository.save(updated)
        cleanupRemovedFiles(from: document, keeping: updated)
        return updated
    }

    private func cleanupRemovedFiles(
        from original: ScannedDocument,
        keeping updated: ScannedDocument
    ) {
        let activePageIDs = Set(updated.pages.map(\.id))
        for page in original.pages where !activePageIDs.contains(page.id) {
            try? fileManager.removeFile(at: page.originalImagePath)
            try? fileManager.removeFile(at: page.processedImagePath)
        }
        if let oldPDF = original.pdfPath,
           oldPDF != updated.pdfPath {
            try? fileManager.removeFile(at: oldPDF)
        }
    }
}
