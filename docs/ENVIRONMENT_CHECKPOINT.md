# ScanMaster AI 开发环境检查点

更新时间：2026-08-09

本文件用于 macOS 安装重启后继续执行，不代替写盘前的实时 `diskutil` 核对。

## 磁盘安全边界

| 设备 | 卷 | 用途 | 规则 |
| --- | --- | --- | --- |
| 内置 `/dev/disk1` | Monterey 系统卷组 | 稳定系统与恢复环境 | 严禁擦除或写入 OpenCore |
| 外置 1 TB 盘 HFS+ 分区 | `新加卷` 600 GB | 用户现有数据 | 严禁擦除或用作安装盘 |
| 外置 128 GB 盘 | `Install macOS Sequoia` | Sequoia/OpenCore 启动安装盘 | 已完成写盘，重试时不要选为目标 |
| 外置 APFS 容器现有卷 | `ScanMaster Dev` | 安装器、OCLP 和开发资源归档 | 保留，不再作为 macOS 安装目标 |
| 外置 APFS 容器新卷 | `ScanMaster System` | 空白 Sequoia + Xcode 系统卷 | 唯一 macOS 安装目标 |

设备编号可能在重启或重插后变化。任何擦除或安装操作前，必须再次同时核对容量、卷名、协议和内外置属性。

## 已验证资产

- OCLP 2.4.1 pkg：`/Volumes/ScanMaster Dev/DeveloperInstallers/OpenCore-Patcher-2.4.1.pkg`
- OCLP pkg SHA-256：`a8c0732c197b49337d2b8b970ce57f5151495a2dac300e1f93e802a0261e188d`
- OCLP 应用：`/Volumes/ScanMaster Dev/DeveloperInstallers/OpenCore-Patcher-2.4.1-expanded/OpenCore-Patcher.pkg/Payload/Library/Application Support/Dortania/OpenCore-Patcher.app`
- OCLP 机型识别：`MacBookPro12,1`
- macOS 目标：Sequoia 15.7.7，build `24G720`
- InstallAssistant 预期大小：`15,655,501,868` 字节
- InstallAssistant 下载目录：`/Volumes/ScanMaster Dev/DeveloperInstallers/macOS-Sequoia-15.7.7-24G720`
- InstallAssistant SHA-256：`7e1277990f0a0b0922d75e0e4bdbe293319091610703e31319efbea17f33430a`
- InstallAssistant 信任验收：`signed Apple Software`，Gatekeeper `accepted / Apple Installer`
- 外置安装器应用：`/Volumes/ScanMaster Dev/Applications/Install macOS Sequoia.app`
- 正确 PKGDMG 组装：应用内 `SharedSupport.dmg` 必须是整个 `InstallAssistant.pkg` 的硬链接，大小同为 `15,655,501,868` 字节且文件头为 `xar!`；不能使用包内抽出的 `15,640,198,404` 字节普通 UDIF
- `createinstallmedia` 签名验收：Apple `Software Signing`，x86_64/arm64，严格代码签名通过；但 Sequoia 15.7.7 版本在本机 Monterey 12.7.4 上启动即崩溃（`SIGSEGV` / exit `139`），因此没有再用它重写介质
- SharedSupport 验收：`hdiutil verify` 结果 `VALID`；清单 `OSVersion=15.7.7`、`Build=24G720`
- SharedSupport 核心资产验收：15,629,879,094 字节的系统 ZIP SHA-256 为 `da5423a77073d1bb265c2e61d2eeb8893da817c3a3a6378ba474f6654105e847`，与 Apple MobileAsset 清单逐字节一致
- OpenCore EFI 构建：`/Volumes/ScanMaster Dev/DeveloperInstallers/OpenCore-Build-MacBookPro12,1`
- OpenCore 验收：OCLP 2.4.1 / OpenCore 1.0.4，`MacBookPro12,1` / `Mac-E43C1C25D4880AD6`，167 个文件，OCLP 内置验证和 `plutil` 检查通过

## 当前阶段

