import Foundation

final class LocalDocumentFileManager: DocumentFileManaging {
    private let systemFileManager: FileManager
    private let rootURL: URL

    init(systemFileManager: FileManager = .default) throws {
        self.systemFileManager = systemFileManager
        let applicationSupport = try systemFileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        rootURL = applicationSupport
            .appendingPathComponent("ScanMasterAI", isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
        try systemFileManager.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
    }

    func saveImage(
        _ data: Data,
        documentID: UUID,
        pageID: UUID,
        variant: ImageVariant
    ) throws -> String {
        let directory = try documentDirectory(documentID: documentID)
            .appendingPathComponent("Images", isDirectory: true)
        try systemFileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("\(pageID.uuidString)-\(variant.rawValue).jpg")
        try data.write(to: url, options: .atomic)
        return relativePath(for: url)
    }

    func loadImage(at relativePath: String) throws -> Data {
        try Data(contentsOf: absoluteURL(for: relativePath), options: .mappedIfSafe)
    }

    func pdfURL(documentID: UUID, filename: String) throws -> URL {
        let directory = try documentDirectory(documentID: documentID)
        let safeName = DocumentNamePolicy.normalized(filename)
        return directory.appendingPathComponent("\(safeName).pdf")
    }

    func renamePDF(at relativePath: String, filename: String) throws -> String {
        let source = absoluteURL(for: relativePath)
        let destination = source.deletingLastPathComponent().appendingPathComponent(
            "\(DocumentNamePolicy.normalized(filename)).pdf"
        )
        guard source.standardizedFileURL != destination.standardizedFileURL else {
            return relativePath
        }
        if systemFileManager.fileExists(atPath: destination.path) {
            try systemFileManager.removeItem(at: destination)
        }
        try systemFileManager.moveItem(at: source, to: destination)
        return self.relativePath(for: destination)
    }

    func absoluteURL(for relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath)
    }

    func relativePath(for absoluteURL: URL) -> String {
        let root = rootURL.standardizedFileURL.path
        let path = absoluteURL.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else { return absoluteURL.lastPathComponent }
        return String(path.dropFirst(root.count + 1))
    }

    func removeFile(at relativePath: String) throws {
        let url = absoluteURL(for: relativePath).standardizedFileURL
        let root = rootURL.standardizedFileURL.path
        guard url.path.hasPrefix(root + "/") else { return }
        if systemFileManager.fileExists(atPath: url.path) {
            try systemFileManager.removeItem(at: url)
        }
    }

    func removeFiles(documentID: UUID) throws {
        let directory = rootURL.appendingPathComponent(documentID.uuidString, isDirectory: true)
        if systemFileManager.fileExists(atPath: directory.path) {
            try systemFileManager.removeItem(at: directory)
        }
    }

    private func documentDirectory(documentID: UUID) throws -> URL {
        let directory = rootURL.appendingPathComponent(documentID.uuidString, isDirectory: true)
        try systemFileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
