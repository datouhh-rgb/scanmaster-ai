import SwiftUI
import UIKit
import VisionKit

struct HomeView: View {
    let dependencies: AppDependencyContainer

    @StateObject private var viewModel: HomeViewModel
    @State private var isScannerPresented = false
    @State private var editorSession: ScanSession?
    @State private var scannerError: String?
    @State private var futureFeature: String?
    @State private var isPreparingScan = false

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(library: dependencies.documentLibraryUseCase)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    scanButton
                    featureGrid
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
            .task { viewModel.load() }
            .sheet(isPresented: $isScannerPresented) {
                DocumentScannerView(
                    onComplete: handleScan,
                    onCancel: { isScannerPresented = false },
                    onError: { error in
                        isScannerPresented = false
                        scannerError = error.localizedDescription
                    }
                )
                .ignoresSafeArea()
            }
            .fullScreenCover(item: $editorSession) { session in
                ScanEditorView(
                    session: session,
                    dependencies: dependencies,
                    onSaved: { _ in
                        editorSession = nil
                        viewModel.load()
                    }
                )
            }
            .alert("暂未开放", isPresented: futureAlertBinding) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(futureFeature ?? "该功能将在后续版本提供。")
            }
            .alert("无法扫描", isPresented: scannerAlertBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(scannerError ?? "请检查相机权限后重试。")
            }
            .overlay {
                if isPreparingScan {
                    ZStack {
                        Color.black.opacity(0.12).ignoresSafeArea()
                        ProgressView("正在准备页面…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ScanMaster AI")
                    .font(.largeTitle.bold())
                Text("轻量、私密的随身扫描仪")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "shield.lefthalf.filled")
                .font(.title2)
                .foregroundStyle(AppColors.mint)
                .accessibilityLabel("本地隐私保护")
        }
        .padding(.top, 18)
    }

    private var scanButton: some View {
        Button(action: startScan) {
            HStack(spacing: 18) {
                Image(systemName: "doc.viewfinder.fill")
                    .font(.system(size: 40, weight: .semibold))
                VStack(alignment: .leading, spacing: 5) {
                    Text("扫描文件")
                        .font(.title2.bold())
                    Text("自动裁边 · 连续多页 · 高清 PDF")
                        .font(.subheadline)
                        .opacity(0.86)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(
                LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26)
            )
            .shadow(color: AppColors.accent.opacity(0.22), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开相机并自动识别文档边缘")
    }

    private var featureGrid: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    futureFeature = "证件扫描将在 V1.0 提供，届时支持身份证、护照、银行卡和营业执照。"
                } label: {
                    FeatureCard(
                        title: "扫描证件",
                        subtitle: "标准尺寸与智能拉正",
                        systemImage: "person.text.rectangle",
                        color: .orange,
                        badge: "V1.0"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button {
                    futureFeature = "图片文字识别将在 V0.5 提供，支持中英文 OCR 与全文搜索。"
                } label: {
                    FeatureCard(
                        title: "图片识别",
                        subtitle: "中文、英文 OCR",
                        systemImage: "text.viewfinder",
                        color: .purple,
                        badge: "V0.5"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }

            NavigationLink {
                DocumentLibraryView(dependencies: dependencies)
            } label: {
                FeatureCard(
                    title: "我的文档",
                    subtitle: "预览、合并、拆分与分享 PDF",
                    systemImage: "folder.fill",
                    color: AppColors.accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !viewModel.recentDocuments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("最近文档")
                        .font(.title3.bold())
                    Spacer()
                    NavigationLink("查看全部") {
                        DocumentLibraryView(dependencies: dependencies)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                ForEach(viewModel.recentDocuments) { document in
                    NavigationLink {
                        DocumentDetailView(document: document, dependencies: dependencies)
                    } label: {
                        HStack(spacing: 14) {
                            LocalImageView(data: viewModel.thumbnails[document.id])
                                .frame(width: 54, height: 68)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(document.filename)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(document.pages.count) 页 · \(document.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private func startScan() {
        guard VNDocumentCameraViewController.isSupported else {
            scannerError = "当前设备不支持文档相机。请在装有摄像头的 iPhone 上使用。"
            return
        }
        isScannerPresented = true
    }

    private func handleScan(_ images: [UIImage]) {
        isScannerPresented = false
        guard !images.isEmpty else {
            scannerError = "没有获取到扫描页面，请重新拍摄。"
            return
        }
        isPreparingScan = true
        DispatchQueue.global(qos: .userInitiated).async {
            let pages = images.compactMap { $0.jpegData(compressionQuality: 0.96) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPreparingScan = false
                if pages.isEmpty {
                    scannerError = "扫描页面转换失败，请重新拍摄。"
                } else {
                    editorSession = ScanSession(pageData: pages)
                }
            }
        }
    }

    private var futureAlertBinding: Binding<Bool> {
        Binding(
            get: { futureFeature != nil },
            set: { if !$0 { futureFeature = nil } }
        )
    }

    private var scannerAlertBinding: Binding<Bool> {
        Binding(
            get: { scannerError != nil },
            set: { if !$0 { scannerError = nil } }
        )
    }
}
