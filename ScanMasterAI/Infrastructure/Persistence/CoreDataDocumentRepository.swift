import CoreData
import Foundation

final class CoreDataDocumentRepository: DocumentRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAll() throws -> [ScannedDocument] {
        try perform {
            let request = NSFetchRequest<CDDocument>(entityName: "CDDocument")
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).map(Self.map)
        }
    }

    func fetch(id: UUID) throws -> ScannedDocument? {
        try perform {
            try find(id: id).map(Self.map)
        }
    }

    func save(_ document: ScannedDocument) throws {
        try perform {
            let object = try find(id: document.id) ?? CDDocument(
                entity: entity(named: "CDDocument"),
                insertInto: context
            )
            object.id = document.id
            object.filename = document.filename
            object.typeRaw = document.type.rawValue
            object.createdAt = document.createdAt
            object.updatedAt = document.updatedAt
            object.pdfPath = document.pdfPath
            object.ocrText = document.ocrText
            object.tagsData = try JSONEncoder().encode(document.tags)

            object.pages.forEach(context.delete)
            object.pages = Set(document.pages.map { page in
                let stored = CDPage(
                    entity: entity(named: "CDPage"),
                    insertInto: context
                )
                stored.id = page.id
                stored.documentID = page.documentID
                stored.originalImagePath = page.originalImagePath
                stored.processedImagePath = page.processedImagePath
                stored.order = Int32(page.order)
                stored.rotationRaw = Int16(page.rotation.rawValue)
                stored.filterRaw = page.filter.rawValue
                stored.document = object
                return stored
            })
            if context.hasChanges { try context.save() }
        }
    }

    func delete(id: UUID) throws {
        try perform {
            if let object = try find(id: id) {
                context.delete(object)
                try context.save()
            }
        }
    }

    private func find(id: UUID) throws -> CDDocument? {
        let request = NSFetchRequest<CDDocument>(entityName: "CDDocument")
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func entity(named name: String) -> NSEntityDescription {
        guard let entity = NSEntityDescription.entity(forEntityName: name, in: context) else {
            preconditionFailure("Core Data entity \(name) is missing")
        }
        return entity
    }

    private func perform<T>(_ operation: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        context.performAndWait { result = Result { try operation() } }
        return try result.get()
    }
}

private extension CoreDataDocumentRepository {
    static func map(_ object: CDDocument) -> ScannedDocument {
        let tags = (try? JSONDecoder().decode([String].self, from: object.tagsData)) ?? []
        let pages = object.pages.map { stored in
            ScannedPage(
                id: stored.id,
                documentID: stored.documentID,
                originalImagePath: stored.originalImagePath,
                processedImagePath: stored.processedImagePath,
                order: Int(stored.order),
                rotation: QuarterTurn(rawValue: Int(stored.rotationRaw)) ?? .zero,
                filter: ScanFilter(rawValue: stored.filterRaw) ?? .original
            )
        }
        return ScannedDocument(
            id: object.id,
            filename: object.filename,
            type: DocumentType(rawValue: object.typeRaw) ?? .document,
            createdAt: object.createdAt,
            updatedAt: object.updatedAt,
            pages: pages,
            pdfPath: object.pdfPath,
            ocrText: object.ocrText,
            tags: tags
        )
    }
}
