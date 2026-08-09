import SwiftUI
import VisionKit

struct ScanEditorView: View {
    let dependencies: AppDependencyContainer
    let onSaved: (ScannedDocument) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ScanEditorViewModel
    @State private var scannerMode: EditorScannerMode?
    @State private var isOrganizerPresented = false
    @State private var isSaveSheetPresented = false
    @State private var isDiscardConfirmationPresented = false

    init(
        session: ScanSession,
        dependencies: AppDependencyContainer,
        onSaved: @escaping (ScannedDocument) -> Void
    ) {
        self.dependencies = dependencies
        self.onSaved = onSaved
        _viewModel = StateObject(
            wrappedValue: ScanEditorViewModel(
                session: session,
                imageEnhancer: dependencies.imageEnhancer,
                saveScan: dependencies.saveScanUseCase,
                updateScan: dependencies.updateScanUseCase
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pagePreview
                pageCounter
                filterBar
                actionBar
            }
            .background(AppColors.background)
            .navigationTitle("编辑扫描")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isDiscardConfirmationPresented = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成 PDF") { isSaveSheetPresented = true }
                        .fontWeight(.semibold)
                        .disabled(viewModel.pages.isEmpty)
                }
            }
            .sheet(item: $scannerMode) { mode in
                DocumentScannerView(
                    onComplete: { images in
                        scannerMode = nil
                        switch mode {
                        case .add: viewModel.add(images: images)
                        case .replace: viewModel.replaceSelected(with: images)
                        }
                    },
                    onCancel: { scannerMode = nil },
                    onError: { error in
                        scannerMode = nil
                        viewModel.errorMessage = error.localizedDescription
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isOrganizerPresented) {
                PageOrganizerView(viewModel: viewModel)
            }
            .sheet(isPresented: $isSaveSheetPresented) {
                SaveDocumentView(viewModel: viewModel)
                    .presentationDetents([.medium])
                    .interactiveDismissDisabled(viewModel.isSaving)
            }
            .confirmationDialog(
                "放弃当前扫描？",
                isPresented: $isDiscardConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("放弃扫描", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            } message: {
                Text("尚未生成 PDF，离开后这些页面不会保存。")
            }
            .alert("操作失败", isPresented: errorBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "未知错误")
            }
            .onChange(of: viewModel.savedDocument?.id) { _, savedID in
                guard savedID != nil else { return }
                isSaveSheetPresented = false
                if let document = viewModel.savedDocument {
                    onSaved(document)
                }
                dismiss()
            }
        }
    }

    private var pagePreview: some View {
        TabView(selection: $viewModel.selectedPageID) {
            ForEach(viewModel.pages) { page in
                ZStack {
                    Color(uiColor: .secondarySystemBackground)
                    LocalImageView(data: page.previewData, contentMode: .fit)
                        .padding(16)
                    if viewModel.processingPageIDs.contains(page.id) {
                        ProgressView("正在增强")
                            .padding(14)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .tag(Optional(page.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxHeight: .infinity)
        .accessibilityLabel("扫描页面预览")
    }

    private var pageCounter: some View {
        HStack {
            Text("第 \(viewModel.selectedPageNumber) 页 / 共 \(viewModel.pages.count) 页")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                isOrganizerPresented = true
            } label: {
                Label("页面排序", systemImage: "rectangle.stack.badge.play")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ScanFilter.allCases) { filter in
                    Button {
                        viewModel.select(filter: filter)
                    } label: {
                        Text(filter.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                viewModel.selectedPage?.filter == filter ? .white : .primary
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                viewModel.selectedPage?.filter == filter
                                    ? AppColors.accent
                                    : Color(uiColor: .tertiarySystemFill),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var actionBar: some View {
        HStack {
            editorAction("添加", systemImage: "plus.viewfinder") {
                guard VNDocumentCameraViewController.isSupported else {
                    viewModel.errorMessage = "当前设备不支持文档相机。"
                    return
                }
                scannerMode = .add
            }
            Spacer()
            editorAction("重拍", systemImage: "arrow.triangle.2.circlepath.camera") {
                guard VNDocumentCameraViewController.isSupported else {
                    viewModel.errorMessage = "当前设备不支持文档相机。"
                    return
                }
                scannerMode = .replace
            }
            Spacer()
            editorAction("旋转", systemImage: "rotate.right") {
                viewModel.rotateSelectedPage()
            }
            Spacer()
            editorAction("删除", systemImage: "trash", role: .destructive) {
                viewModel.deleteSelectedPage()
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 14)
        .background(AppColors.surface)
    }

    private func editorAction(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(minWidth: 56)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private enum EditorScannerMode: String, Identifiable {
    case add
    case replace

    var id: String { rawValue }
}
