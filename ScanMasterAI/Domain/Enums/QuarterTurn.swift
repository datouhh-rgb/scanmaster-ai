import Foundation

enum QuarterTurn: Int, Codable, CaseIterable, Hashable {
    case zero = 0
    case clockwise90 = 90
    case clockwise180 = 180
    case clockwise270 = 270

    func rotatedClockwise() -> QuarterTurn {
        QuarterTurn(rawValue: (rawValue + 90) % 360) ?? .zero
    }
}
