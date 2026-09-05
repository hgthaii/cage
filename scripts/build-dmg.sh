#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_directory="${repository_root}/dist"
staging_directory="$(mktemp -d /private/tmp/cage-dmg.XXXXXX)"
payload="${staging_directory}/payload"
read_write_image="${staging_directory}/Cage-rw.dmg"
device_name=""

cleanup() {
    if [[ -n "${device_name}" ]]; then
        hdiutil detach "${device_name}" -quiet || true
    fi
    rm -rf -- "${staging_directory}"
}
trap cleanup EXIT

bash "${repository_root}/scripts/app.sh" build-and-verify
mkdir -p "${payload}" "${output_directory}"
/usr/bin/ditto "/private/tmp/cage-app/Cage.app" "${payload}/Cage.app"
ln -s /Applications "${payload}/Applications"

hdiutil create -volname "Cage" -srcfolder "${payload}" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -ov "${read_write_image}"
attach_output="$(hdiutil attach "${read_write_image}" -mountrandom /Volumes -readwrite -nobrowse -noautoopen -noverify)"
device_name="$(printf '%s\n' "${attach_output}" | awk '/^\/dev\// { print $1; exit }')"
mount_directory="$(printf '%s\n' "${attach_output}" | awk -F '\t' '$NF ~ /^\/Volumes\// { print $NF; exit }')"
[[ -n "${device_name}" && -n "${mount_directory}" ]]

osascript - "$(basename "${mount_directory}")" <<'APPLESCRIPT'
on run arguments
set diskName to item 1 of arguments
tell application "Finder"
    tell disk diskName
        open
        tell container window
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set pathbar visible to false
            set bounds to {120, 120, 840, 390}
        end tell
        set backgroundFile to file "Cage.app:Contents:Resources:InstallerBackground.png"
        tell the icon view options of container window
            set icon size to 96
            set text size to 12
            set arrangement to not arranged
            set background picture to backgroundFile
        end tell
        set position of item "Cage.app" to {180, 105}
        set position of item "Applications" to {540, 105}
        close
        open
        -- Recalculate the icon-view extent after reopening, before Finder saves it.
        delay 1
        tell container window
            set bounds to {120, 120, 830, 380}
        end tell
    end tell
    delay 1
    tell disk diskName
        tell container window
            set bounds to {120, 120, 840, 390}
        end tell
    end tell
    delay 3
    tell disk diskName
        close container window
    end tell
end tell
end run
APPLESCRIPT

sync
hdiutil detach "${device_name}" -quiet
device_name=""
hdiutil convert "${read_write_image}" -format UDZO -imagekey zlib-level=9 \
    -ov -o "${output_directory}/Cage.dmg"
hdiutil verify "${output_directory}/Cage.dmg"
printf '%s\n' "${output_directory}/Cage.dmg"
