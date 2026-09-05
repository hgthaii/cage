#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    printf '%s\n' "Usage: $0 build | verify [app-path] | build-and-verify" >&2
}

build_app() {
    local output_root="/private/tmp/cage-app"
    local app_path="${output_root}/Cage.app"
    local compiled_assets="${output_root}/CompiledAssets"
    local version="${CAGE_VERSION:-0.0.0}"
    local build_number="${CAGE_BUILD_NUMBER:-1}"
    local signing_identity="${CAGE_CODE_SIGN_IDENTITY:--}"
    local require_stable_signing="${CAGE_REQUIRE_STABLE_SIGNING:-false}"

    export CLANG_MODULE_CACHE_PATH="/private/tmp/cage-clang-cache"
    export SWIFTPM_MODULECACHE_OVERRIDE="/private/tmp/cage-swift-cache"

    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
        printf '%s\n' "Invalid CAGE_VERSION: ${version}" >&2
        exit 1
    }
    [[ "${build_number}" =~ ^[1-9][0-9]*$ ]] || {
        printf '%s\n' "Invalid CAGE_BUILD_NUMBER: ${build_number}" >&2
        exit 1
    }
    if [[ "${require_stable_signing}" == "true" && "${signing_identity}" == "-" ]]; then
        printf '%s\n' "A stable signing identity is required for a release build." >&2
        exit 1
    fi

    build_architecture() {
        swift build \
            --package-path "${repository_root}" \
            --disable-sandbox \
            --configuration release \
            --product Cage \
            --triple "$1-apple-macosx"
    }

    binary_path() {
        swift build \
            --package-path "${repository_root}" \
            --disable-sandbox \
            --configuration release \
            --triple "$1-apple-macosx" \
            --show-bin-path
    }

    build_architecture arm64
    build_architecture x86_64
    local arm_path x86_path
    arm_path="$(binary_path arm64)"
    x86_path="$(binary_path x86_64)"

    rm -rf -- "${app_path}" "${compiled_assets}"
    mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Resources" \
        "${app_path}/Contents/Frameworks" "${compiled_assets}"
    xcrun lipo -create "${arm_path}/Cage" "${x86_path}/Cage" \
        -output "${app_path}/Contents/MacOS/Cage"
    chmod 755 "${app_path}/Contents/MacOS/Cage"

    install -m 644 "${repository_root}/Resources/Info.plist" "${app_path}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "${app_path}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${build_number}" "${app_path}/Contents/Info.plist"
    install -m 644 "${repository_root}/Resources/StatusIconIdle.svg" "${app_path}/Contents/Resources/StatusIconIdle.svg"
    install -m 644 "${repository_root}/Resources/StatusIconLocked.svg" "${app_path}/Contents/Resources/StatusIconLocked.svg"
    CLANG_MODULE_CACHE_PATH=/private/tmp/cage-dmg-clang-cache \
    SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/cage-dmg-swift-cache \
    xcrun swift "${repository_root}/scripts/generate-dmg-background.swift" \
        "${app_path}/Contents/Resources/InstallerBackground.png"

    xcrun actool \
        --compile "${compiled_assets}" \
        --platform macosx \
        --minimum-deployment-target 11.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "${output_root}/AssetInfo.plist" \
        "${repository_root}/src/Media.xcassets" >/dev/null
    install -m 644 "${compiled_assets}/AppIcon.icns" "${app_path}/Contents/Resources/AppIcon.icns"
    install -m 644 "${compiled_assets}/Assets.car" "${app_path}/Contents/Resources/Assets.car"

    /usr/bin/ditto "${arm_path}/Sparkle.framework" "${app_path}/Contents/Frameworks/Sparkle.framework"
    mkdir -p "${app_path}/Contents/Resources/ThirdPartyNotices"
    install -m 644 "${repository_root}/.build/checkouts/Sparkle/LICENSE" \
        "${app_path}/Contents/Resources/ThirdPartyNotices/Sparkle.txt"

    if ! otool -l "${app_path}/Contents/MacOS/Cage" | grep -F '@executable_path/../Frameworks' >/dev/null; then
        install_name_tool -add_rpath '@executable_path/../Frameworks' "${app_path}/Contents/MacOS/Cage"
    fi
    local codesign_arguments=(--force --deep --sign "${signing_identity}")
    if [[ "${signing_identity}" != "-" ]]; then codesign_arguments+=(--timestamp=none); fi
    codesign "${codesign_arguments[@]}" "${app_path}"
    printf '%s\n' "${app_path}"
}

verify_app() {
    local app_path="${1:-/private/tmp/cage-app/Cage.app}"
    local info="${app_path}/Contents/Info.plist"
    local executable="${app_path}/Contents/MacOS/Cage"
    local sparkle="${app_path}/Contents/Frameworks/Sparkle.framework"

    test -x "${executable}"
    test -d "${sparkle}"
    test -f "${app_path}/Contents/Resources/AppIcon.icns"
    test -f "${app_path}/Contents/Resources/StatusIconIdle.svg"
    test -f "${app_path}/Contents/Resources/StatusIconLocked.svg"
    test -f "${app_path}/Contents/Resources/InstallerBackground.png"
    test -f "${app_path}/Contents/Resources/ThirdPartyNotices/Sparkle.txt"
    plutil -lint "${info}"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${info}")" == "dev.hgthaii.cage" ]]
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${info}")" == "11.0" ]]
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "${info}")" == "https://github.com/hgthaii/cage/releases/latest/download/appcast.xml" ]]
    lipo "${executable}" -verify_arch arm64 x86_64
    otool -L "${executable}" | grep -F '@rpath/Sparkle.framework/Versions/B/Sparkle' >/dev/null
    otool -l "${executable}" | grep -F '@executable_path/../Frameworks' >/dev/null

    local framework_binary
    while IFS= read -r -d '' framework_binary; do
        file -b "${framework_binary}" | grep -q 'Mach-O' || continue
        lipo "${framework_binary}" -verify_arch arm64 x86_64
    done < <(find "${sparkle}" -type f -perm -111 -print0)

    codesign --verify --deep --strict --verbose=2 "${app_path}"
    if [[ "${CAGE_REQUIRE_STABLE_SIGNING:-false}" == "true" ]]; then
        local signature
        signature="$(codesign -dv --verbose=4 "${app_path}" 2>&1)"
        [[ "${signature}" != *"Signature=adhoc"* ]]
    fi
    printf '%s\n' "Verified ${app_path}"
}

case "${1:-}" in
    build) [[ "$#" -eq 1 ]] || { usage; exit 2; }; build_app ;;
    verify) [[ "$#" -le 2 ]] || { usage; exit 2; }; verify_app "${2:-}" ;;
    build-and-verify) [[ "$#" -eq 1 ]] || { usage; exit 2; }; build_app; verify_app ;;
    *) usage; exit 2 ;;
esac
