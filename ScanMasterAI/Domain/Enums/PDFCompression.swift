import Foundation

enum PDFCompression: String, Codable, CaseIterable, Identifiable, Hashable {
    case highQuality
    case balanced
    case smallFile

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highQuality: return "高清"
        case .balanced: return "平衡"
        case .smallFile: return "小文件"
        }
    }

    var jpegQuality: Double {
        switch self {
        case .highQuality: return 0.92
        case .balanced: return 0.76
        case .smallFile: return 0.55
        }
    }

    var maximumDimension: Double {
        switch self {
        case .highQuality: return 3_500
        case .balanced: return 2_500
        case .smallFile: return 1_600
        }
    }
}
