import PDFKit
import UIKit
import XCTest

@testable import ScanMasterAI

final class CoreDataDocumentRepositoryTests: XCTestCase {
    func testDocumentRoundTripAndDelete() throws {
        let stack = try CoreDataStack(inMemory: true)
        let repository = CoreDataDocumentRepository(context: stack.container.viewContext)
        let documentID = UUID()
        let page = ScannedPage(
            documentID: documentID,
            originalImagePath: "original.jpg",
            processedImagePath: "processed.jpg",
            order: 0,
            filter: .receipt
        )
        let original = ScannedDocument(
            id: documentID,
            filename: "测试文档",
            pages: [page],
            pdfPath: "document.pdf",
            tags: ["重要"]
        )

        try repository.save(original)
        let fetched = try XCTUnwrap(repository.fetch(id: documentID))

        XCTAssertEqual(fetched, original)
        XCTAssertEqual(fetched.pages.first?.filter, .receipt)
        try repository.delete(id: documentID)
        XCTAssertNil(try repository.fetch(id: documentID))
    }
}

final class ImageEnhancerTests: XCTestCase {
    func testEveryFilterProducesReadableJPEG() throws {
        let source = testImage()
        let data = try XCTUnwrap(source.jpegData(compressionQuality: 0.95))
        let enhancer = CoreImageEnhancer()

        for filter in ScanFilter.allCases {
            let result = try enhancer.process(
                data,
                filter: filter,
                rotation: .clockwise90,
                compression: .smallFile
            )
            let output = try XCTUnwrap(UIImage(data: result))
            XCTAssertGreaterThan(output.size.width, 0, "\(filter) width")
            XCTAssertGreaterThan(output.size.height, 0, "\(filter) height")
            XCTAssertLessThanOrEqual(
                max(output.size.width, output.size.height),
                CGFloat(PDFCompression.smallFile.maximumDimension) + 1
            )
        }
    }

    private func testImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1_900, height: 1_100)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_900, height: 1_100))
            UIColor.black.setFill()
            context.fill(CGRect(x: 180, y: 200, width: 1_500, height: 90))
            context.fill(CGRect(x: 180, y: 400, width: 1_100, height: 60))
        }
    }
}

final class PDFGeneratorTests: XCTestCase {
    func testCreatesMultiPagePDF() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 1_200)).image {
            UIColor.white.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 800, height: 1_200))
        }
        let page = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanMasterPDFTest-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: output) }

        try PDFGenerator().generatePDF(
            from: [page, page, page],
            at: output,
            compression: .balanced
        )

        let document = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(document.pageCount, 3)
        XCTAssertGreaterThan(document.dataRepresentation()?.count ?? 0, 0)
    }

    func testInvalidPageDoesNotReplaceExistingPDF() throws {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanMasterExistingPDF-\(UUID().uuidString).pdf")
        let existingData = Data("existing PDF placeholder".utf8)
        try existingData.write(to: output)
        defer { try? FileManager.default.removeItem(at: output) }

        XCTAssertThrowsError(
            try PDFGenerator().generatePDF(
                from: [Data("not an image".utf8)],
                at: output,
                compression: .balanced
            )
        )
        XCTAssertEqual(try Data(contentsOf: output), existingData)
    }

    func testStorageWriteFailureDoesNotReplaceExistingPDF() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("ScanMasterReadOnly-\(UUID().uuidString)", isDirectory: true)
        let output = directory.appendingPathComponent("existing.pdf")
        let existingData = Data("existing PDF placeholder".utf8)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try existingData.write(to: output)

        defer {
            try? fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path
            )
            try? fileManager.removeItem(at: directory)
        }

        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 1_200)).image {
            UIColor.white.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 800, height: 1_200))
        }
        let page = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        try fileManager.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: directory.path
        )

        XCTAssertThrowsError(
            try PDFGenerator().generatePDF(
                from: [page],
                at: output,
                compression: .balanced
            )
        )
        XCTAssertEqual(try Data(contentsOf: output), existingData)
        XCTAssertEqual(
            try fileManager.contentsOfDirectory(atPath: directory.path),
            ["existing.pdf"]
        )
    }
}
