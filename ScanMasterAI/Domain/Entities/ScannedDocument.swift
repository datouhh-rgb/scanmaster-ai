import Foundation

struct ScannedDocument: Identifiable, Codable, Hashable {
    let id: UUID
    var filename: String
    var type: DocumentType
    let createdAt: Date
    var updatedAt: Date
    var pages: [ScannedPage]
    var pdfPath: String?
    var ocrText: String
    var tags: [String]

    init(
        id: UUID = UUID(),
        filename: String,
        type: DocumentType = .document,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        pages: [ScannedPage] = [],
        pdfPath: String? = nil,
        ocrText: String = "",
        tags: [String] = []
    ) {
        self.id = id
        self.filename = filename
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pages = pages.sorted { $0.order < $1.order }
        self.pdfPath = pdfPath
        self.ocrText = ocrText
        self.tags = tags
    }
}