1. OCLP pkg 和应用的 Developer ID 签名、Apple 公证已通过。
2. Sequoia `InstallAssistant.pkg` 已从 Apple `swcdn.apple.com` 直接下载到外置卷，精确大小、SHA-256、Apple 签名和 Gatekeeper 检查均通过。
3. 完整 Sequoia 安装器应用已在外置 `ScanMaster Dev/Applications` 组装，SharedSupport 完整性、产品版本和 `createinstallmedia` 签名均已验收。
4. `MacBookPro12,1` 的 OpenCore EFI 已构建、验证并保存在外置卷。
5. 128 GB `/dev/disk3` 已制作为 `Install macOS Sequoia`；Apple 工具报告复制 100% 完成，启动目录 bless 正确，BaseSystem 校验和为 `VALID`。
6. OpenCore 已写入 `disk3s1` EFI，写入前后各 167 个文件，逐文件 SHA-256 完全一致；EFI 已安全卸载。
7. OCLP 2.4.1 官方 pkg 和本检查点已复制到安装盘 `/PostInstall`，便于无网络首次启动后打 Root Patch。
8. 第一次从 OpenCore 启动安装器后，在选择 `ScanMaster Dev` 时收到“安装器已损坏”通用提示，未向目标写入系统。为隔离目标因素，随后新增了空白 `ScanMaster System`。
9. 第二次选择空白 `ScanMaster System` 仍失败。用户拍摄的安装器日志给出了确定错误：`pkgdmg is missing a footer`、`pkgdmg validation has failed`、`OSISVerifyBaseSystemOperation` 和 `com.apple.OSInstallerSetup.error Code=255`。网络时钟 `NSURLErrorDomain Code=-1009` 是离线伴随信息，不是主错误。
10. 根因是此前手工组装时误把包内抽出的普通 `SharedSupport.dmg`（15,640,198,404 字节、文件头为 BSD/UDIF）放进安装器。Apple 的 `InstallAssistant.pkg` 实际是可同时被 XAR 和 UDIF 识别的 PKGDMG；OCLP 2.4.1 官方安装流程会把整个 `InstallAssistant.pkg` 原文件链接为应用的 `SharedSupport.dmg`。普通 DMG 虽能通过 `hdiutil verify`，但缺少 OSInstaller 要求的 PKGDMG 封装信息。
11. 外置安装器应用已按官方脚本语义修正：`InstallAssistant.pkg` 与应用内 `SharedSupport.dmg` 当前同为 inode `434`、link count `2`、大小 `15,655,501,868` 字节，`cmp` 完全一致，`hdiutil imageinfo` 可将该双格式文件识别为有效只读 UDIF。
12. OCLP 2.4.1 已通过官方 pkg 正式安装到 Monterey，Privileged Helper Tool 存在；OpenCore NVRAM 标记 `OCLP-Model=MacBookPro12,1`、`OCLP-Version=2.4.1`、`revpatch=sbvmm` 均已确认。
13. 已在同一 423.9 GB APFS 容器内新增空白 `ScanMaster System`，仅占约 655 KB、共享约 374.9 GB 可用空间。下一次只向此空白卷安装；资源继续留在 `ScanMaster Dev`。
14. 尝试用修正后的安装器重新执行 `createinstallmedia` 时，该 Apple 工具在 Monterey 12.7.4 上启动即崩溃；系统崩溃报告确认 `EXC_BAD_ACCESS / SIGSEGV`，命令退出码为 `139`，并非目标盘或管理员认证错误。
15. 由于 128 GB 介质上的 BaseSystem、RecoveryOS、bless 目录和 OpenCore 均已正确生成，已采用带回滚保护的原位修复：先把完整 `InstallAssistant.pkg` 复制到同卷临时文件，验证 SHA-256、文件头、`cmp` 和 `hdiutil verify`，再原子替换旧 `SharedSupport.dmg`。
16. 原位修复已成功完成。启动盘上的 `SharedSupport.dmg` 当前为 `15,655,501,868` 字节、文件头 `xar!`，与 Apple `InstallAssistant.pkg` 得到 `CMP=IDENTICAL`，替换前后映像校验均为 `VALID`；旧的 15,640,198,404 字节文件和临时副本均已移除。
17. 启动盘 `BaseSystem.dmg` 再次校验为 `VALID`，`.IAPhysicalMedia` 存在，bless 仍指向 `System/Library/CoreServices/boot.efi`；OCLP pkg、检查点和诊断脚本已刷新到 `PostInstall`。
18. 已用管理员授权只读挂载 128 GB 安装盘 EFI：源和目标均为 167 个文件，逐文件 SHA-256 清单完全一致，`EFI/OC/config.plist` 通过 `plutil`；最终标记为 `OPENCORE_EFI_VERIFIED`，随后 EFI 已安全卸载。
19. 重启前最终审计确认：128 GB 安装盘当前为外置 `/dev/disk2`，1 TB 数据/开发盘为外置 `/dev/disk3`；设备编号仅记录本次状态，重启后仍须按容量和卷名识别。唯一安装目标 `ScanMaster System` 仍为空白 APFS 卷，仅约 896 KB，可用容器空间约 374.9 GB。
20. macOS Sequoia 已成功安装到外置卷组：System 卷 `ScanMaster System`、Data 卷 `ScanMaster System - 数据`、Preboot、Recovery 和 VM 均已生成。系统文件确认版本为 `15.7.7`、build `24G720`。
21. `ScanMaster System` 已生成不可清除的密封系统快照 `7E830390-F768-41B3-98BC-B3EEA1A615AF`，APFS bless 正确指向该快照及对应 Preboot；`bless --getBoot` 返回外置 System 卷。Data 卷存在 `.AppleSetupDone`，用户 `andy` 已创建。
22. 安装完成后的当前会话仍启动在内置 Monterey 12.7.4，而非外置 Sequoia。下一步需再次重启，选择 `EFI Boot`，再在 OpenCore 中选择 `ScanMaster System`（不再选择安装器）；进入 Sequoia 后立即安装 OCLP 2.4.1 并执行 Post-Install Root Patch。
23. `ChatGPT.app` 已从 Monterey `/Applications` 物理复制到 Sequoia Data 卷 `/Applications`，没有移动原包、没有建立指向 Monterey 的软链接。源和目标版本均为 `26.707.72221`、bundle id `com.openai.codex`、大小约 1.3 GB；逐文件哈希/软链接清单一致，目标严格代码签名通过。
24. ChatGPT 仅复制应用包。Sequoia 用户 `andy` 下的 `.codex`、Application Support、Caches、Preferences、HTTPStorages、WebKit 和 Containers 等 `com.openai.codex` 数据路径均保持不存在，因此没有复制 Monterey 登录令牌、会话、缓存或 Codex 账户资料；首次启动需重新登录。
25. `ClashX.app` 已物理复制到 Sequoia，版本 `1.139.0`、bundle id `com.west2online.ClashX`、大小约 99 MB，严格代码签名通过。`~/.config/clash`（6 个文件）、`~/Library/Application Support/com.west2online.ClashX`（61 个文件）、偏好 plist 和 `com.codex.autostart.clashx` 自动启动项均已复制并逐文件验证。
26. Sequoia 中上述两个应用和 ClashX 用户数据已统一设置为数字 UID 501/GID 20；在 Sequoia 用户数据库中该身份属于 `andy`。递归所有权检查无例外。Monterey 两个应用及 ClashX 源数据仍存在且迁移前后清单一致。
27. Monterey 与 Sequoia 的 `/Library/Preferences/SystemConfiguration/preferences.plist` 没有互相复制或改写，当前 SHA-256 分别为 `4c393c5ab12788c853ca6b1d4cbd230b5d682b77ef7466ee13125e3a910e1671` 与 `874ed8e3fd52c06ae5d3cb326a10238d9f542eaee30f1540a1e34ac33bc00025`，系统代理设置保持各自独立。ClashX 应用包内含签名的 ProxyConfigHelper；未离线复制 Monterey 的 root helper/LaunchDaemon，首次在 Sequoia 启用系统代理时由该系统重新授权安装。
28. 已从新 EFI/OpenCore 启动外置 `ScanMaster System`，运行系统确认为 macOS Sequoia 15.7.7（24G720）、Intel `x86_64`。OCLP 2.4.1 Post-Install Root Patch 已完成并重启；Intel Iris Graphics 6100、1536 MB VRAM、Metal 2、Broadwell 图形驱动和 FaceTime 相机均已识别。
29. `/Applications/Xcode.app` 已安装 Xcode 26.3（17C529），应用为 x86_64/arm64 Universal，深度代码签名和 Gatekeeper 验收通过；许可、首次启动组件及 `xcode-select` 均已完成。
30. Xcode 自带 iOS 26.2 Device/Simulator SDK。iOS 26.2 Simulator Runtime（23C54）已从 Apple 下载、校验并导入，注册 ID 为 `788AE7F1-D7A3-4883-A58D-B56A8A7026D5`；归档 DMG SHA-256 为 `27dd2a164b0eb553c8648823c7e29d1bdac75d26325019e01229c17ec0138334`。
31. ScanMasterAI V0.1 已在 iPhone 17 Pro / iOS 26.2 模拟器完成 Debug 和 Release 构建，二者均成功。修复了 `ScanEditorViewModel` 的一处存储属性初始化顺序错误，以及两个冒烟脚本对含空格卷路径的参数引用错误；没有加入 OCR 或任何 V0.5+ 功能。
32. V0.1 XCTest 共 9 项，9 项通过、0 失败、0 跳过；核心冒烟测试 8/8、架构集成冒烟测试 16/16 通过。结果包保存在 `/Volumes/ScanMaster Dev/TestResults/ScanMasterAI-V0.1-20260721-0034.xcresult`。
33. Debug 应用已在原 iPhone 17 Pro 模拟器完成安装与首页启动冒烟验收，进程正常运行；首页截图保存为 `/Volumes/ScanMaster Dev/TestResults/ScanMasterAI-V0.1-home.png`。验收后关闭模拟器以释放 8 GB Intel 主机资源。
34. iPhone 14 Pro Max（iPhone15,3，iOS 18.7.8 / 22H352）已通过 USB 连接、解锁、信任并开启开发者模式。Xcode Personal Team 自动签名成功，V0.1 Debug arm64 真机构建、安装和首次启动均成功；安装前确认设备上不存在 `com.scanmasterai.app`，没有覆盖既有应用数据。
35. 真机 VisionKit 验收已完成：进入相机、自动裁边、三页连续扫描、20 页连续扫描、保存、PDF 预览、系统分享、旋转和五种滤镜均正常。20 页全部保留，保存约 3 秒，无卡顿或闪退。
36. 低光、倾斜、阴影、狭长票据和中文密集页面的裁边均正常；关闭相机权限后显示权限提示且不崩溃，重新授权后功能恢复。一次未统一口径的 20 页测试前进入相机约 5 秒；随后按“强制退出、等待、点击应用图标、首页立即点击扫描、相机可用时停止”的正常冷启动口径复测三次，三次均低于 1 秒，满足产品说明的 3 秒目标。V0.1 环境与核心功能验收完成，未开始 V0.5。
37. 同一份 20 页 A4 真机文档完成三档 PDF 实测：高清 `42,090,684` 字节、平衡 `26,865,010` 字节、小文件 `8,735,452` 字节，档位大小关系正确，页数和页面尺寸均保持不变。
38. 20 页高清保存的初始峰值内存为 `799,639,136` 字节（762.60 MiB）。PDF 改为逐页自动释放与同目录临时文件原子替换、Core Image 禁用中间结果缓存、保存/更新按页建立自动释放池后，最终真机峰值降至 `199,443,608` 字节（190.20 MiB），降低 `600,195,528` 字节（75.1%）；50 个采样点均未超过 200 MiB，应用未退出或崩溃。
39. 两次覆盖安装前后均导出应用容器清单：容器保持 96 个文件，ScanMaster 用户数据保持 56 项，逐项路径、大小和修改时间一致。既有三页文档与 20 页压力测试文档均保留；20 页文档最终恢复为平衡档，确认为 20 页 A4、`26,865,010` 字节，SHA-256 为 `042b1f52f13a0b3f971c5ee1836af2cdf1bc9283c39ed9e6488245a616a2cb7e`。
40. 深色模式、最大辅助功能字体、旁白和竖屏锁定已在真机完成。文字、图标、按钮和背景正常，无截断、重叠、不可聚焦控件或闪退；V0.1 按 Info.plist 设计只支持竖屏，横置时保持竖屏且无异常。
41. 前后台中断测试中，未保存的两页在离开应用约 10 秒后仍完整保留，相机和编辑流程可继续；完成状态下强制退出并重新启动的恢复流程已执行，未报告文档或预览异常。
42. 为避免人为占满 iPhone 或 Mac 磁盘，以不可写目录注入底层存储写入失败。测试得到预期的 `Permission denied`，旧 PDF 内容未被替换，临时 PDF 已清理。最终 iOS 26.2 模拟器 XCTest 为 11/11 通过、0 失败、0 跳过，结果包为 `/Volumes/ScanMaster Dev/TestResults/ScanMasterAI-V0.1-StorageGate-20260726.xcresult`；核心冒烟 8/8、架构冒烟 16/16 和 plist 校验再次通过。
43. 最终 Release 通用 iOS Simulator 构建成功并通过 `validate-for-store` 浅层包校验；最终 Debug arm64 真机包使用 Personal Team 签名且构建成功。所有内存、PDF 和安装清单证据集中保存在 `/Volumes/ScanMaster Dev/TestResults/ScanMasterAI-V0.1-DeviceAudit-20260726`。没有开发 OCR 或任何 V0.5+ 功能。
44. 为补齐 Deployment Target 对应的本机覆盖，已从 Apple Developer 下载并导入官方 iOS 17.5 Simulator Runtime（21F79，arm64/x86_64，注册 ID `5F08770C-053D-428B-B79E-E79339758F3C`）。DMG 为 `7,336,630,623` 字节，`hdiutil verify` 结果 `VALID`，SHA-256 为 `8021fac54f569def395a0275fd5bb704a85f325b63a4d0b7fba9a4d00e57fd00`，归档在 `/Volumes/ScanMaster Dev/DeveloperInstallers/iOS-17.5-Simulator-Runtime/iOS_17.5_Simulator_Runtime.dmg`。新建的 `ScanMaster iPhone 15 Pro iOS 17.5`（UDID `E0531B81-E0F8-4AD3-90D2-CCD3EFD18C56`）在首次迁移后以非抹除方式重启，随后 V0.1 x86_64 XCTest 11/11 通过、0 失败、0 跳过；结果包为 `/Volumes/ScanMaster Dev/TestResults/ScanMasterAI-V0.1-iOS17.5-Retry-20260809-0540.xcresult`。独立启动返回有效 PID 且进程保持运行；该 OCLP 模拟器没有 Metal，Core Image 使用软件渲染，截图不作为 UI 视觉验收。测试后设备已正常关机且未删除。未改变产品源码、真机用户数据或版本范围。

