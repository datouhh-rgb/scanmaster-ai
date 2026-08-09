import Foundation

protocol ImageEnhancing {
    func process(
        _ imageData: Data,
        filter: ScanFilter,
        rotation: QuarterTurn,
        compression: PDFCompression
    ) throws -> Data
}

protocol PDFGenerating {
    func generatePDF(
        from pageData: [Data],
        at outputURL: URL,
        compression: PDFCompression
    ) throws
}

protocol DocumentFileManaging {
    func saveImage(
        _ data: Data,
        documentID: UUID,
        pageID: UUID,
        variant: ImageVariant
    ) throws -> String
    func loadImage(at relativePath: String) throws -> Data
    func pdfURL(documentID: UUID, filename: String) throws -> URL
    func renamePDF(at relativePath: String, filename: String) throws -> String
    func absoluteURL(for relativePath: String) -> URL
    func relativePath(for absoluteURL: URL) -> String
    func removeFile(at relativePath: String) throws
    func removeFiles(documentID: UUID) throws
}

enum ImageVariant: String {
    case original
    case processed
}
