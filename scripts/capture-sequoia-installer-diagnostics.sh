#!/bin/bash

set -u

readonly media_root="/Volumes/Install macOS Sequoia"
readonly output_root="${media_root}/PostInstall/diagnostics"
readonly timestamp="$(date '+%Y%m%d-%H%M%S')"
readonly report_path="${output_root}/installer-diagnostics-${timestamp}.txt"
readonly install_log_path="${output_root}/install-${timestamp}.log"

if [[ ! -d "${media_root}" ]]; then
    echo "未找到安装盘：${media_root}" >&2
    exit 1
fi

mkdir -p "${output_root}"

{
    echo "ScanMaster Sequoia installer diagnostics"
    echo "Captured: $(date)"
    echo
    echo "== sw_vers =="
    sw_vers 2>&1 || true
    echo
    echo "== diskutil list =="
    diskutil list 2>&1 || true
    echo
    echo "== diskutil APFS =="
    diskutil apfs list 2>&1 || true
    echo
    echo "== NVRAM OCLP markers =="
    nvram '4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:OCLP-Model' 2>&1 || true
    nvram '4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:OCLP-Version' 2>&1 || true
    nvram '4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:revpatch' 2>&1 || true
    nvram boot-args 2>&1 || true
} > "${report_path}"

if [[ -f /var/log/install.log ]]; then
    cp -p /var/log/install.log "${install_log_path}"
else
    echo "当前环境没有 /var/log/install.log" >> "${report_path}"
fi

sync
echo "DIAGNOSTICS_CAPTURED"
echo "${report_path}"
[[ -f "${install_log_path}" ]] && echo "${install_log_path}"
