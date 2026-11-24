#!/usr/bin/env bash
# Builds the optional C++ streak field and wires it into the addon.
#
#   ./tools/build_extension.sh                  # debug build, api 4.7
#   ./tools/build_extension.sh --release        # debug + release
#   ./tools/build_extension.sh --api 4.6        # target another 4.x line
#   ./tools/build_extension.sh --godot /path/to/godot  # use that build's exact API
#   ./tools/build_extension.sh --ref <git-ref>         # pin a godot-cpp revision
#
# Requirements: git, a C++17 compiler (g++/clang++/MSVC), and scons
# (`pip install scons`).
#
# The output is deliberately gitignored: addons/vfx_2d/bin/ plus a generated
# addons/vfx_2d/vfx_streaks.gdextension. Delete both to fall back to pure
# GDScript; the addon detects the library at runtime.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

api_version="4.7"
# Pinned to a godot-cpp commit from the 4.7 era: later master targets the 4.8
# interface, which 4.7.x rejects ("non-existent interface function:
# get_godot_version"). Override with --ref or GODOT_CPP_REF.
godot_cpp_ref="${GODOT_CPP_REF:-fba3efaf6ac396b8c8ebe44e31a2b7a516a2e337}"
build_release=0
godot_bin=""
jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
# Trimmed bindings: compiling every Godot class takes ~40 min on 2 cores, this
# profile takes ~1 min and produces a much smaller library.
build_profile="$repo_root/cpp/build_profile.json"

while [ $# -gt 0 ]; do
    case "$1" in
        --release) build_release=1 ;;
        --api) shift; api_version="$1" ;;
        --godot) shift; godot_bin="$1" ;;
        --jobs) shift; jobs="$1" ;;
        --ref) shift; godot_cpp_ref="$1" ;;
        -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

if ! command -v scons >/dev/null 2>&1; then
    if [ -x /tmp/gdtk/bin/scons ]; then
        export PATH="/tmp/gdtk/bin:$PATH"
    else
        echo "scons not found. Install it with: pip install scons" >&2
        exit 1
    fi
fi

# 1. godot-cpp, fetched once and reused. A raw commit SHA cannot be passed to
# `git clone --branch`, so pins are fetched explicitly.
if [ ! -d cpp/godot-cpp ]; then
    godot_cpp_url="https://github.com/godotengine/godot-cpp.git"
    if [[ "$godot_cpp_ref" =~ ^[0-9a-f]{7,40}$ ]]; then
        echo "==> Fetching godot-cpp commit ${godot_cpp_ref}"
        mkdir -p cpp/godot-cpp
        git -C cpp/godot-cpp init -q
        git -C cpp/godot-cpp remote add origin "$godot_cpp_url"
        git -C cpp/godot-cpp fetch -q --depth 1 origin "$godot_cpp_ref"
        git -C cpp/godot-cpp checkout -q FETCH_HEAD
    else
        echo "==> Cloning godot-cpp (${godot_cpp_ref})"
        git clone --depth 1 --branch "$godot_cpp_ref" "$godot_cpp_url" cpp/godot-cpp
    fi
fi
echo "==> godot-cpp $(git -C cpp/godot-cpp rev-parse --short HEAD)"

# 2. Optional: bind against the exact API of a specific engine build.
api_args=(api_version="$api_version")
if [ -n "$godot_bin" ]; then
    echo "==> Dumping API + interface from $godot_bin"
    gdext_dir=/tmp/vfx_gdextension_api
    rm -rf "$gdext_dir"
    mkdir -p "$gdext_dir"
    ( cd "$gdext_dir" && "$godot_bin" --headless --dump-extension-api \
        --dump-gdextension-interface --dump-gdextension-interface-json >/dev/null 2>&1 )
    if [ -f "$gdext_dir/extension_api.json" ] && [ -f "$gdext_dir/gdextension_interface.json" ] \
        && [ -f "$gdext_dir/gdextension_interface.h" ]; then
        # gdextension_dir alone is not enough: the dump writes
        # extension_api.json, while scons looks for extension_api-4-7.json and
        # bails with "'api_version' must be provided". Point it at the file.
        api_args=(custom_api_file="$gdext_dir/extension_api.json" gdextension_dir="$gdext_dir")
    else
        echo "warning: incomplete API dump from that build; using api_version=$api_version" >&2
        api_args=(api_version="$api_version")
    fi
fi

# 3. godot-cpp static library + the extension itself.
targets=(template_debug)
if [ "$build_release" = "1" ]; then
    targets+=(template_release)
fi

for target in "${targets[@]}"; do
    echo "==> Building godot-cpp ($target, api $api_version)"
    ( cd cpp/godot-cpp && scons platform=linux target="$target" "${api_args[@]}" \
        build_profile="$build_profile" -j"$jobs" )
    echo "==> Building libvfx_streaks ($target)"
    ( cd cpp && scons platform=linux target="$target" "${api_args[@]}" \
        build_profile="$build_profile" -j"$jobs" )
done

# 4. Generate the .gdextension descriptor for whatever was actually built.
echo "==> Writing addons/vfx_2d/vfx_streaks.gdextension"
VFX_API_VERSION="$api_version" python3 - "$repo_root" <<'PY'
import os
import re
import sys

root = sys.argv[1]
bin_dir = os.path.join(root, "addons", "vfx_2d", "bin")
target_map = {
    "template_debug": "debug",
    "template_release": "release",
    "editor": "editor",
}
pattern = re.compile(r"^libvfx_streaks\.(?P<platform>[a-z]+)\.(?P<target>[a-z_]+)\.(?P<arch>[a-z0-9_]+)\.(?P<ext>so|dll|dylib)$")

entries = {}
for name in sorted(os.listdir(bin_dir)) if os.path.isdir(bin_dir) else []:
    match = pattern.match(name)
    if not match:
        continue
    platform = match.group("platform")
    target = target_map.get(match.group("target"))
    if target is None:
        continue
    key = "%s.%s.%s" % (platform, target, match.group("arch"))
    entries[key] = "res://addons/vfx_2d/bin/" + name

if not entries:
    print("No extension binaries found in %s" % bin_dir, file=sys.stderr)
    sys.exit(1)

lines = [
    "; Generated by tools/build_extension.sh. Do not edit by hand.",
    "; Remove this file (and addons/vfx_2d/bin/) to go back to pure GDScript.",
    "[configuration]",
    'entry_symbol = "vfx_streaks_library_init"',
    'compatibility_minimum = "%s"' % os.environ.get("VFX_API_VERSION", "4.7"),
    "reloadable = true",
    "",
    "[libraries]",
]
for key in sorted(entries):
    lines.append('%s = "%s"' % (key, entries[key]))
lines.append("")

path = os.path.join(root, "addons", "vfx_2d", "vfx_streaks.gdextension")
with open(path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines))
print("wrote %s (%d librar%s)" % (path, len(entries), "y" if len(entries) == 1 else "ies"))
PY

echo
echo "Done. Verify with:"
echo "  godot --headless --path . res://tests/test_runner.tscn"