## 后续门禁

1. 启动盘上的 `SharedSupport.dmg` 必须保持 `15,655,501,868` 字节、`xar!` 文件头，并与已验签 Apple `InstallAssistant.pkg` 逐字节一致。
2. 安装器应用和资源必须保留在外置卷，不占用内置盘的约 15 GB 空间。
3. 启动前必须重新确认 `Install macOS Sequoia` 是独立约 128 GB 外置盘；本次 EFI/OpenCore 167 文件哈希清单已经确认无差异并已卸载。
4. 所有管理员认证只由用户在 macOS 标准提示框中输入，不在命令、日志或文件中传递密码。
5. 系统安装只选择空白 `ScanMaster System`；`ScanMaster Dev` 只保存资源。在任何重启前先更新本检查点。

## 首次安装启动顺序

1. 关闭应用并重启 Mac，从黑屏开始持续按住 Option（⌥）。
2. 在 Apple 启动选择器选择 128 GB 安装盘的 `EFI Boot`。
3. 进入 OpenCore 选择器后选择 `Install macOS Sequoia`。
4. 在 macOS 安装器中只选择空白 APFS 卷 `ScanMaster System`。严禁选择 `ScanMaster Dev`、内置 Macintosh HD、600 GB `新加卷` 或 128 GB 安装盘。
5. 安装期间会多次重启；如果自动回到 Monterey，重启按 Option 选 `EFI Boot`，再在 OpenCore 中选择 Sequoia 安装/系统卷。
6. 首次进入 Sequoia 后，从安装盘 `PostInstall/OpenCore-Patcher-2.4.1.pkg` 安装 OCLP，执行 Post-Install Root Patch，然后重启。

