#!/usr/bin/env bash

set -euo pipefail

certificate="${CAGE_SIGNING_CERTIFICATE_P12_BASE64:?Missing certificate secret}"
password="${CAGE_SIGNING_CERTIFICATE_PASSWORD:?Missing certificate password}"
keychain="${RUNNER_TEMP:-/private/tmp}/cage-signing.keychain-db"
p12="${RUNNER_TEMP:-/private/tmp}/cage-signing.p12"

printf '%s' "${certificate}" | base64 --decode > "${p12}"
security create-keychain -p "${password}" "${keychain}"
security set-keychain-settings -lut 21600 "${keychain}"
security unlock-keychain -p "${password}" "${keychain}"
security import "${p12}" -P "${password}" -A -t cert -f pkcs12 -k "${keychain}"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${password}" "${keychain}"
security list-keychains -d user -s "${keychain}" login.keychain-db

identity="$(security find-identity -v -p codesigning "${keychain}" | awk '/[0-9A-F]{40}/ { print $2; exit }')"
test -n "${identity}"
printf 'CAGE_CODE_SIGN_IDENTITY=%s\n' "${identity}" >> "${GITHUB_ENV:?GITHUB_ENV is required}"
printf 'CAGE_SIGNING_KEYCHAIN=%s\n' "${keychain}" >> "${GITHUB_ENV}"
