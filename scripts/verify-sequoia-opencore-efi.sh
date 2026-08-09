#!/bin/zsh

set -euo pipefail

readonly media="/Volumes/Install macOS Sequoia"
readonly source_root="/Volumes/ScanMaster Dev"
readonly opencore_source="${source_root}/DeveloperInstallers/OpenCore-Build-MacBookPro12,1"
readonly log_directory="${source_root}/DeveloperInstallers/logs"
readonly log_file="${log_directory}/verify-sequoia-opencore-efi-$(date +%Y%m%d-%H%M%S).log"

for required_path in \
    "${media}" \
    "${opencore_source}/EFI/OC/config.plist" \
    "${opencore_source}/System/Library/CoreServices/boot.efi"; do
    if [[ ! -e "${required_path}" ]]; then
        echo "缺少必要路径：${required_path}" >&2
        exit 1
    fi
done

mkdir -p "${log_directory}"
exec > >(tee -a "${log_file}") 2>&1

readonly target_disk="$(diskutil info -plist "${media}" | plutil -extract ParentWholeDisk raw -o - -)"
readonly target_size="$(diskutil info -plist "${target_disk}" | plutil -extract TotalSize raw -o - -)"
readonly target_internal="$(diskutil info -plist "${target_disk}" | plutil -extract Internal raw -o - -)"

if [[ "${target_internal}" != "false" ]] \
    || (( target_size < 120000000000 || target_size > 135000000000 )); then
    echo "安全检查失败：EFI 必须属于约 128 GB 的外置安装盘。" >&2
    echo "当前：${target_disk} / ${target_size} bytes / Internal=${target_internal}" >&2
    exit 1
fi

readonly efi_partition="${target_disk}s1"
readonly source_manifest="$(mktemp -t scanmaster-oc-source)"
readonly target_manifest="$(mktemp -t scanmaster-oc-target)"
efi_mounted=false

cleanup() {
    rm -f "${source_manifest}" "${target_manifest}"
    if [[ "${efi_mounted}" == "true" ]]; then
        sudo diskutil unmount "${efi_partition}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT INT TERM

echo "ScanMaster OpenCore EFI 只读复核"
echo "日志：${log_file}"
echo "目标：/dev/${efi_partition}（所属磁盘 /dev/${target_disk}，${target_size} bytes，external）"
echo
echo "请输入本机管理员密码。输入时终端不会显示字符，这是正常现象。"
sudo -v

echo
echo "[1/4] 只读挂载 EFI…"
sudo diskutil mount readOnly "${efi_partition}"
efi_mounted=true
readonly efi_mount="$(diskutil info -plist "${efi_partition}" | plutil -extract MountPoint raw -o - -)"

echo
echo "[2/4] 生成源和目标逐文件 SHA-256 清单…"
(cd "${opencore_source}" && find EFI/OC System -type f -print0 | sort -z | xargs -0 shasum -a 256) > "${source_manifest}"
(cd "${efi_mount}" && find EFI/OC System -type f -print0 | sort -z | xargs -0 shasum -a 256) > "${target_manifest}"
readonly source_count="$(wc -l < "${source_manifest}" | tr -d ' ')"
readonly target_count="$(wc -l < "${target_manifest}" | tr -d ' ')"
echo "source files=${source_count}"
echo "target files=${target_count}"

echo
echo "[3/4] 比对清单并检查 OpenCore 配置…"
diff -u "${source_manifest}" "${target_manifest}"
plutil -lint "${efi_mount}/EFI/OC/config.plist"
if [[ "${source_count}" != "167" ]] || [[ "${target_count}" != "167" ]]; then
    echo "文件数不是预期的 167。" >&2
    exit 1
fi

echo
echo "[4/4] 安全卸载 EFI…"
sudo diskutil unmount "${efi_partition}"
efi_mounted=false

echo
echo "OPENCORE_EFI_VERIFIED"
echo "167 个文件逐一 SHA-256 完全一致，EFI 已安全卸载。"
