import Foundation

enum ScanFilter: String, Codable, CaseIterable, Identifiable, Hashable {
    case original
    case enhanced
    case blackAndWhite
    case grayscale
    case receipt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "原图"
        case .enhanced: return "增强"
        case .blackAndWhite: return "黑白"
        case .grayscale: return "灰度"
        case .receipt: return "票据"
        }
    }
}
