import Foundation
import UIKit

struct ScanPageDraft: Identifiable {
    let id: UUID
    let originalData: Data
    var previewData: Data
    var filter: ScanFilter
    var rotation: QuarterTurn

    init?(
        id: UUID = UUID(),
        data: Data,
        filter: ScanFilter = .enhanced,
        rotation: QuarterTurn = .zero
    ) {
        guard UIImage(data: data) != nil else { return nil }
        self.id = id
        originalData = data
        previewData = data
        self.filter = filter
        self.rotation = rotation
    }

    init?(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.96) else { return nil }
        self.init(data: data)
    }

    init?(sessionPage: ScanSessionPage) {
        self.init(
            id: sessionPage.id,
            data: sessionPage.imageData,
            filter: sessionPage.filter,
            rotation: sessionPage.rotation
        )
    }
}
