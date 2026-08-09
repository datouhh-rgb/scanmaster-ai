import Foundation

enum DocumentNamePolicy {
    static let maximumLength = 80

    static func normalized(_ proposedName: String, now: Date = Date()) -> String {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutExtension: String
        if trimmed.lowercased().hasSuffix(".pdf") {
            withoutExtension = String(trimmed.dropLast(4))
        } else {
            withoutExtension = trimmed
        }

        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let safeScalars = withoutExtension.unicodeScalars.map { scalar in
            forbidden.contains(scalar) ? "-" : String(scalar)
        }
        let safe = safeScalars.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if safe.isEmpty {
            return defaultName(now: now)
        }
        return String(safe.prefix(maximumLength))
    }

    static func defaultName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "扫描文档 \(formatter.string(from: now))"
    }
}
