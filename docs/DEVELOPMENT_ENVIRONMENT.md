# 本机开发环境安装方案

检测日期：2026-08-09

## 当前硬件

- MacBook Pro 13-inch Early 2015，机型标识 `MacBookPro12,1`。
- 双核 Intel Core i5，8 GB RAM。
- 内置盘约 25 GB 可用。
- 外置 1 TB USB SSD `/dev/disk2` 已分为 600 GB HFS+ 数据分区 `新加卷` 和 423.9 GB APFS 开发容器 `ScanMaster Dev`；原数据分区仍有约 55 GB 数据。
- 独立 128 GB USB SSD `/dev/disk3` 已命名为 `OCLP Installer`。
- macOS Monterey 12.7.4，仅安装 Command Line Tools 14.2。

Apple 将 Monterey 列为该机型的最高官方系统。Xcode 26 需要 macOS Sequoia 15.6 或更高版本，因此不存在满足当前 App Store 提交要求的官方本机安装组合。

## 推荐的非官方本机组合

- 内置盘：继续保留 Monterey，作为稳定恢复环境。
- 外置盘现有 600 GB HFS+ 分区：保留已有数据。
- 外置盘 423.9 GB APFS 容器：`ScanMaster Dev` 保存安装资源，空白 `ScanMaster System` 安装 macOS Sequoia 15.7.x、Xcode 26.3、Simulator 和 DerivedData；两卷共享容器空间。
- 单独 `OCLP Installer` 128 GB 外置盘：制作 OpenCore Legacy Patcher/macOS 安装介质；该盘会被完全清空。
- Xcode：选择仍支持 macOS Sequoia 15.6 的 Xcode 26.3，而不是要求 macOS Tahoe 的 Xcode 26.4+。Xcode 26.3 满足“Xcode 26 或更高版本”上传要求，并支持从 iOS 17 起的应用部署。
- 测试：界面和单元测试可用模拟器；VisionKit 相机必须使用 iPhone 真机。

## 计划中的存储布局

```text
外置 SSD
├── 新加卷              # 保留现有 HFS+ 数据
└── APFS 容器，约 424 GB
    ├── ScanMaster Dev       # 安装器、OCLP、KDK 等资源归档
    └── ScanMaster System    # 空白系统目标
        ├── macOS Sequoia
        ├── Applications/Xcode.app
        └── Developer/
            ├── DerivedData
            ├── CoreSimulator
            └── Archives
```

源码继续放在内置盘。源码体积小，外盘意外断开时不影响 Git 工作树。

## 执行门禁

在执行外盘缩容、创建 APFS 分区或安装 OpenCore 前，必须同时满足：

1. 用户明确接受非 Apple 官方支持方案。
2. 外置盘已有 55 GB 数据存在另一份可恢复备份。
3. 已插入一个至少 32 GB、允许完全清空的独立 U 盘。
4. Mac 已接通电源，安装期间不拔出任何存储设备。

即使“无损缩容”通常会保留数据，分区表修改仍有断电或介质故障风险，不能把空闲空间充足等同于无需备份。

## 已完成的环境准备

