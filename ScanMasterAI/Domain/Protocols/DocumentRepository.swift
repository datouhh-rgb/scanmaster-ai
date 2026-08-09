import Foundation

protocol DocumentRepository {
    func fetchAll() throws -> [ScannedDocument]
    func fetch(id: UUID) throws -> ScannedDocument?
    func save(_ document: ScannedDocument) throws
    func delete(id: UUID) throws
}
