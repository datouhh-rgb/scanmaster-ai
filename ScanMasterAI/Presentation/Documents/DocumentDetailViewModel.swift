import Combine
import Foundation

@MainActor
final class DocumentDetailViewModel: ObservableObject {
    @Published private(set) var document: ScannedDocument
    @Published private(set) var pdfURL: URL?
    @Published private(set) var isBusy = false
    @Published private(set) var didDelete = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let library: DocumentLibraryUseCase

    init(document: ScannedDocument, library: DocumentLibraryUseCase) {
        self.document = document
        self.library = library
        pdfURL = library.pdfURL(for: document)
    }

    func rename(to newName: String) {
        do {
            document = try library.rename(document: document, to: newName)
            pdfURL = library.pdfURL(for: document)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func makeEditSession() throws -> ScanSession {
        let pages = try document.pages.sorted { $0.order < $1.order }.map { page in
            ScanSessionPage(
                id: page.id,
                imageData: try library.originalImageData(for: page),
                filter: page.filter,
                rotation: page.rotation
            )
        }
        return ScanSession(document: document, pages: pages)
    }

    func acceptUpdatedDocument(_ updated: ScannedDocument) {
        document = updated
        pdfURL = library.pdfURL(for: updated)
        successMessage = "页面调整已保存。"
    }

    func split() {
        guard !isBusy else { return }
        isBusy = true
        let source = document
        let useCase = library

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try useCase.split(document: source) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let documents):
                    self.successMessage = "已拆分为 \(documents.count) 个单页 PDF。"
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func delete() {
        do {
            try library.delete(document: document)
            didDelete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
