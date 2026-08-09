import SwiftUI

struct DocumentDetailView: View {
    let dependencies: AppDependencyContainer

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DocumentDetailViewModel
    @State private var isSharePresented = false
    @State private var isRenamePresented = false
    @State private var isSplitConfirmationPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var proposedName: String
    @State private var editorSession: ScanSession?

    init(document: ScannedDocument, dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: DocumentDetailViewModel(
                document: document,
                library: dependencies.documentLibraryUseCase
            )
        )
        _proposedName = State(initialValue: document.filename)
    }

    var body: some View {
        Group {
            if let url = viewModel.pdfURL {
                PDFPreview(url: url, version: viewModel.document.updatedAt)
            } else {
                ContentUnavailableView(
                    "PDF 不存在",
                    systemImage: "doc.badge.exclamationmark",
                    description: Text("本地 PDF 文件可能已被移动或删除。")
                )
            }
        }
        .navigationTitle(viewModel.document.filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isSharePresented = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(viewModel.pdfURL == nil)
                Menu {
                    Button {
                        do {
                            editorSession = try viewModel.makeEditSession()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    } label: {
                        Label("编辑页面", systemImage: "slider.horizontal.3")
                    }
                    Button {
                        proposedName = viewModel.document.filename
                        isRenamePresented = true
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }
                    Button {
                        isSplitConfirmationPresented = true
                    } label: {
                        Label("拆分为单页 PDF", systemImage: "rectangle.split.3x1")
                    }
                    .disabled(viewModel.document.pages.count < 2)
                    Divider()
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Label("删除文档", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isSharePresented) {
            if let url = viewModel.pdfURL {
                ShareSheet(items: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(item: $editorSession) { session in
            ScanEditorView(
                session: session,
                dependencies: dependencies,
                onSaved: { updated in
                    editorSession = nil
                    viewModel.acceptUpdatedDocument(updated)
                }
            )
        }
        .alert("重命名", isPresented: $isRenamePresented) {
            TextField("文件名", text: $proposedName)
            Button("取消", role: .cancel) {}
            Button("保存") { viewModel.rename(to: proposedName) }
        }
        .confirmationDialog(
            "拆分 PDF？",
            isPresented: $isSplitConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("拆分为 \(viewModel.document.pages.count) 个文件") {
                viewModel.split()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("原文档会保留，并为每一页创建独立 PDF。")
        }
        .confirmationDialog(
            "删除这个文档？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { viewModel.delete() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会删除 PDF 和所有页面图片，无法撤销。")
        }
        .alert("操作失败", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .alert("完成", isPresented: successBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.successMessage ?? "操作已完成")
        }
        .overlay {
            if viewModel.isBusy {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView("正在拆分 PDF…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
        .onChange(of: viewModel.didDelete) { _, deleted in
            if deleted { dismiss() }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )
    }
}
