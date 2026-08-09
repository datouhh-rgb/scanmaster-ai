import Foundation

final class AppDependencyContainer {
    let saveScanUseCase: SaveScannedDocumentUseCase
    let updateScanUseCase: UpdateScannedDocumentUseCase
    let documentLibraryUseCase: DocumentLibraryUseCase
    let imageEnhancer: ImageEnhancing

    private let coreDataStack: CoreDataStack
    private let fileManager: DocumentFileManaging
    private let repository: DocumentRepository
    private let pdfGenerator: PDFGenerating

    init(inMemory: Bool = false) throws {
        let stack = try CoreDataStack(inMemory: inMemory)
        let files = try LocalDocumentFileManager()
        let documentRepository = CoreDataDocumentRepository(context: stack.container.viewContext)
        let enhancer = CoreImageEnhancer()
        let generator = PDFGenerator()
        let saveUseCase = SaveScannedDocumentUseCase(
            repository: documentRepository,
            fileManager: files,
            imageEnhancer: enhancer,
            pdfGenerator: generator
        )

        coreDataStack = stack
        fileManager = files
        repository = documentRepository
        imageEnhancer = enhancer
        pdfGenerator = generator
        saveScanUseCase = saveUseCase
        updateScanUseCase = UpdateScannedDocumentUseCase(
            repository: documentRepository,
            fileManager: files,
            imageEnhancer: enhancer,
            pdfGenerator: generator
        )
        documentLibraryUseCase = DocumentLibraryUseCase(
            repository: documentRepository,
            fileManager: files,
            saveScan: saveUseCase
        )
    }
}
