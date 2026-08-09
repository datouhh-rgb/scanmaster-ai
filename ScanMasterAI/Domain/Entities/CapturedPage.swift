import Foundation

struct CapturedPage {
    let id: UUID
    let imageData: Data
    var filter: ScanFilter
    var rotation: QuarterTurn

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
