#!/usr/bin/env bash
# Packages the addon into a distributable archive: dist/vfx_2d-<version>.zip
#
# Usage: ./tools/package.sh [version]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version="${1:-$(sed -n 's/^version="\(.*\)"$/\1/p' addons/vfx_2d/plugin.cfg)}"
if [ -z "$version" ]; then
    echo "Could not determine the addon version from addons/vfx_2d/plugin.cfg" >&2
    exit 1
fi

mkdir -p dist
out="dist/vfx_2d-${version}.zip"
rm -f "$out"
zip -qr "$out" addons/vfx_2d -x '*.DS_Store' -x '*.import'

echo "Packaged ${out}"
echo "Install by extracting it into a Godot project root (it contains addons/vfx_2d/)."
