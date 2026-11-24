#!/usr/bin/env bash
# Packages the addon into a distributable archive: dist/vfx_2d-<version>.zip
#
#   ./tools/package.sh                    # pure GDScript addon (no C++ binaries)
#   ./tools/package.sh 0.3.0              # explicit version
#   ./tools/package.sh --with-extension   # include the locally built GDExtension
#
# Binaries are platform and engine specific, so they are excluded by default:
# ship one archive per platform when you enable --with-extension.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

include_extension=0
version=""
for arg in "$@"; do
    case "$arg" in
        --with-extension) include_extension=1 ;;
        -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
        -*) echo "Unknown argument: $arg" >&2; exit 2 ;;
        *) version="$arg" ;;
    esac
done

if [ -z "$version" ]; then
    version="$(sed -n 's/^version="\(.*\)"$/\1/p' addons/vfx_2d/plugin.cfg)"
fi
if [ -z "$version" ]; then
    echo "Could not determine the addon version from addons/vfx_2d/plugin.cfg" >&2
    exit 1
fi

mkdir -p dist
suffix=""
if [ "$include_extension" = "1" ]; then
    suffix="-cpp"
fi
out="dist/vfx_2d-${version}${suffix}.zip"
rm -f "$out"

excludes=(-x '*.DS_Store' -x '*.import')
if [ "$include_extension" = "0" ]; then
    excludes+=(-x 'addons/vfx_2d/bin/*' -x 'addons/vfx_2d/vfx_streaks.gdextension*')
fi

zip -qr "$out" addons/vfx_2d "${excludes[@]}"

echo "Packaged ${out}"
if [ "$include_extension" = "1" ]; then
    echo "Includes locally built GDExtension binaries — Linux/engine specific, see cpp/README.md."
else
    echo "GDScript only. Extract into a Godot project root (it contains addons/vfx_2d/)."
fi
