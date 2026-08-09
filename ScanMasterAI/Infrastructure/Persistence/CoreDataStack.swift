import CoreData
import Foundation

final class CoreDataStack {
    let container: NSPersistentContainer

    init(inMemory: Bool = false) throws {
        container = NSPersistentContainer(
            name: "ScanMasterAI",
            managedObjectModel: Self.makeModel()
        )

        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            description.type = NSSQLiteStoreType
            description.url = try Self.storeURL()
        }
        description.shouldAddStoreAsynchronously = false
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        container.persistentStoreDescriptions = [description]

        var loadingError: Error?
        container.loadPersistentStores { _, error in loadingError = error }
        if let loadingError { throw loadingError }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func storeURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("ScanMasterAI", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("ScanMasterAI.sqlite")
    }
}

private extension CoreDataStack {
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let document = NSEntityDescription()
        document.name = "CDDocument"
        document.managedObjectClassName = NSStringFromClass(CDDocument.self)

        let page = NSEntityDescription()
        page.name = "CDPage"
        page.managedObjectClassName = NSStringFromClass(CDPage.self)

        document.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("filename", .stringAttributeType, optional: false),
            attribute("typeRaw", .stringAttributeType, optional: false),
            attribute("createdAt", .dateAttributeType, optional: false),
            attribute("updatedAt", .dateAttributeType, optional: false),
            attribute("pdfPath", .stringAttributeType, optional: true),
            attribute("ocrText", .stringAttributeType, optional: false),
            attribute("tagsData", .binaryDataAttributeType, optional: false)
        ]
        page.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("documentID", .UUIDAttributeType, optional: false),
            attribute("originalImagePath", .stringAttributeType, optional: false),
            attribute("processedImagePath", .stringAttributeType, optional: false),
            attribute("order", .integer32AttributeType, optional: false),
            attribute("rotationRaw", .integer16AttributeType, optional: false),
            attribute("filterRaw", .stringAttributeType, optional: false)
        ]

        let pagesRelationship = NSRelationshipDescription()
        pagesRelationship.name = "pages"
        pagesRelationship.destinationEntity = page
        pagesRelationship.minCount = 0
        pagesRelationship.maxCount = 0
        pagesRelationship.deleteRule = .cascadeDeleteRule
        pagesRelationship.isOptional = true
        pagesRelationship.isOrdered = false

        let documentRelationship = NSRelationshipDescription()
        documentRelationship.name = "document"
        documentRelationship.destinationEntity = document
        documentRelationship.minCount = 0
        documentRelationship.maxCount = 1
        documentRelationship.deleteRule = .nullifyDeleteRule
        documentRelationship.isOptional = true

        pagesRelationship.inverseRelationship = documentRelationship
        documentRelationship.inverseRelationship = pagesRelationship
        document.properties.append(pagesRelationship)
        page.properties.append(documentRelationship)
        model.entities = [document, page]
        return model
    }

    static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}
