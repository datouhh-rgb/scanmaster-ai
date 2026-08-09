import Foundation

private final class FakeImageEnhancer: ImageEnhancing {
    func process(
        _ imageData: Data,
        filter: ScanFilter,
        rotation: QuarterTurn,
        compression: PDFCompression
    ) throws -> Data {
        imageData + Data("-processed".utf8)
    }
}

private final class FakePDFGenerator: PDFGenerating {
    private(set) var generatedPageCount = 0

    func generatePDF(
        from pageData: [Data],
        at outputURL: URL,
        compression: PDFCompression
    ) throws {
        generatedPageCount = pageData.count
        try Data("mock-pdf".utf8).write(to: outputURL)
    }
}

private final class TemporaryFileManager: DocumentFileManaging {
    private let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanMasterArchitectureSmoke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func saveImage(
        _ data: Data,
        documentID: UUID,
        pageID: UUID,
        variant: ImageVariant
    ) throws -> String {
        let directory = root.appendingPathComponent(documentID.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = "\(documentID.uuidString)/\(pageID.uuidString)-\(variant.rawValue).jpg"
        try data.write(to: absoluteURL(for: path))
        return path
    }

    func loadImage(at relativePath: String) throws -> Data {
        try Data(contentsOf: absoluteURL(for: relativePath))
    }

    func pdfURL(documentID: UUID, filename: String) throws -> URL {
        let directory = root.appendingPathComponent(documentID.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(DocumentNamePolicy.normalized(filename)).pdf")
    }

    func renamePDF(at relativePath: String, filename: String) throws -> String {
        let source = absoluteURL(for: relativePath)
        let destination = source.deletingLastPathComponent().appendingPathComponent(
            "\(DocumentNamePolicy.normalized(filename)).pdf"
        )
        if source != destination { try FileManager.default.moveItem(at: source, to: destination) }
        return self.relativePath(for: destination)
    }

    func absoluteURL(for relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    func relativePath(for absoluteURL: URL) -> String {
        String(absoluteURL.path.dropFirst(root.path.count + 1))
    }

    func removeFile(at relativePath: String) throws {
        let url = absoluteURL(for: relativePath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func removeFiles(documentID: UUID) throws {
        let directory = root.appendingPathComponent(documentID.uuidString)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message)")
        exit(1)
    }
}

do {
    let stack = try CoreDataStack(inMemory: true)
    let repository = CoreDataDocumentRepository(context: stack.container.viewContext)
    let files = try TemporaryFileManager()
    let enhancer = FakeImageEnhancer()
    let generator = FakePDFGenerator()
    let save = SaveScannedDocumentUseCase(
        repository: repository,
        fileManager: files,
        imageEnhancer: enhancer,
        pdfGenerator: generator
    )
    let library = DocumentLibraryUseCase(
        repository: repository,
        fileManager: files,
        saveScan: save
    )
    let update = UpdateScannedDocumentUseCase(
        repository: repository,
        fileManager: files,
        imageEnhancer: enhancer,
        pdfGenerator: generator
    )

    let saved = try save.execute(
        filename: "测试/合同.pdf",
        pages: [
            CapturedPage(imageData: Data("page-one".utf8)),
            CapturedPage(imageData: Data("page-two".utf8), filter: .grayscale)
        ]
    )

    require(saved.filename == "测试-合同", "保存用例执行文件名策略")
    require(saved.pages.count == 2, "保存用例保留两页")
    require(generator.generatedPageCount == 2, "PDF 生成器收到全部页面")
    let generatedPDFExists = library.pdfURL(for: saved).map {
        FileManager.default.fileExists(atPath: $0.path)
    } ?? false
    require(generatedPDFExists, "PDF 文件已写入")

    let fetched = try library.fetchDocuments()
    require(fetched.count == 1, "Core Data 可读取保存的文档")
    require(fetched[0].pages.map(\.order) == [0, 1], "Core Data 往返保持页面顺序")

    let renamed = try library.rename(document: fetched[0], to: "最终版")
    require(renamed.filename == "最终版", "文档支持重命名")
    require(renamed.pdfPath?.hasSuffix("最终版.pdf") == true, "重命名同步更新实际 PDF 文件名")

    let split = try library.split(document: renamed)
    require(split.count == 2, "多页文档可拆分为单页 PDF")

    let merged = try library.merge(documents: split, filename: "重新合并")
    require(merged.pages.count == 2, "多个单页 PDF 可重新合并")

    let originalOrder = merged.pages.sorted { $0.order < $1.order }
    let reversedCaptures = try originalOrder.reversed().map { page in
        CapturedPage(
            id: page.id,
            imageData: try files.loadImage(at: page.originalImagePath),
            filter: .receipt,
            rotation: .clockwise90
        )
    }
    let edited = try update.execute(
        document: merged,
        filename: "重新编辑",
        pages: reversedCaptures
    )
    require(edited.id == merged.id, "页面编辑原位更新文档而非创建副本")
    require(edited.pages.map(\.id) == originalOrder.reversed().map(\.id), "页面编辑保存新排序")
    require(edited.pages.allSatisfy { $0.filter == .receipt }, "页面编辑保存新滤镜")

    let removedPage = edited.pages[1]
    let singlePage = try update.execute(
        document: edited,
        filename: edited.filename,
        pages: [
            CapturedPage(
                id: edited.pages[0].id,
                imageData: try files.loadImage(at: edited.pages[0].originalImagePath)
            )
        ]
    )
    require(singlePage.pages.count == 1, "页面编辑支持删除页面")
    require(
        !FileManager.default.fileExists(atPath: files.absoluteURL(for: removedPage.originalImagePath).path),
        "页面更新后清理已删除页面文件"
    )

    try library.delete(document: singlePage)
    let deletedDocument = try repository.fetch(id: singlePage.id)
    require(deletedDocument == nil, "删除同时移除元数据")
    print("All architecture smoke tests passed")
} catch {
    print("FAIL: \(error)")
    exit(1)
}
