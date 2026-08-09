import XCTest

#if canImport(ScanMasterCore)
@testable import ScanMasterCore
#else
@testable import ScanMasterAI
#endif

final class DocumentNamePolicyTests: XCTestCase {
    func testRemovesPDFExtensionAndForbiddenCharacters() {
        let result = DocumentNamePolicy.normalized("  合同/报价?.PDF  ")
        XCTAssertEqual(result, "合同-报价-")
    }

    func testEmptyNameUsesStableDefaultPrefix() {
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(DocumentNamePolicy.normalized("  ", now: date).hasPrefix("扫描文档 "))
    }

    func testLimitsFilenameLength() {
        let result = DocumentNamePolicy.normalized(String(repeating: "文", count: 120))
        XCTAssertEqual(result.count, DocumentNamePolicy.maximumLength)
    }
}

final class ScanOptionTests: XCTestCase {
    func testQuarterTurnCyclesToZero() {
        var rotation = QuarterTurn.zero
        for _ in 0..<4 { rotation = rotation.rotatedClockwise() }
        XCTAssertEqual(rotation, .zero)
    }

    func testCompressionQualityIsMonotonic() {
        XCTAssertGreaterThan(
            PDFCompression.highQuality.jpegQuality,
            PDFCompression.balanced.jpegQuality
        )
        XCTAssertGreaterThan(
            PDFCompression.balanced.jpegQuality,
            PDFCompression.smallFile.jpegQuality
        )
        XCTAssertGreaterThan(
            PDFCompression.highQuality.maximumDimension,
            PDFCompression.smallFile.maximumDimension
        )
    }
}

final class PageOrdererTests: XCTestCase {
    func testMovingPagesAlsoNormalizesOrder() {
        let documentID = UUID()
        let pages = (0..<3).map { index in
            ScannedPage(
                documentID: documentID,
                originalImagePath: "original-\(index)",
                processedImagePath: "processed-\(index)",
                order: index
            )
        }

        let reordered = PageOrderer.moving(
            pages,
            fromOffsets: IndexSet(integer: 0),
            toOffset: 3
        )

        XCTAssertEqual(reordered.map(\.originalImagePath), ["original-1", "original-2", "original-0"])
        XCTAssertEqual(reordered.map(\.order), [0, 1, 2])
    }
}
