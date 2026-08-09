import SwiftUI

struct SaveDocumentView: View {
    @ObservedObject var viewModel: ScanEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("文件") {
                    TextField("PDF 名称", text: $viewModel.filename)
                        .textInputAutocapitalization(.never)
                    LabeledContent("页数", value: "\(viewModel.pages.count) 页")
                }
                Section("压缩") {
                    Picker("PDF 质量", selection: $viewModel.compression) {
                        ForEach(PDFCompression.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(compressionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(viewModel.isEditingExistingDocument ? "更新 PDF" : "生成 PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isEditingExistingDocument ? "更新" : "保存") {
                        viewModel.save()
                    }
                        .fontWeight(.semibold)
                        .disabled(viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    ZStack {
                        Color.black.opacity(0.16).ignoresSafeArea()
                        ProgressView("正在生成 PDF…")
                            .padding(22)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
        }
    }

    private var compressionDescription: String {
        switch viewModel.compression {
        case .highQuality: return "保留更多细节，适合打印和归档。"
        case .balanced: return "清晰度与文件大小平衡，推荐日常使用。"
        case .smallFile: return "适合聊天和邮件发送，细节会有所减少。"
        }
    }
}
