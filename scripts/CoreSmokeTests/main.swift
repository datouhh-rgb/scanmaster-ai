import Foundation

private var failures = 0

private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    if condition() {
        print("PASS: \(message)")
    } else {
        failures += 1
        print("FAIL: \(message)")
    }
}

let normalized = DocumentNamePolicy.normalized("  合同/报价?.PDF  ")
expect(normalized == "合同-报价-", "文件名清理扩展名和非法字符")

let defaultName = DocumentNamePolicy.normalized("  ", now: Date(timeIntervalSince1970: 0))
expect(defaultName.hasPrefix("扫描文档 "), "空文件名生成安全默认值")

let longName = DocumentNamePolicy.normalized(String(repeating: "文", count: 120))
expect(longName.count == DocumentNamePolicy.maximumLength, "文件名限制为 80 个字符")

var rotation = QuarterTurn.zero
for _ in 0..<4 { rotation = rotation.rotatedClockwise() }
expect(rotation == .zero, "旋转四次回到初始方向")

expect(
    PDFCompression.highQuality.jpegQuality > PDFCompression.balanced.jpegQuality,
    "高清压缩质量高于平衡模式"
)
expect(
    PDFCompression.balanced.jpegQuality > PDFCompression.smallFile.jpegQuality,
    "平衡压缩质量高于小文件模式"
)

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
expect(
    reordered.map(\.originalImagePath) == ["original-1", "original-2", "original-0"],
    "页面拖动保持期望顺序"
)
expect(reordered.map(\.order) == [0, 1, 2], "页面拖动后重新编号")

if failures > 0 {
    print("\(failures) core smoke test(s) failed")
    exit(1)
}

print("All core smoke tests passed")
