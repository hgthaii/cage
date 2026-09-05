#!/usr/bin/env bash

set -euo pipefail
umask 077

certificate="${CAGE_SIGNING_CERTIFICATE_P12_BASE64:?Missing certificate secret}"
password="${CAGE_SIGNING_CERTIFICATE_PASSWORD:?Missing certificate password}"
keychain="${RUNNER_TEMP:-/private/tmp}/cage-signing.keychain-db"
p12="${RUNNER_TEMP:-/private/tmp}/cage-signing.p12"
public_certificate="${RUNNER_TEMP:-/private/tmp}/cage-signing.pem"
trap 'rm -f -- "${p12}" "${public_certificate}"' EXIT

printf '%s' "${certificate}" | base64 --decode > "${p12}"
export CAGE_P12_PASSWORD="${password}"
openssl pkcs12 -in "${p12}" -clcerts -nokeys -passin env:CAGE_P12_PASSWORD -out "${public_certificate}"
unset CAGE_P12_PASSWORD
# Self-signed identities are not listed by `find-identity -v`; resolve the exact
# identity from the certificate instead, without changing system trust.
identity="$(openssl x509 -in "${public_certificate}" -noout -fingerprint -sha1 | sed -E 's/^[^=]+=//; s/://g')"
[[ "${identity}" =~ ^[0-9A-Fa-f]{40}$ ]]
security create-keychain -p "${password}" "${keychain}"
printf 'CAGE_SIGNING_KEYCHAIN=%s\n' "${keychain}" >> "${GITHUB_ENV:?GITHUB_ENV is required}"
security set-keychain-settings -lut 21600 "${keychain}"
security unlock-keychain -p "${password}" "${keychain}"
security import "${p12}" -P "${password}" -T /usr/bin/codesign -t cert -f pkcs12 -k "${keychain}"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${password}" "${keychain}" >/dev/null
security list-keychains -d user -s "${keychain}" login.keychain-db

printf 'CAGE_CODE_SIGN_IDENTITY=%s\n' "${identity}" >> "${GITHUB_ENV:?GITHUB_ENV is required}"
