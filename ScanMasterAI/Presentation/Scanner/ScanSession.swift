import Foundation

struct ScanSessionPage {
    let id: UUID
    let imageData: Data
    let filter: ScanFilter
    let rotation: QuarterTurn

    init(
        id: UUID = UUID(),
        imageData: Data,
        filter: ScanFilter = .enhanced,
        rotation: QuarterTurn = .zero
    ) {
        self.id = id
        self.imageData = imageData
        self.filter = filter
        self.rotation = rotation
    }
}

struct ScanSession: Identifiable {
    let id = UUID()
    let sourceDocument: ScannedDocument?
    let pages: [ScanSessionPage]

    init(pageData: [Data]) {
        sourceDocument = nil
        pages = pageData.map { ScanSessionPage(imageData: $0) }
    }

    init(document: ScannedDocument, pages: [ScanSessionPage]) {
        sourceDocument = document
        self.pages = pages
    }
}
