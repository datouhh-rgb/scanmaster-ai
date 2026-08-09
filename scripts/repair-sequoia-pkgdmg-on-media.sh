#!/bin/zsh

set -euo pipefail

readonly media="/Volumes/Install macOS Sequoia"
readonly source_root="/Volumes/ScanMaster Dev"
readonly source_pkg="${source_root}/DeveloperInstallers/macOS-Sequoia-15.7.7-24G720/InstallAssistant.pkg"
readonly expected_sha256="7e1277990f0a0b0922d75e0e4bdbe293319091610703e31319efbea17f33430a"
readonly target="${media}/Install macOS Sequoia.app/Contents/SharedSupport/SharedSupport.dmg"
readonly temporary="${target}.scanmaster-new"
readonly backup="${target}.scanmaster-bad"
readonly checkpoint="/Users/liuyanan/Documents/编程/docs/ENVIRONMENT_CHECKPOINT.md"
readonly diagnostic_script="/Users/liuyanan/Documents/编程/scripts/capture-sequoia-installer-diagnostics.sh"
readonly oclp_pkg="${source_root}/DeveloperInstallers/OpenCore-Patcher-2.4.1.pkg"
readonly log_directory="${source_root}/DeveloperInstallers/logs"
readonly log_file="${log_directory}/repair-sequoia-pkgdmg-$(date +%Y%m%d-%H%M%S).log"

for required_path in \
    "${media}" \
    "${source_pkg}" \
    "${target}" \
    "${checkpoint}" \
    "${diagnostic_script}" \
    "${oclp_pkg}"; do
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
readonly target_writable="$(diskutil info -plist "${media}" | plutil -extract WritableVolume raw -o - -)"

if [[ "${target_internal}" != "false" ]] \
    || [[ "${target_writable}" != "true" ]] \
    || (( target_size < 120000000000 || target_size > 135000000000 )); then
    echo "安全检查失败：目标必须是约 128 GB 的可写外置盘。" >&2
    echo "当前：${target_disk} / ${target_size} bytes / Internal=${target_internal} / Writable=${target_writable}" >&2
    exit 1
fi

readonly source_size="$(stat -f '%z' "${source_pkg}")"
readonly target_size_before="$(stat -f '%z' "${target}")"
readonly available_kib="$(df -k "${media}" | awk 'NR == 2 { print $4 }')"

if (( available_kib * 1024 < source_size + 1073741824 )); then
    echo "空间不足：原子替换至少需要源文件大小加 1 GiB 余量。" >&2
    exit 1
fi

echo "ScanMaster Sequoia PKGDMG 原位修复"
echo "日志：${log_file}"
echo "目标：/dev/${target_disk} (${target_size} bytes, external)"
echo "旧文件：${target_size_before} bytes"
echo "新文件：${source_size} bytes"
echo

echo "[1/6] 验证 Apple 原包 SHA-256 与 PKGDMG footer…"
readonly actual_sha256="$(shasum -a 256 "${source_pkg}" | awk '{ print $1 }')"
if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
    echo "Apple 原包 SHA-256 不匹配：${actual_sha256}" >&2
    exit 1
fi
/usr/bin/hdiutil verify "${source_pkg}"

echo
echo "[2/6] 复制到同一卷的临时文件（保留旧文件，便于回滚）…"
rm -f "${temporary}"
/usr/bin/rsync -a --progress "${source_pkg}" "${temporary}"

echo
echo "[3/6] 在替换前逐字节验证临时文件…"
stat -f 'temporary size=%z %N' "${temporary}"
readonly header="$(xxd -p -l 4 "${temporary}")"
if [[ "${header}" != "78617221" ]]; then
    echo "临时文件缺少 xar! PKGDMG 文件头：${header}" >&2
    exit 1
fi
cmp "${source_pkg}" "${temporary}"
/usr/bin/hdiutil verify "${temporary}"

echo
echo "[4/6] 原子切换 SharedSupport.dmg…"
rm -f "${backup}"
mv "${target}" "${backup}"
if ! mv "${temporary}" "${target}"; then
    mv "${backup}" "${target}"
    echo "切换失败，旧文件已恢复。" >&2
    exit 1
fi

if ! cmp "${source_pkg}" "${target}"; then
    rm -f "${target}"
    mv "${backup}" "${target}"
    echo "替换后校验失败，旧文件已恢复。" >&2
    exit 1
fi
/usr/bin/hdiutil verify "${target}"
rm -f "${backup}"

echo
echo "[5/6] 刷新离线工具和环境检查点…"
mkdir -p "${media}/PostInstall"
cp -p "${oclp_pkg}" "${media}/PostInstall/"
cp -p "${checkpoint}" "${media}/PostInstall/"
cp -p "${diagnostic_script}" "${media}/PostInstall/"

echo
echo "[6/6] 验证启动盘基础系统和物理介质标记…"
/usr/bin/hdiutil verify "${media}/BaseSystem/BaseSystem.dmg"
test -e "${media}/.IAPhysicalMedia"
/usr/sbin/bless --info "${media}"
sync

echo
echo "MEDIA_PKGDMG_REPAIR_READY"
echo "SharedSupport.dmg 已与 Apple InstallAssistant.pkg 逐字节一致。"