该精简 InstallAssistant 界面没有“实用工具 → 终端”。若再次失败，应像第二次一样打开“安装器日志”并拍摄包含首条 `Operation failed` 前后内容的清晰照片，不再要求查找不存在的终端菜单。

## Sequoia 上的验收顺序

1. [x] 从 OpenCore 启动 `ScanMaster System`，确认 `sw_vers` 为 Sequoia 15.7.7；完成 OCLP Post-Install Root Patch 并确认图形、相机和基础硬件识别正常。
2. [x] 安装 Xcode 26.3，接受许可并完成首次组件安装。
3. [x] 确认 iOS 26.2 SDK、iOS 26.2 Simulator Runtime 和 iOS 17.5 兼容性 Runtime 可用。
4. [x] 将 Simulator Runtime、安装归档、DerivedData 和测试结果保留在外置开发/Sequoia 卷，不写入项目源码目录。
5. [x] 执行 ScanMasterAI Debug/Release 构建，以及 iOS 26.2 与 iOS 17.5 XCTest。
6. [x] 连接 iPhone 真机，完成 VisionKit 相机、连续扫描、特殊样本和权限恢复验收。
7. [x] 强制退出应用后按正常冷启动口径复测三次，均低于 1 秒，满足“3 秒内进入相机”目标。
8. [x] 完成三档 20 页 PDF 体积、20 页高清峰值内存与覆盖安装数据保持验收。
9. [x] 完成深色模式、最大动态字体、旁白和仅竖屏行为验收。
10. [x] 完成前后台切换、强制退出重启与模拟存储写入失败恢复验收。
