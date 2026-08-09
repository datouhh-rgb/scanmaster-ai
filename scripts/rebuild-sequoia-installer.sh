#!/bin/zsh

set -euo pipefail

readonly source_root="/Volumes/ScanMaster Dev"
readonly installer_volume="/Volumes/Install macOS Sequoia"
readonly source_app="${source_root}/Applications/Install macOS Sequoia.app"
readonly createinstallmedia="${source_app}/Contents/Resources/createinstallmedia"
readonly source_pkg="${source_root}/DeveloperInstallers/macOS-Sequoia-15.7.7-24G720/InstallAssistant.pkg"
readonly source_shared_support="${source_app}/Contents/SharedSupport/SharedSupport.dmg"
readonly opencore_source="${source_root}/DeveloperInstallers/OpenCore-Build-MacBookPro12,1"
readonly oclp_pkg="${source_root}/DeveloperInstallers/OpenCore-Patcher-2.4.1.pkg"
readonly checkpoint="/Users/liuyanan/Documents/编程/docs/ENVIRONMENT_CHECKPOINT.md"
readonly diagnostic_script="/Users/liuyanan/Documents/编程/scripts/capture-sequoia-installer-diagnostics.sh"
readonly log_directory="${source_root}/DeveloperInstallers/logs"
readonly log_file="${log_directory}/rebuild-sequoia-installer-$(date +%Y%m%d-%H%M%S).log"

for required_path in \
    "${installer_volume}" \
    "${createinstallmedia}" \
    "${source_pkg}" \
    "${source_shared_support}" \
    "${opencore_source}/EFI/OC/config.plist" \
    "${opencore_source}/System/Library/CoreServices/boot.efi" \
    "${oclp_pkg}" \
    "${checkpoint}" \
    "${diagnostic_script}"; do
    if [[ ! -e "${required_path}" ]]; then
        echo "缺少必要路径：${required_path}" >&2
        exit 1
    fi
done

mkdir -p "${log_directory}"
exec > >(tee -a "${log_file}") 2>&1

readonly target_disk="$(diskutil info -plist "${installer_volume}" | plutil -extract ParentWholeDisk raw -o - -)"
readonly target_size="$(diskutil info -plist "${target_disk}" | plutil -extract TotalSize raw -o - -)"
readonly target_internal="$(diskutil info -plist "${target_disk}" | plutil -extract Internal raw -o - -)"

if [[ "${target_internal}" != "false" ]] || (( target_size < 120000000000 || target_size > 135000000000 )); then
    echo "安全检查失败：目标必须是约 128 GB 的外置盘，当前为 ${target_disk} / ${target_size} 字节 / Internal=${target_internal}" >&2
    exit 1
fi

readonly pkg_inode="$(stat -f '%i' "${source_pkg}")"
readonly shared_inode="$(stat -f '%i' "${source_shared_support}")"
readonly pkg_size="$(stat -f '%z' "${source_pkg}")"
readonly shared_size="$(stat -f '%z' "${source_shared_support}")"

if [[ "${pkg_inode}" != "${shared_inode}" ]] || [[ "${pkg_size}" != "${shared_size}" ]]; then
    echo "安全检查失败：SharedSupport 不是完整 InstallAssistant.pkg 的硬链接。" >&2
    exit 1
fi

echo "ScanMaster Sequoia 启动盘重建"
echo "日志：${log_file}"
echo "目标：/dev/${target_disk} (${target_size} bytes, external)"
echo "PKGDMG：inode=${pkg_inode}, size=${pkg_size}"
echo
echo "请输入本机管理员密码。输入时终端不会显示字符，这是正常现象。"
sudo -v

echo
echo "[1/7] 使用修正后的 Apple PKGDMG 重建 128 GB 启动盘…"
sudo "${createinstallmedia}" --volume "${installer_volume}" --nointeraction

if [[ ! -d "${installer_volume}" ]]; then
    echo "createinstallmedia 完成后未找到安装卷。" >&2
    exit 1
fi

echo
echo "[2/7] 恢复离线安装包、检查点和诊断脚本…"
mkdir -p "${installer_volume}/PostInstall"
cp -p "${oclp_pkg}" "${installer_volume}/PostInstall/"
cp -p "${checkpoint}" "${installer_volume}/PostInstall/"
cp -p "${diagnostic_script}" "${installer_volume}/PostInstall/"

echo
echo "[3/7] 将 MacBookPro12,1 OpenCore 写回 EFI…"
readonly efi_partition="${target_disk}s1"
sudo diskutil mount "${efi_partition}"
readonly efi_mount="$(diskutil info -plist "${efi_partition}" | plutil -extract MountPoint raw -o - -)"

sudo rm -rf "${efi_mount}/EFI/OC" "${efi_mount}/System"
sudo mkdir -p "${efi_mount}/EFI"
sudo cp -r "${opencore_source}/EFI/OC" "${efi_mount}/EFI/OC"
sudo cp -r "${opencore_source}/System" "${efi_mount}/System"

echo
echo "[4/7] 逐文件核对 OpenCore…"
readonly source_manifest="$(mktemp -t scanmaster-oc-source)"
readonly target_manifest="$(mktemp -t scanmaster-oc-target)"
trap 'rm -f "${source_manifest}" "${target_manifest}"' EXIT

(cd "${opencore_source}" && find EFI/OC System -type f -print0 | sort -z | xargs -0 shasum -a 256) > "${source_manifest}"
(cd "${efi_mount}" && find EFI/OC System -type f -print0 | sort -z | xargs -0 shasum -a 256) > "${target_manifest}"
diff -u "${source_manifest}" "${target_manifest}"
echo "OpenCore files: $(wc -l < "${target_manifest}" | tr -d ' ')"

echo
echo "[5/7] 验证启动盘上的 PKGDMG 与 Apple 原包完全一致…"
readonly media_shared_support="${installer_volume}/Install macOS Sequoia.app/Contents/SharedSupport/SharedSupport.dmg"
stat -f 'size=%z %N' "${media_shared_support}"
cmp "${source_pkg}" "${media_shared_support}"
/usr/bin/hdiutil verify "${media_shared_support}"

echo
echo "[6/7] 验证 BaseSystem 和 bless 信息…"
/usr/bin/hdiutil verify "${installer_volume}/BaseSystem/BaseSystem.dmg"
/usr/sbin/bless --info "${installer_volume}"
plutil -p "${installer_volume}/.IAPhysicalMedia"

echo
echo "[7/7] 安全卸载 EFI 并刷新写缓存…"
sudo diskutil unmount "${efi_partition}"
sync

echo
echo "REBUILD_READY"
echo "PKGDMG footer 已恢复，启动盘和 OpenCore 均已验证。"
