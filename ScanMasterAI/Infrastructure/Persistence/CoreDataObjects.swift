import CoreData
import Foundation

@objc(CDDocument)
final class CDDocument: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var filename: String
    @NSManaged var typeRaw: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var pdfPath: String?
    @NSManaged var ocrText: String
    @NSManaged var tagsData: Data
    @NSManaged var pages: Set<CDPage>
}

@objc(CDPage)
final class CDPage: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var documentID: UUID
    @NSManaged var originalImagePath: String
    @NSManaged var processedImagePath: String
    @NSManaged var order: Int32
    @NSManaged var rotationRaw: Int16
    @NSManaged var filterRaw: String
    @NSManaged var document: CDDocument?
}
