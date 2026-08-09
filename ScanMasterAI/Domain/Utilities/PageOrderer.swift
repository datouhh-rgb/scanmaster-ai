import Foundation

enum PageOrderer {
    static func moving(
        _ pages: [ScannedPage],
        fromOffsets: IndexSet,
        toOffset: Int
    ) -> [ScannedPage] {
        var result = pages
        let movingItems = fromOffsets.sorted().map { result[$0] }
        for index in fromOffsets.sorted(by: >) {
            result.remove(at: index)
        }

        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        let destination = min(
            max(0, toOffset - removedBeforeDestination),
            result.count
        )
        result.insert(contentsOf: movingItems, at: destination)

        return result.enumerated().map { index, page in
            var updated = page
            updated.order = index
            return updated
        }
    }
}
