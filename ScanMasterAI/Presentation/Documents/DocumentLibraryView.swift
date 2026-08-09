import SwiftUI

struct DocumentLibraryView: View {
    let dependencies: AppDependencyContainer

    @StateObject private var viewModel: DocumentLibraryViewModel
    @State private var isSelecting = false
    @State private var isMergePromptPresented = false
    @State private var mergeFilename = "合并文档"

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: DocumentLibraryViewModel(
                library: dependencies.documentLibraryUseCase
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.documents.isEmpty {
                ContentUnavailableView {
                    Label("还没有文档", systemImage: "doc.viewfinder")
                } description: {
                    Text("从首页扫描第一份文件，PDF 会安全保存在本机。")
                }
            } else {
                documentList
            }
        }
        .navigationTitle("我的文档")
        .background(AppColors.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelecting ? "完成" : "选择") {
                    isSelecting.toggle()
                    if !isSelecting { viewModel.selectedIDs.removeAll() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting { selectionBar }
        }
        .task { viewModel.load() }
        .onAppear { viewModel.load() }
        .refreshable { viewModel.load() }
        .alert("合并 PDF", isPresented: $isMergePromptPresented) {
            TextField("新文件名", text: $mergeFilename)
            Button("取消", role: .cancel) {}
            Button("合并") { viewModel.merge(filename: mergeFilename) }
        } message: {
            Text("将按文档创建时间和原页面顺序合并。")
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
                    ProgressView("正在合并 PDF…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private var documentList: some View {
        List {
            ForEach(viewModel.documents) { document in
                Group {
                    if isSelecting {
                        Button { viewModel.toggleSelection(document) } label: {
                            HStack(spacing: 12) {
                                Image(
                                    systemName: viewModel.selectedIDs.contains(document.id)
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                )
                                .font(.title3)
                                .foregroundStyle(
                                    viewModel.selectedIDs.contains(document.id)
                                        ? AppColors.accent
                                        : .secondary
                                )
                                DocumentRow(
                                    document: document,
                                    thumbnailData: viewModel.thumbnails[document.id]
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            DocumentDetailView(
                                document: document,
                                dependencies: dependencies
                            )
                        } label: {
                            DocumentRow(
                                document: document,
                                thumbnailData: viewModel.thumbnails[document.id]
                            )
                        }
                        .swipeActions {
                            Button("删除", role: .destructive) {
                                viewModel.delete(document)
                            }
                        }
                    }
                }
                .listRowBackground(AppColors.surface)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var selectionBar: some View {
        HStack {
            Text("已选择 \(viewModel.selectedIDs.count) 项")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button {
                mergeFilename = "合并文档 \(Date().formatted(date: .numeric, time: .omitted))"
                isMergePromptPresented = true
            } label: {
                Label("合并 PDF", systemImage: "doc.on.doc")
                    .fontWeight(.semibold)
            }
            .disabled(viewModel.selectedIDs.count < 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
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

private struct DocumentRow: View {
    let document: ScannedDocument
    let thumbnailData: Data?

    var body: some View {
        HStack(spacing: 14) {
            LocalImageView(data: thumbnailData)
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 6) {
                Text(document.filename)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("\(document.pages.count) 页 · \(document.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
