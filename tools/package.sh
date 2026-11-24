#!/usr/bin/env bash
# Packages the addon into distributable archives:
#
#   dist/vfx_2d-<version>.zip           drop-in addon (addons/vfx_2d/ only)
#   dist/vfx_2d-<version>-project.zip   the whole runnable project, demo and
#                                       effect gallery included
#   dist/vfx_2d-<version>-assetlib.zip  editor-plugin archive for Godot AssetLib
#                                       (the addon folder, validated for submission)
#
#   ./tools/package.sh                    # both archives, pure GDScript
#   ./tools/package.sh 0.5.1              # explicit version
#   ./tools/package.sh --with-extension   # addon archive with the built library
#   ./tools/package.sh --addon-only       # skip the project archive
#   ./tools/package.sh --assetlib         # AssetLib archive only (see docs/ASSETLIB.md)
#
# Binaries are platform and engine specific, so they are excluded by default:
# ship one archive per platform when you enable --with-extension.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

include_extension=0
include_project=1
assetlib_only=0
version=""
for arg in "$@"; do
    case "$arg" in
        --with-extension) include_extension=1 ;;
        --addon-only) include_project=0 ;;
        --assetlib) assetlib_only=1; include_project=0 ;;
        -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}"; exit 0 ;;
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

# An AssetLib submission ships the plugin folder and nothing else: the docs and
# the licence have to travel inside it, because users may never see the repo.
# The file set matches the drop-in addon archive; the extra checks below are what
# makes this one submittable.
if [ "$assetlib_only" = "1" ]; then
    mkdir -p dist
    assetlib_out="dist/vfx_2d-${version}-assetlib.zip"
    rm -f "$assetlib_out"
    zip -qr "$assetlib_out" addons/vfx_2d \
        -x '*.DS_Store' -x '*.import' \
        -x 'addons/vfx_2d/bin/*' -x 'addons/vfx_2d/vfx_streaks.gdextension*'

    listing="$(unzip -Z1 "$assetlib_out")"
    problems=0
    fail() {
        echo "  FAIL $1" >&2
        problems=1
    }

    for required in \
        addons/vfx_2d/plugin.cfg \
        addons/vfx_2d/plugin.gd \
        addons/vfx_2d/vfx_2d.gd \
        addons/vfx_2d/README.md \
        addons/vfx_2d/LICENSE; do
        grep -qx "$required" <<< "$listing" || fail "missing $required"
    done
    if grep -Eq '\.(so|dll|dylib|wasm|gdextension)$' <<< "$listing"; then
        fail "archive carries native library files; ship those separately (see docs/ASSETLIB.md)"
    fi
    if grep -Eq '^(tests|demo|cpp|tools|docs|\.github)/' <<< "$listing"; then
        fail "archive carries files from outside addons/ (see docs/ASSETLIB.md)"
    fi
    file_count="$(printf '%s\n' "$listing" | grep -c . || true)"
    bytes="$(wc -c < "$assetlib_out" | tr -d ' ')"
    if [ "$bytes" -ge 10485760 ]; then
        fail "archive is $((bytes / 1048576)) MiB; AssetLib rejects uploads this large"
    fi

    if [ "$problems" = "1" ]; then
        echo "AssetLib archive failed its checks; see the FAIL lines above." >&2
        exit 1
    fi

    echo "Packaged ${assetlib_out} (${file_count} files, $((bytes / 1024)) KiB)"
    echo "Checks passed: plugin folder only, no native libraries, README + LICENSE inside."
    echo "Upload this to https://godotengine.org/asset-library/asset/submit"
    echo "Checklist: docs/ASSETLIB.md"
    exit 0
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
    echo "Includes locally built GDExtension binaries, Linux/engine specific. See cpp/README.md."
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
