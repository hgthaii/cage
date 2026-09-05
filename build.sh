#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CAGE_BUILD_NUMBER="${CAGE_BUILD_NUMBER:-$(git -C "${repository_root}" rev-list --count HEAD)}"
bash "${repository_root}/scripts/build-dmg.sh"
