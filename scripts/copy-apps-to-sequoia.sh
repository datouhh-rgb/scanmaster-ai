#!/bin/zsh

set -euo pipefail
export LANG=C
export LC_ALL=C
umask 022

readonly source_home="/Users/liuyanan"
readonly target_data="/Volumes/ScanMaster System - 数据"
readonly target_home="${target_data}/Users/andy"
readonly target_uid="$(stat -f '%u' "${target_home}")"
readonly target_gid="$(stat -f '%g' "${target_home}")"
readonly log_directory="/Volumes/ScanMaster Dev/DeveloperInstallers/logs"
readonly log_file="${log_directory}/copy-apps-to-sequoia-$(date +%Y%m%d-%H%M%S).log"

readonly chatgpt_source="/Applications/ChatGPT.app"
readonly clashx_source="/Applications/ClashX.app"
readonly chatgpt_target="${target_data}/Applications/ChatGPT.app"
readonly clashx_target="${target_data}/Applications/ClashX.app"

readonly clash_config_source="${source_home}/.config/clash"
readonly clash_support_source="${source_home}/Library/Application Support/com.west2online.ClashX"
readonly clash_preferences_source="${source_home}/Library/Preferences/com.west2online.ClashX.plist"
readonly clash_launch_agent_source="${source_home}/Library/LaunchAgents/com.codex.autostart.clashx.plist"

readonly clash_config_target="${target_home}/.config/clash"
readonly clash_support_target="${target_home}/Library/Application Support/com.west2online.ClashX"
readonly clash_preferences_target="${target_home}/Library/Preferences/com.west2online.ClashX.plist"
readonly clash_launch_agent_target="${target_home}/Library/LaunchAgents/com.codex.autostart.clashx.plist"

readonly source_proxy_db="/Library/Preferences/SystemConfiguration/preferences.plist"
readonly target_proxy_db="${target_data}/Library/Preferences/SystemConfiguration/preferences.plist"

readonly -a chatgpt_user_data=(
    "${target_home}/.codex"
    "${target_home}/Library/Application Support/com.openai.codex"
    "${target_home}/Library/Caches/com.openai.codex"
    "${target_home}/Library/Preferences/com.openai.codex.plist"
    "${target_home}/Library/HTTPStorages/com.openai.codex"
    "${target_home}/Library/WebKit/com.openai.codex"
    "${target_home}/Library/Containers/com.openai.codex"
    "${target_home}/Library/Saved Application State/com.openai.codex.savedState"
)

for required_path in \
    "${chatgpt_source}" \
    "${clashx_source}" \
    "${clash_config_source}" \
    "${clash_support_source}" \
    "${clash_preferences_source}" \
    "${clash_launch_agent_source}" \
    "${target_data}/Applications" \
    "${target_home}/Library" \
    "${source_proxy_db}" \
    "${target_proxy_db}"; do
    if [[ ! -e "${required_path}" ]]; then
        echo "Missing required path: ${required_path}" >&2
        exit 1
    fi
done

if [[ "$(sw_vers -productVersion)" != 12.* ]]; then
    echo "Safety check failed: this migration must run from Monterey." >&2
    exit 1
fi

readonly target_volume_name="$(diskutil info -plist "${target_data}" | plutil -extract VolumeName raw -o - -)"
readonly target_internal="$(diskutil info -plist "${target_data}" | plutil -extract Internal raw -o - -)"
readonly target_writable="$(diskutil info -plist "${target_data}" | plutil -extract WritableVolume raw -o - -)"

if [[ "${target_volume_name}" != "ScanMaster System - 数据" ]] \
    || [[ "${target_internal}" != "false" ]] \
    || [[ "${target_writable}" != "true" ]] \
    || [[ "${target_uid}:${target_gid}" != "501:20" ]]; then
    echo "Safety check failed for Sequoia Data volume or andy ownership." >&2
    echo "Volume=${target_volume_name} Internal=${target_internal} Writable=${target_writable} UID:GID=${target_uid}:${target_gid}" >&2
    exit 1
fi

for source_app in "${chatgpt_source}" "${clashx_source}"; do
    if [[ -L "${source_app}" ]]; then
        echo "Source app must be a physical bundle, not a symbolic link: ${source_app}" >&2
        exit 1
    fi
