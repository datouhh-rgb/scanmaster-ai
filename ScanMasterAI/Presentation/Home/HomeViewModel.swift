import Combine
import Foundation
import UIKit

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var recentDocuments: [ScannedDocument] = []
    @Published private(set) var thumbnails: [UUID: Data] = [:]
    @Published var errorMessage: String?

    private let library: DocumentLibraryUseCase

    init(library: DocumentLibraryUseCase) {
        self.library = library
    }

    func load() {
        do {
            let documents = try library.fetchDocuments()
            recentDocuments = Array(documents.prefix(3))
            let pairs: [(UUID, Data)] = recentDocuments.compactMap { document in
                guard let page = document.pages.first,
                      let data = try? library.imageData(for: page) else { return nil }
                return (document.id, data)
            }
            thumbnails = Dictionary(uniqueKeysWithValues: pairs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
