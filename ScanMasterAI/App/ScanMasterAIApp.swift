import SwiftUI

@main
struct ScanMasterAIApp: App {
    private let bootstrap: Result<AppDependencyContainer, Error>

    init() {
        bootstrap = Result { try AppDependencyContainer() }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .success(let dependencies):
                HomeView(dependencies: dependencies)
                    .tint(AppColors.accent)
            case .failure(let error):
                StartupFailureView(error: error)
            }
        }
    }
}

private struct StartupFailureView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("无法启动 ScanMaster AI", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text("本地资料库初始化失败。请重启应用；问题持续时请联系支持。\n\n\(error.localizedDescription)")
        }
        .padding()
    }
}