done

for target_path in \
    "${chatgpt_target}" \
    "${clashx_target}" \
    "${clash_config_target}" \
    "${clash_support_target}" \
    "${clash_preferences_target}" \
    "${clash_launch_agent_target}"; do
    if [[ -e "${target_path}" || -L "${target_path}" ]]; then
        echo "Refusing to overwrite an existing Sequoia path: ${target_path}" >&2
        exit 1
    fi
done

for private_path in "${chatgpt_user_data[@]}"; do
    if [[ -e "${private_path}" || -L "${private_path}" ]]; then
        echo "Refusing migration because ChatGPT user data already exists: ${private_path}" >&2
        exit 1
    fi
done

mkdir -p "${log_directory}"
exec > >(tee -a "${log_file}") 2>&1

manifest_tree() {
    local root="$1"
    (
        cd "${root}"
        find . -type f -print0 | sort -z | xargs -0 shasum -a 256
        find . -type l -print0 | sort -z | while IFS= read -r -d '' link_path; do
            printf 'LINK  %s -> %s\n' "${link_path}" "$(readlink "${link_path}")"
        done
    )
}

copy_tree_atomic() {
    local source="$1"
    local target="$2"
    local temporary="${target}.scanmaster-copying"
    rm -rf "${temporary}"
    mkdir -p "${target:h}"
    /usr/bin/ditto --rsrc --extattr --acl "${source}" "${temporary}"
    chown -R "${target_uid}:${target_gid}" "${temporary}"
    mv "${temporary}" "${target}"
}

copy_file_atomic() {
    local source="$1"
    local target="$2"
    local temporary="${target}.scanmaster-copying"
    rm -f "${temporary}"
    mkdir -p "${target:h}"
    /usr/bin/ditto --rsrc --extattr --acl "${source}" "${temporary}"
    chown "${target_uid}:${target_gid}" "${temporary}"
    mv "${temporary}" "${target}"
}

readonly workspace="$(mktemp -d -t scanmaster-app-copy)"
trap 'rm -rf "${workspace}"' EXIT INT TERM

echo "ScanMaster Sequoia app and ClashX configuration copy"
echo "Log: ${log_file}"
echo "Target user: andy (${target_uid}:${target_gid})"
echo "Source remains on Monterey; destination is a physical copy."
echo

echo "[1/8] Record source manifests and independent proxy database hashes..."
manifest_tree "${chatgpt_source}" > "${workspace}/chatgpt-source-before"
manifest_tree "${clashx_source}" > "${workspace}/clashx-source-before"
manifest_tree "${clash_config_source}" > "${workspace}/clash-config-source-before"
manifest_tree "${clash_support_source}" > "${workspace}/clash-support-source-before"
shasum -a 256 "${clash_preferences_source}" > "${workspace}/clash-preferences-source-before"
shasum -a 256 "${clash_launch_agent_source}" > "${workspace}/clash-launch-source-before"
readonly source_proxy_hash_before="$(shasum -a 256 "${source_proxy_db}" | awk '{print $1}')"
readonly target_proxy_hash_before="$(shasum -a 256 "${target_proxy_db}" | awk '{print $1}')"

echo
echo "[2/8] Copy ChatGPT.app only (no account data, token, cache, or ~/.codex)..."
copy_tree_atomic "${chatgpt_source}" "${chatgpt_target}"

echo
echo "[3/8] Copy ClashX.app as an independent physical bundle..."
copy_tree_atomic "${clashx_source}" "${clashx_target}"

echo
echo "[4/8] Copy ClashX configuration, application support, preferences, and launch agent..."
copy_tree_atomic "${clash_config_source}" "${clash_config_target}"
copy_tree_atomic "${clash_support_source}" "${clash_support_target}"
copy_file_atomic "${clash_preferences_source}" "${clash_preferences_target}"
copy_file_atomic "${clash_launch_agent_source}" "${clash_launch_agent_target}"

