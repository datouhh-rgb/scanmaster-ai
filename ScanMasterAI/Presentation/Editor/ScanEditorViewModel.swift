import Combine
import Foundation
import UIKit

@MainActor
final class ScanEditorViewModel: ObservableObject {
    @Published private(set) var pages: [ScanPageDraft]
    @Published var selectedPageID: UUID?
    @Published var filename: String
    @Published var compression: PDFCompression = .balanced
    @Published private(set) var processingPageIDs: Set<UUID> = []
    @Published private(set) var isSaving = false
    @Published private(set) var savedDocument: ScannedDocument?
    @Published var errorMessage: String?

    private let imageEnhancer: ImageEnhancing
    private let saveScan: SaveScannedDocumentUseCase
    private let updateScan: UpdateScannedDocumentUseCase
    private let sourceDocument: ScannedDocument?
    private var previewGeneration: [UUID: Int] = [:]

    init(
        session: ScanSession,
        imageEnhancer: ImageEnhancing,
        saveScan: SaveScannedDocumentUseCase,
        updateScan: UpdateScannedDocumentUseCase
    ) {
        let initialPages = session.pages.compactMap(ScanPageDraft.init(sessionPage:))
        pages = initialPages
        selectedPageID = initialPages.first?.id
        filename = session.sourceDocument?.filename ?? DocumentNamePolicy.defaultName()
        self.imageEnhancer = imageEnhancer
        self.saveScan = saveScan
        self.updateScan = updateScan
        sourceDocument = session.sourceDocument

        for page in pages {
            refreshPreview(pageID: page.id)
        }
    }

    var selectedPage: ScanPageDraft? {
        guard let selectedPageID else { return nil }
        return pages.first { $0.id == selectedPageID }
    }

    var isEditingExistingDocument: Bool {
        sourceDocument != nil
    }

    var selectedPageNumber: Int {
        guard let selectedPageID,
              let index = pages.firstIndex(where: { $0.id == selectedPageID }) else { return 0 }
        return index + 1
    }

    func add(images: [UIImage]) {
        let additions = images.compactMap(ScanPageDraft.init(image:))
        guard !additions.isEmpty else {
            errorMessage = "新页面读取失败，请重新拍摄。"
            return
        }
        pages.append(contentsOf: additions)
        selectedPageID = additions.first?.id
        additions.forEach { refreshPreview(pageID: $0.id) }
    }

    func replaceSelected(with images: [UIImage]) {
        guard let first = images.first,
              let replacement = ScanPageDraft(image: first),
              let selectedPageID,
              let index = pages.firstIndex(where: { $0.id == selectedPageID }) else {
            errorMessage = "重拍页面读取失败，请重试。"
            return
        }
        processingPageIDs.remove(selectedPageID)
        previewGeneration.removeValue(forKey: selectedPageID)
        pages[index] = replacement
        self.selectedPageID = replacement.id
        refreshPreview(pageID: replacement.id)

        if images.count > 1 {
            add(images: Array(images.dropFirst()))
        }
    }

    func select(filter: ScanFilter) {
        guard let id = selectedPageID,
              let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages[index].filter = filter
        refreshPreview(pageID: id)
    }

    func rotateSelectedPage() {
        guard let id = selectedPageID,
              let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages[index].rotation = pages[index].rotation.rotatedClockwise()
        refreshPreview(pageID: id)
    }

    func deleteSelectedPage() {
        guard pages.count > 1 else {
            errorMessage = "文档至少需要保留一页。"
            return
        }
        guard let id = selectedPageID,
              let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages.remove(at: index)
        let nextIndex = min(index, pages.count - 1)
        selectedPageID = pages[nextIndex].id
        processingPageIDs.remove(id)
        previewGeneration.removeValue(forKey: id)
    }

    func delete(at offsets: IndexSet) {
        guard pages.count - offsets.count >= 1 else {
            errorMessage = "文档至少需要保留一页。"
            return
        }
        let deletedIDs = Set(offsets.map { pages[$0].id })
        for index in offsets.sorted(by: >) { pages.remove(at: index) }
        processingPageIDs.subtract(deletedIDs)
        deletedIDs.forEach { previewGeneration.removeValue(forKey: $0) }
        if let selectedPageID, deletedIDs.contains(selectedPageID) {
            self.selectedPageID = pages.first?.id
        }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        let movingItems = fromOffsets.sorted().map { pages[$0] }
        for index in fromOffsets.sorted(by: >) { pages.remove(at: index) }
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        let destination = min(max(0, toOffset - removedBeforeDestination), pages.count)
        pages.insert(contentsOf: movingItems, at: destination)
    }

    func save() {
        guard !pages.isEmpty, !isSaving else { return }
        isSaving = true
        let name = filename
        let compression = compression
        let captures = pages.map {
            CapturedPage(
                id: $0.id,
                imageData: $0.originalData,
                filter: $0.filter,
                rotation: $0.rotation
            )
        }
        let useCase = saveScan
        let updateUseCase = updateScan
        let documentToUpdate = sourceDocument

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                if let documentToUpdate {
                    return try updateUseCase.execute(
                        document: documentToUpdate,
                        filename: name,
                        pages: captures,
                        compression: compression
                    )
                } else {
                    return try useCase.execute(
                        filename: name,
                        pages: captures,
                        compression: compression
                    )
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success(let document): self.savedDocument = document
                case .failure(let error): self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func refreshPreview(pageID: UUID) {
        guard let page = pages.first(where: { $0.id == pageID }) else { return }
        processingPageIDs.insert(pageID)
        let generation = (previewGeneration[pageID] ?? 0) + 1
        previewGeneration[pageID] = generation
        let enhancer = imageEnhancer
        let data = page.originalData
        let filter = page.filter
        let rotation = page.rotation

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try enhancer.process(
                    data,
                    filter: filter,
                    rotation: rotation,
                    compression: .smallFile
                )
            }
            DispatchQueue.main.async {
                guard let self,
                      self.previewGeneration[pageID] == generation,
                      let index = self.pages.firstIndex(where: { $0.id == pageID }) else { return }
                if self.pages[index].filter == filter,
                   self.pages[index].rotation == rotation,
                   case .success(let preview) = result {
                    self.pages[index].previewData = preview
                }
                self.processingPageIDs.remove(pageID)
                if case .failure(let error) = result {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
