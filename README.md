# ScanMaster AI

ScanMaster AI 是一款最低支持 iOS 17 的原生文档扫描应用。项目采用 Swift、SwiftUI、MVVM + Clean Architecture，目标是在 12 个月内按版本演进为可提交 App Store 的商业级产品。

当前只实现 **V0.1 扫描基础**，没有提前混入 OCR、证件模板、AI 或云同步功能。

## V0.1 功能

- VisionKit 系统文档相机：自动边缘识别、自动拍摄、裁剪、透视矫正和连续多页扫描。
- 页面编辑：新扫描和已保存文档均可添加、重拍、删除、拖动排序、旋转并重新选择增强模式。
- Core Image 增强：原图、增强、黑白、灰度、票据五种模式。
- PDF：命名、高清/平衡/小文件压缩、预览、原位页面调整、合并、拆分和系统分享。
- 本地文档列表：最近文档、重命名和删除。
- 隐私优先：V0.1 不请求网络权限，扫描图片和 PDF 只保存在应用沙盒。

## 开发环境

- Xcode 26+
- macOS Sequoia 15.6+
- iOS 17+ 真机；VisionKit 文档相机不能在普通模拟器中完成真实拍摄。

截至 2026-07-13，App Store Connect 要求使用 Xcode 26 或更高版本和 iOS 26 SDK 构建上传包。工程的 Deployment Target 仍保持 iOS 17。

## 打开和运行

1. 使用 Xcode 打开 `ScanMasterAI.xcodeproj`。
2. 在 Signing & Capabilities 中选择开发团队，并按需修改 Bundle Identifier。
3. 选择 iOS 17 或更新版本的 iPhone 真机。
4. 运行 `ScanMasterAI` Scheme。
5. 首次扫描时允许相机权限。

## 验证

当前机器没有可用的完整 Xcode 时，可运行不依赖 UIKit 的验证：

```sh
./scripts/verify-core.sh
./scripts/verify-architecture.sh
```

安装 Xcode 后执行：

```sh
xcodebuild \
  -project ScanMasterAI.xcodeproj \
  -scheme ScanMasterAI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

相机扫描验收必须在真机执行。

## 工程结构

```text
ScanMasterAI/
├── App/                 # 组合根和应用入口
├── Domain/              # 实体、枚举、协议、领域规则
├── Application/         # 保存、合并、拆分等用例
├── Infrastructure/      # VisionKit/Core Image/PDF/Core Data/文件系统
└── Presentation/        # SwiftUI View 与 ViewModel
```

详细资料：

- [V0.1 产品说明](docs/V0.1_PRODUCT_SPEC.md)
- [V0.1 架构说明](docs/V0.1_ARCHITECTURE.md)
- [V0.1 测试报告](docs/V0.1_TEST_REPORT.md)
- [V0.1 状态与下一版本计划](docs/V0.1_STATUS.md)
- [12 个月路线图](docs/ROADMAP.md)
- [当前 Mac 的开发环境安装方案](docs/DEVELOPMENT_ENVIRONMENT.md)
- [生成式资产与最终提示记录](docs/ASSET_PROMPTS.md)