echo
echo "[5/8] Verify copied app signatures and bundle identities..."
codesign --verify --deep --strict --verbose=2 "${chatgpt_target}"
codesign --verify --deep --strict --verbose=2 "${clashx_target}"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${chatgpt_target}/Contents/Info.plist")" == "com.openai.codex" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${clashx_target}/Contents/Info.plist")" == "com.west2online.ClashX" ]]
plutil -lint "${clash_preferences_target}"
plutil -lint "${clash_launch_agent_target}"

echo
echo "[6/8] Compare every copied file and symbolic-link target..."
manifest_tree "${chatgpt_target}" > "${workspace}/chatgpt-target"
manifest_tree "${clashx_target}" > "${workspace}/clashx-target"
manifest_tree "${clash_config_target}" > "${workspace}/clash-config-target"
manifest_tree "${clash_support_target}" > "${workspace}/clash-support-target"
diff -u "${workspace}/chatgpt-source-before" "${workspace}/chatgpt-target"
diff -u "${workspace}/clashx-source-before" "${workspace}/clashx-target"
diff -u "${workspace}/clash-config-source-before" "${workspace}/clash-config-target"
diff -u "${workspace}/clash-support-source-before" "${workspace}/clash-support-target"
[[ "$(shasum -a 256 "${clash_preferences_target}" | awk '{print $1}')" == "$(awk '{print $1}' "${workspace}/clash-preferences-source-before")" ]]
[[ "$(shasum -a 256 "${clash_launch_agent_target}" | awk '{print $1}')" == "$(awk '{print $1}' "${workspace}/clash-launch-source-before")" ]]

echo
echo "[7/8] Verify ownership, physical copies, privacy boundary, and proxy isolation..."
for copied_path in \
    "${chatgpt_target}" \
    "${clashx_target}" \
    "${clash_config_target}" \
    "${clash_support_target}" \
    "${clash_preferences_target}" \
    "${clash_launch_agent_target}"; do
    [[ ! -L "${copied_path}" ]]
    [[ "$(stat -f '%u:%g' "${copied_path}")" == "${target_uid}:${target_gid}" ]]
done

while IFS= read -r -d '' copied_link; do
    link_target="$(readlink "${copied_link}")"
    case "${link_target}" in
        /Applications/*|/Users/liuyanan/*|/Volumes/Macintosh\ HD/*)
            echo "External link back to Monterey detected: ${copied_link} -> ${link_target}" >&2
            exit 1
            ;;
    esac
done < <(find "${chatgpt_target}" "${clashx_target}" "${clash_config_target}" "${clash_support_target}" -type l -print0)

for private_path in "${chatgpt_user_data[@]}"; do
    [[ ! -e "${private_path}" && ! -L "${private_path}" ]]
done

[[ "$(shasum -a 256 "${source_proxy_db}" | awk '{print $1}')" == "${source_proxy_hash_before}" ]]
[[ "$(shasum -a 256 "${target_proxy_db}" | awk '{print $1}')" == "${target_proxy_hash_before}" ]]

echo
echo "[8/8] Prove Monterey sources were retained and unchanged..."
manifest_tree "${chatgpt_source}" > "${workspace}/chatgpt-source-after"
manifest_tree "${clashx_source}" > "${workspace}/clashx-source-after"
manifest_tree "${clash_config_source}" > "${workspace}/clash-config-source-after"
manifest_tree "${clash_support_source}" > "${workspace}/clash-support-source-after"
diff -u "${workspace}/chatgpt-source-before" "${workspace}/chatgpt-source-after"
diff -u "${workspace}/clashx-source-before" "${workspace}/clashx-source-after"
diff -u "${workspace}/clash-config-source-before" "${workspace}/clash-config-source-after"
diff -u "${workspace}/clash-support-source-before" "${workspace}/clash-support-source-after"
[[ "$(shasum -a 256 "${clash_preferences_source}" | awk '{print $1}')" == "$(awk '{print $1}' "${workspace}/clash-preferences-source-before")" ]]
[[ "$(shasum -a 256 "${clash_launch_agent_source}" | awk '{print $1}')" == "$(awk '{print $1}' "${workspace}/clash-launch-source-before")" ]]

sync
echo
echo "SEQUOIA_APP_COPY_VERIFIED"
echo "ChatGPT app-only copy is clean; ClashX app/config/preferences are copied; both OS proxy databases remain independent."
