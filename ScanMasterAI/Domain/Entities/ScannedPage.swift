import Foundation

struct ScannedPage: Identifiable, Codable, Hashable {
    let id: UUID
    let documentID: UUID
    var originalImagePath: String
    var processedImagePath: String
    var order: Int
    var rotation: QuarterTurn
    var filter: ScanFilter

    init(
        id: UUID = UUID(),
        documentID: UUID,
        originalImagePath: String,
        processedImagePath: String,
        order: Int,
        rotation: QuarterTurn = .zero,
        filter: ScanFilter = .enhanced
    ) {
        self.id = id
        self.documentID = documentID
        self.originalImagePath = originalImagePath
        self.processedImagePath = processedImagePath
        self.order = order
        self.rotation = rotation
        self.filter = filter
    }
}
