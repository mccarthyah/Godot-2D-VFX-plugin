#!/usr/bin/env bash
# Packages the addon into distributable archives:
#
#   dist/vfx_2d-<version>.zip           drop-in addon (addons/vfx_2d/ only)
#   dist/vfx_2d-<version>-project.zip   the whole runnable project, demo and
#                                       effect gallery included
#
#   ./tools/package.sh                    # both archives, pure GDScript
#   ./tools/package.sh 0.3.0              # explicit version
#   ./tools/package.sh --with-extension   # addon archive with the built library
#   ./tools/package.sh --addon-only       # skip the project archive
#
# Binaries are platform and engine specific, so they are excluded by default:
# ship one archive per platform when you enable --with-extension.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

include_extension=0
include_project=1
version=""
for arg in "$@"; do
    case "$arg" in
        --with-extension) include_extension=1 ;;
        --addon-only) include_project=0 ;;
        -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}"; exit 0 ;;
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

if [ "$include_project" = "1" ]; then
    project_out="dist/vfx_2d-${version}-project.zip"
    rm -f "$project_out"
    zip -qr "$project_out" project.godot icon.svg README.md LICENSE \
        addons/vfx_2d demo tests "${excludes[@]}"
    echo "Packaged ${project_out}"
    echo "Open it in Godot and press F5 (demo) or F6 on demo/gallery.tscn (effect gallery)."
fi
