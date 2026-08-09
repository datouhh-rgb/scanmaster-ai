import Foundation

struct DocumentLibraryUseCase {
    let repository: DocumentRepository
    let fileManager: DocumentFileManaging
    let saveScan: SaveScannedDocumentUseCase

    func fetchDocuments() throws -> [ScannedDocument] {
        try repository.fetchAll().sorted { $0.updatedAt > $1.updatedAt }
    }

    func delete(document: ScannedDocument) throws {
        try repository.delete(id: document.id)
        try? fileManager.removeFiles(documentID: document.id)
    }

    func rename(document: ScannedDocument, to newName: String) throws -> ScannedDocument {
        var updated = document
        let normalizedName = DocumentNamePolicy.normalized(newName)
        let originalPDFPath = updated.pdfPath
        var renamedPDFPath: String?

        if let originalPDFPath {
            renamedPDFPath = try fileManager.renamePDF(
                at: originalPDFPath,
                filename: normalizedName
            )
            updated.pdfPath = renamedPDFPath
        }
        updated.filename = normalizedName
        updated.updatedAt = Date()
        do {
            try repository.save(updated)
            return updated
        } catch {
            if let renamedPDFPath {
                _ = try? fileManager.renamePDF(
                    at: renamedPDFPath,
                    filename: document.filename
                )
            }
            throw error
        }
    }

    func merge(
        documents: [ScannedDocument],
        filename: String,
        compression: PDFCompression = .balanced
    ) throws -> ScannedDocument {
        let captures = try documents
            .sorted { $0.createdAt < $1.createdAt }
            .flatMap { document in
                try document.pages.sorted { $0.order < $1.order }.map { page in
                    CapturedPage(
                        imageData: try fileManager.loadImage(at: page.processedImagePath),
                        filter: .original
                    )
                }
            }
        return try saveScan.execute(
            filename: filename,
            pages: captures,
            compression: compression
        )
    }

    func split(
        document: ScannedDocument,
        compression: PDFCompression = .balanced
    ) throws -> [ScannedDocument] {
        try document.pages.sorted { $0.order < $1.order }.enumerated().map { index, page in
            let data = try fileManager.loadImage(at: page.processedImagePath)
            return try saveScan.execute(
                filename: "\(document.filename)-第\(index + 1)页",
                pages: [CapturedPage(imageData: data, filter: .original)],
                type: document.type,
                compression: compression
            )
        }
    }

    func pdfURL(for document: ScannedDocument) -> URL? {
        guard let path = document.pdfPath else { return nil }
        return fileManager.absoluteURL(for: path)
    }

    func imageData(for page: ScannedPage) throws -> Data {
        try fileManager.loadImage(at: page.processedImagePath)
    }

    func originalImageData(for page: ScannedPage) throws -> Data {
        try fileManager.loadImage(at: page.originalImagePath)
    }
}
