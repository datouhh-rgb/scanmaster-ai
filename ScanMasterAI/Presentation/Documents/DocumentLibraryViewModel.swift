import Combine
import Foundation

@MainActor
final class DocumentLibraryViewModel: ObservableObject {
    @Published private(set) var documents: [ScannedDocument] = []
    @Published private(set) var thumbnails: [UUID: Data] = [:]
    @Published var selectedIDs: Set<UUID> = []
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let library: DocumentLibraryUseCase

    init(library: DocumentLibraryUseCase) {
        self.library = library
    }

    var selectedDocuments: [ScannedDocument] {
        documents.filter { selectedIDs.contains($0.id) }
    }

    func load() {
        do {
            documents = try library.fetchDocuments()
            let pairs: [(UUID, Data)] = documents.compactMap { document in
                guard let page = document.pages.first,
                      let data = try? library.imageData(for: page) else { return nil }
                return (document.id, data)
            }
            thumbnails = Dictionary(uniqueKeysWithValues: pairs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSelection(_ document: ScannedDocument) {
        if selectedIDs.contains(document.id) {
            selectedIDs.remove(document.id)
        } else {
            selectedIDs.insert(document.id)
        }
    }

    func delete(_ document: ScannedDocument) {
        do {
            try library.delete(document: document)
            selectedIDs.remove(document.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func merge(filename: String) {
        let selected = selectedDocuments
        guard selected.count >= 2, !isBusy else { return }
        isBusy = true
        let useCase = library

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try useCase.merge(documents: selected, filename: filename)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let document):
                    self.selectedIDs.removeAll()
                    self.load()
                    self.successMessage = "已生成 \(document.filename).pdf"
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
