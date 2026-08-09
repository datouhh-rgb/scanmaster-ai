import Foundation

enum DocumentType: String, Codable, CaseIterable, Hashable {
    case document
    case identityCard
    case receipt
    case other

    var displayName: String {
        switch self {
        case .document: return "文档"
        case .identityCard: return "证件"
        case .receipt: return "票据"
        case .other: return "其他"
        }
    }
}
