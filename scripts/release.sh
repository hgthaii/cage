#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    printf '%s\n' "Usage: $0 build-update | verify <dmg> <zip> <appcast>" >&2
}

build_update() (
    local version="${CAGE_VERSION:?CAGE_VERSION is required}"
    local private_key="${SPARKLE_EDDSA_PRIVATE_KEY:-}"
    local output="${repository_root}/dist"
    local archive="Cage-${version}.zip"
    local staging
    staging="$(mktemp -d /private/tmp/cage-update.XXXXXX)"
    trap 'rm -rf -- "${staging}"' EXIT

    [[ -n "${private_key}" ]] || { printf '%s\n' "Missing SPARKLE_EDDSA_PRIVATE_KEY." >&2; exit 1; }
    bash "${repository_root}/scripts/app.sh" build
    mkdir -p "${output}"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent \
        /private/tmp/cage-app/Cage.app "${staging}/${archive}"

    local generate_appcast
    generate_appcast="$(find "${repository_root}/.build/artifacts" \
        -type f -name generate_appcast -print -quit 2>/dev/null)"
    test -x "${generate_appcast}"
    printf '%s' "${private_key}" | "${generate_appcast}" \
        --ed-key-file - \
        --download-url-prefix "https://github.com/hgthaii/cage/releases/download/v${version}/" \
        --link "https://github.com/hgthaii/cage" \
        --maximum-deltas 0 \
        "${staging}"
    /usr/bin/ditto "${staging}/${archive}" "${output}/${archive}"
    install -m 644 "${staging}/appcast.xml" "${output}/appcast.xml"
)

verify_release() (
    local dmg="$1" archive="$2" appcast="$3"
    local version="${CAGE_VERSION:?CAGE_VERSION is required}"
    local work
    work="$(mktemp -d /private/tmp/cage-release-verify.XXXXXX)"
    trap 'hdiutil detach "${work}/mounted" -quiet 2>/dev/null || true; rm -rf -- "${work}"' EXIT
    test -f "${dmg}" && test -f "${archive}" && test -f "${appcast}"
    mkdir -p "${work}/mounted" "${work}/archive"
    hdiutil attach "${dmg}" -mountpoint "${work}/mounted" -readonly -nobrowse -noverify -quiet
    bash "${repository_root}/scripts/app.sh" verify "${work}/mounted/Cage.app"
    hdiutil detach "${work}/mounted" -quiet
    /usr/bin/ditto -x -k "${archive}" "${work}/archive"
    bash "${repository_root}/scripts/app.sh" verify "${work}/archive/Cage.app"

    local feed_version feed_url signature
    feed_version="$(xmllint --xpath 'string(//*[local-name()="shortVersionString"][1])' "${appcast}")"
    feed_url="$(xmllint --xpath 'string(//*[local-name()="enclosure"]/@url)' "${appcast}")"
    signature="$(xmllint --xpath 'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])' "${appcast}")"
    [[ "${feed_version}" == "${version}" ]]
    [[ "${feed_url}" == "https://github.com/hgthaii/cage/releases/download/v${version}/Cage-${version}.zip" ]]
    test -n "${signature}"
    CLANG_MODULE_CACHE_PATH=/private/tmp/cage-release-clang-cache \
    SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/cage-release-swift-cache \
    xcrun swift "${repository_root}/scripts/verify-sparkle-signature.swift" \
        "${archive}" "${signature}" "${work}/archive/Cage.app/Contents/Info.plist"
    hdiutil verify "${dmg}"
    printf '%s\n' "Verified Cage ${version} release artifacts"
)

case "${1:-}" in
    build-update) [[ "$#" -eq 1 ]] || { usage; exit 2; }; build_update ;;
    verify) [[ "$#" -eq 4 ]] || { usage; exit 2; }; verify_release "$2" "$3" "$4" ;;
    *) usage; exit 2 ;;
esac