- `ScanMaster Dev` APFS 资源卷和空白 `ScanMaster System` 系统目标卷均已创建并挂载；两者位于同一容器并共享约 374.9 GB 可用空间。
- 独立 128 GB 安装盘已制作为 `Install macOS Sequoia`，并包含 OpenCore EFI、OCLP 离线包、检查点和诊断脚本。
- OpenCore Legacy Patcher 2.4.1 官方 pkg 已下载到 `ScanMaster Dev/DeveloperInstallers`。
- 文件大小为 735,976,622 字节，SHA-256 为 `a8c0732c197b49337d2b8b970ce57f5151495a2dac300e1f93e802a0261e188d`，与 GitHub Release API 摘要一致。
- pkg 与应用均通过 Apple Developer ID 签名检查和 Apple 公证验证。
- OCLP 已正确识别机型 `MacBookPro12,1`。Monterey 下的 `C.UTF-8` 区域环境会触发 OCLP 2.4.1 的 `unsupported locale setting`；仅对 OCLP 进程设置 `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8` 后可正常工作，不修改系统显示语言或用户偏好。
- OCLP 从 Apple 软件目录确认安装目标为 `macOS Sequoia 15.7.7 (24G720)`，`InstallAssistant.pkg` 大小为 15,655,501,868 字节，来源域名为 `swcdn.apple.com`。
- 安装包已直接下载到 `ScanMaster Dev/DeveloperInstallers/macOS-Sequoia-15.7.7-24G720`，不占用内置盘的安装包空间。合并后大小等于 15,655,501,868 字节，SHA-256 为 `7e1277990f0a0b0922d75e0e4bdbe293319091610703e31319efbea17f33430a`，`pkgutil` 确认为 `signed Apple Software`，Gatekeeper 确认为 `accepted / Apple Installer`。
- 完整安装器应用已在外置卷组装为 `/Volumes/ScanMaster Dev/Applications/Install macOS Sequoia.app`。应用内 `SharedSupport.dmg` 与整个 Apple `InstallAssistant.pkg` 共享同一 inode，因此没有再复制 15.6 GB 数据。
- `createinstallmedia` 是 Apple `Software Signing` 签名的 x86_64/arm64 通用可执行文件，严格 `codesign` 检查通过；但 Sequoia 15.7.7 版本在 Monterey 12.7.4 上启动即发生 `EXC_BAD_ACCESS / SIGSEGV`（exit `139`），所以未用它再次格式化介质。`hdiutil verify` 确认 SharedSupport 的全映像校验和为 `VALID`；只读挂载后的 Apple MobileAsset 清单确认 `OSVersion=15.7.7` 和 `Build=24G720`。
- OCLP 已为 `MacBookPro12,1` / `Mac-E43C1C25D4880AD6` 构建并验证 OpenCore 1.0.4 EFI；保存路径为 `/Volumes/ScanMaster Dev/DeveloperInstallers/OpenCore-Build-MacBookPro12,1`，共 167 个文件、约 25 MB。配置包含 OpenCanopy、Wi-Fi、SPI 顶壳、USB、相机和 AMFI 所需补丁，`config.plist` 通过 OCLP 内置验证和 `plutil` 检查。
- 128 GB `OCLP Installer` 已成功制作为 `Install macOS Sequoia`：Apple `createinstallmedia` 报告擦除、RecoveryOS 复制、启动化和全量复制 100% 完成。介质约占用 16 GB，`.IAPhysicalMedia` 存在，System/CoreServices 已 bless，BaseSystem 校验和为 `VALID`。
- `MacBookPro12,1` OpenCore 已按 OCLP 2.4.1 官方 `install.py` 逻辑写入该盘的 209.7 MB EFI 分区。源和目标均为 167 个文件，逐文件 SHA-256 清单差异为 0，写入后 EFI 已安全卸载。
- OCLP 2.4.1 官方 pkg 和环境检查点已复制到安装盘 `PostInstall` 目录；pkg 副本大小为 735,976,622 字节，与已验签源文件逐字节一致。
- 第一次从 OpenCore 启动安装器时，选择同时保存安装资源的 `ScanMaster Dev` 后出现“安装器已损坏”的通用提示，安装未开始。
- 第二次在空白 `ScanMaster System` 上复现后，用户提供的安装器日志显示 `pkgdmg is missing a footer`、`pkgdmg validation has failed`、`OSISVerifyBaseSystemOperation`、`com.apple.OSInstallerSetup.error Code=255`。这排除了目标卷因素并定位到安装器组装层。
- 下载数据仍经复核为完整：InstallAssistant Apple 软件证书有效到 2029 年；15,629,879,094 字节核心系统 ZIP 的 SHA-256 为 `da5423a77073d1bb265c2e61d2eeb8893da817c3a3a6378ba474f6654105e847`，与 Apple MobileAsset 清单一致。问题不在下载，而在此前错误使用了包内抽出的普通 DMG。
- Apple `InstallAssistant.pkg` 是 XAR + UDIF 双格式 PKGDMG。OCLP 2.4.1 官方 `postinstall_actions/link_shared_support.bash` 会把整个 `InstallAssistant.pkg` 链接为应用内 `SharedSupport.dmg`。当前外置安装器已按此语义修正：两者 inode 均为 `434`、大小均为 `15,655,501,868` 字节、`cmp` 完全一致。
- 128 GB 安装盘已通过带回滚保护的原位修复更换 `SharedSupport.dmg`：新文件在切换前后均通过 `cmp` 和 `hdiutil verify`，独立复核得到 `CMP=IDENTICAL`；文件大小为 `15,655,501,868` 字节、文件头为 `xar!`。旧普通 DMG 与临时副本已删除，BaseSystem 校验和、`.IAPhysicalMedia` 和 bless 信息均保持正常。
- OCLP/OpenCore EFI 在首次制作后曾以 167 个文件逐一 SHA-256 验证通过；本次修复没有写入 EFI。重启前又通过管理员授权只读挂载复核，源和目标各 167 个文件的 SHA-256 清单完全一致，`config.plist` 正常，EFI 已安全卸载。
- 最终重启前审计确认 `ScanMaster System` 仍为空白 APFS 卷，仅约 896 KB；其容器约有 374.9 GB 可用空间。系统安装只允许选择该卷。
- macOS Sequoia 已成功安装到外置 `ScanMaster System` 卷组。离线检查确认版本为 15.7.7（24G720），System/Data/Preboot/Recovery/VM 结构完整，密封系统快照和 bless 信息正确，首次设置已完成并创建用户 `andy`。
- 安装完成后曾暂时回到内置 Monterey；随后已通过新 EFI/OpenCore 进入 `ScanMaster System`，完成 OCLP Post-Install Root Patch 并重启。
- `ChatGPT.app` 和 `ClashX.app` 已复制为 Sequoia `/Applications` 下的独立实体应用包，未移动或软链接 Monterey 原文件。两者源/目标逐文件清单一致且目标代码签名有效。
- ChatGPT 没有迁移任何 `com.openai.codex` 用户数据、`.codex`、登录令牌、偏好或缓存，Sequoia 首次启动需重新登录。ClashX 则完整迁移核心配置目录、Application Support、偏好和自动启动项，全部使用 `andy` 对应的 UID 501/GID 20。
- 两套系统的 SystemConfiguration 代理数据库保持独立且均未被迁移脚本改写。Sequoia 首次启用 ClashX 系统代理时，由应用包自带且已签名的 ProxyConfigHelper 在该系统内重新请求管理员授权。
- OCLP 2.4.1 已使用官方 pkg 正式安装到 Monterey，Privileged Helper Tool 已就位，OpenCore 的 `revpatch=sbvmm` 兼容性绕过也已在 NVRAM 中确认。
- 已新增独立空白 `ScanMaster System` 作为唯一系统目标，避免安装器、归档资源与系统目标共用同一卷。精简 InstallAssistant 界面没有“实用工具 → 终端”；若还有错误，将直接使用其“安装器日志”窗口取证。
- 当前运行环境已确认为 macOS Sequoia 15.7.7（24G720）/ Intel x86_64；Root Patch 后 Intel Iris Graphics 6100、Metal 2 和 FaceTime 相机均已识别。
- Xcode 26.3（17C529）Universal 已安装到 `/Applications/Xcode.app`，许可、首次启动组件、`xcode-select`、Apple 签名和 Gatekeeper 验收均已完成。
- iOS 26.2 Device/Simulator SDK、iOS 26.2 Simulator Runtime（23C54）和 iOS 17.5 Simulator Runtime（21F79）均可用。iOS 17.5 官方 DMG 为 `7,336,630,623` 字节，`hdiutil verify` 为 `VALID`，SHA-256 为 `8021fac54f569def395a0275fd5bb704a85f325b63a4d0b7fba9a4d00e57fd00`；归档位于 `/Volumes/ScanMaster Dev/DeveloperInstallers/iOS-17.5-Simulator-Runtime/iOS_17.5_Simulator_Runtime.dmg`。Runtime 资源均保存在 `ScanMaster Dev/DeveloperInstallers`。
- ScanMasterAI V0.1 已在 iPhone 17 Pro / iOS 26.2 模拟器完成 Debug、Release 和最终 11 项 XCTest，全部通过。最终结果包为 `/Volumes/ScanMaster Dev/TestResults/ScanMasterAI-V0.1-StorageGate-20260726.xcresult`；DerivedData 和 `.xcresult` 均位于 `ScanMaster Dev`，未写入原项目目录。
- iOS 17.5 Runtime 注册 ID 为 `5F08770C-053D-428B-B79E-E79339758F3C`。新建 iPhone 15 Pro 兼容性模拟器（UDID `E0531B81-E0F8-4AD3-90D2-CCD3EFD18C56`）完成 x86_64 Debug 测试构建、11/11 XCTest 和独立启动冒烟；最终结果包为 `/Volumes/ScanMaster Dev/TestResults/ScanMasterAI-V0.1-iOS17.5-Retry-20260809-0540.xcresult`。该 OCLP 环境没有模拟器 Metal 渲染器，Core Image 自动化走 CPU 软件路径；测试后设备正常关机，未抹除或删除。
- iPhone 14 Pro Max（iOS 18.7.8）已完成 USB 信任、开发者模式、Personal Team 自动签名、arm64 Debug 构建、安装和启动。安装前设备上不存在相同 bundle id，没有覆盖既有应用数据。
- VisionKit 三页和 20 页连续扫描、自动裁边、保存、预览、分享、旋转、滤镜、困难样本及相机权限拒绝/恢复均通过。20 页保存约 3 秒且无卡顿或闪退；一次未统一口径的观测约 5 秒，随后按强制退出后的正常冷启动口径复测三次，均低于 1 秒，满足 3 秒目标。
- 同一份 20 页 A4 文档三档输出分别为高清 `42,090,684` 字节、平衡 `26,865,010` 字节、小文件 `8,735,452` 字节。逐页释放与 Core Image 缓存修复后，20 页高清真机峰值内存由 762.60 MiB 降至 190.20 MiB，降低 75.1%。
- 覆盖安装前后应用容器 96 个文件、ScanMaster 用户数据 56 项的路径、大小和修改时间完全一致。20 页测试文档最终恢复为平衡档，20 页 A4、`26,865,010` 字节。
- 深色模式、最大辅助功能字体、旁白、仅竖屏、前后台中断和强制退出重启恢复均通过。低存储风险没有通过占满磁盘测试，而是以不可写目录故障注入验证旧 PDF 不被替换且临时文件得到清理。

