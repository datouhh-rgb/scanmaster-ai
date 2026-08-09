import SwiftUI

struct PageOrganizerView: View {
    @ObservedObject var viewModel: ScanEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    HStack(spacing: 14) {
                        LocalImageView(data: page.previewData, contentMode: .fill)
                            .frame(width: 52, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("第 \(index + 1) 页")
                                .font(.headline)
                            Text(page.filter.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove(perform: viewModel.move)
                .onDelete(perform: viewModel.delete)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("调整页面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
