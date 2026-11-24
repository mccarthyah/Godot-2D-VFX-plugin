# Publishing on Godot AssetLib

This is the checklist for shipping a release of the 2D VFX Kit to the
[Godot Asset Library](https://godotengine.org/asset-library/asset), plus what the
`--assetlib` archive contains and why.

## 1. Build the archive

```bash
./tools/package.sh --assetlib
# -> dist/vfx_2d-<version>-assetlib.zip
```

That archive is the addon only (no `demo/`, `tests/`, `cpp/` or binaries), and
it is laid out the way AssetLib expects after extraction:

```
addons/vfx_2d/
  plugin.cfg          # manifest AssetLib reads (name, description, version, script)
  plugin.gd           # EditorPlugin: registers the VFX2D autoload
  vfx_2d.gd           # the autoload itself
  core/ effects/      # effects and shared helpers
  README.md           # ships with the plugin: install, quick start, troubleshooting
  LICENSE             # MIT, travels with the code
```

AssetLib extracts the zip into the user's project root, so the `addons/` level
must be the first path in the archive, which is what `--assetlib` guarantees. The
script then checks the archive it just wrote, and exits non-zero if anything is
off:

```
Packaged dist/vfx_2d-0.5.1-assetlib.zip (88 files, 78 KiB)
Checks passed: plugin folder only, no native libraries, README + LICENSE inside.
```

The checks are: `plugin.cfg`, `plugin.gd`, `vfx_2d.gd`, `README.md` and
`LICENSE` are all present; no `.so` / `.dll` / `.dylib` / `.wasm` /
`.gdextension` files; nothing from `tests/`, `demo/`, `cpp/`, `tools/`, `docs/`
or `.github/`; and the archive is under 10 MiB. Run it in CI (it is) rather than
trusting a remembered checklist.

The file set is the same GDScript-only addon folder as the drop-in
`dist/vfx_2d-<version>.zip`; the `-assetlib` name marks it as the one that has
been validated for submission, and uploading either works.

## 2. Before you submit

- [ ] `addons/vfx_2d/plugin.cfg` has the **new** version (`version="0.5.1"`).
- [ ] `CHANGELOG.md` has an entry for it, with a link reference at the bottom.
- [ ] `./tools/package.sh --assetlib` was run after the version bump.
- [ ] The suite is green on stock 4.2/4.3/4.7.2 (CI does this on every push).
- [ ] `godot --headless --path . res://tests/test_runner.tscn` passes locally.
- [ ] The archive installs into an empty project: extract, enable, verify (see
      `docs/INSTALL.md`, step 3).
- [ ] `README.md` and `LICENSE` exist **inside** `addons/vfx_2d/`.

## 3. Submit

Open <https://godotengine.org/asset-library/asset/submit> and fill it in:

| Field | Value |
| --- | --- |
| Asset type | **Plugins** |
| Category | **2D Tools** (secondary: *Particles*, if offered) |
| Godot version | **4.2** and newer |
| Version | the `plugin.cfg` version, e.g. `0.5.1` |
| Repository URL | `https://github.com/mccarthyah/Godot-2D-VFX-plugin` |
| Issue tracker URL | `https://github.com/mccarthyah/Godot-2D-VFX-plugin/issues` |
| License | **MIT** |
| Title | `2D VFX Kit: procedural effects, no assets` |
| Description | short paragraph: 24 effects + 8 modifiers, pooled, `chaos` knob, optional C++ streak layer, works without it |
| Preview image | a 16:9 frame of the gallery (see below) |
| Tags | `2d`, `vfx`, `effects`, `particles`, `procedural`, `juice` |
| Binary upload | `dist/vfx_2d-<version>-assetlib.zip` |

The description field accepts light markdown. Keep the first sentence identical
to the repo tagline so the library entry, the README and the release notes agree.

## 4. Preview image

AssetLib wants one landscape image, ideally 1280×720 or larger. The gallery is
the best source: run the project, press **R** on each page to fire it, and grab a
frame with Godot's own screenshot (`Viewport.get_texture().get_image()`), or
record a short clip and export a still.

Keep the repository's preview in sync by adding it as `docs/preview.png` and
referencing it from the top of `README.md`.

## 5. After the first submission

- A reviewer approves the entry; until then the asset is visible only to you.
- Updates do **not** need a new submission: use **Edit** on the asset page,
  bump the version, and upload the new `-assetlib.zip`.
- Keep the version in `plugin.cfg` authoritative: the packaging script reads it,
  and so does the editor's plugin list.
- If the API changes, say so in `CHANGELOG.md` under **Changed**/**Removed**;
  AssetLib shows the description, not the changelog.

## 6. Alternatives worth doing anyway

- **GitHub Releases**: attach all three archives (`-project.zip` for the demo
  and gallery, `-cpp.zip` for prebuilt Linux libraries). This is what the README
  links to, and it works before AssetLib approval.
- **A `.gitattributes` `export-ignore` list**: keeps demo/tests out of
  `git archive` output if you ever distribute that way.

## 7. What not to ship to AssetLib

- `addons/vfx_2d/bin/` and `vfx_streaks.gdextension`: platform- and
  engine-version-specific; ship them in the separate `-cpp` archive instead.
- `demo/`, `tests/`, `tools/`, `cpp/`: development material, and the demo needs
  its own `project.godot` to run.
- `.godot/`, `dist/`, `godot-cpp/`: caches and build products (already ignored
  by `.gitignore`).