## 安装后验收

- [x] `sw_vers` 显示 Sequoia 15.7.7（24G720）。
- [x] `xcodebuild -version` 显示 Xcode 26.3（17C529）。
- [x] `xcode-select -p` 指向 `/Applications/Xcode.app/Contents/Developer`。
- [x] `xcodebuild -showsdks` 包含 iOS 26.2 SDK。
- [x] `xcrun simctl list runtimes` 包含可用 iOS 26.2 和 iOS 17.5 Runtime。
- [x] 接受 Xcode 许可并完成首次组件安装。
- [x] ScanMasterAI Debug 和 Release 均可构建。
- [x] iOS 26.2 模拟器单元测试最终 11/11 通过。
- [x] iOS 17.5 / iPhone 15 Pro x86_64 模拟器单元测试最终 11/11 通过，独立启动进程保持运行。
- [x] iPhone 真机可进入 VisionKit 文档相机并完成连续扫描、特殊样本和权限恢复验收。
- [x] 强制退出应用后复测正常冷启动至进入相机，三次均低于 1 秒，满足 3 秒性能目标。
- [x] 20 页三档 PDF 体积与高清峰值内存通过；最终峰值 190.20 MiB。
- [x] 深色模式、最大动态字体、旁白、仅竖屏和前后台恢复通过。
- [x] 覆盖安装保持用户数据，模拟存储写入失败不替换旧 PDF。

## 参考

- [Apple：识别 MacBook Pro 机型](https://support.apple.com/zh-cn/108052)
- [Apple：App Store Connect 即将实施的要求](https://developer.apple.com/news/upcoming-requirements/)
- [Apple：Xcode 支持矩阵](https://developer.apple.com/support/xcode/)
- [OpenCore Legacy Patcher：支持机型](https://dortania.github.io/OpenCore-Legacy-Patcher/MODELS.html)
- [OpenCore Legacy Patcher：创建安装器](https://dortania.github.io/OpenCore-Legacy-Patcher/INSTALLER.html)
