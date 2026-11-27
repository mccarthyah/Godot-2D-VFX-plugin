# Sparkform documentation

Four kinds of page, one rule: **anything that describes code is generated from
that code**, so it cannot go stale between releases.

| Page | What it answers | Maintained by |
|---|---|---|
| [`INSTALL.md`](INSTALL.md) | How do I get this into my project and confirm it works? | hand-written |
| [`API.md`](API.md) | What does `Sparkform` expose, and what do the base classes do? | `tools/gen_docs.py` |
| [`EFFECTS.md`](EFFECTS.md) | What are all 24 effects, and what is every property? | `tools/gen_docs.py` |
| [`COOKBOOK.md`](COOKBOOK.md) | How do I do *this* specific thing? | hand-written |
| [`ASSETLIB.md`](ASSETLIB.md) | How is the AssetLib/itch release built and submitted? | hand-written |

New to the addon? Read [`INSTALL.md`](INSTALL.md) first, then the front page of
the repository (`README.md`) for the quick start, then
[`EFFECTS.md`](EFFECTS.md) when you want to tune something.

## Generated pages

`API.md` and `EFFECTS.md` are produced from the `##` doc comments and the
`@export` declarations in `addons/sparkform`:

```bash
python3 tools/gen_docs.py          # rewrite both pages
python3 tools/gen_docs.py --check  # exit 1 if either page is stale
```

CI runs `--check`, so a pull request that renames a property without regenerating
the reference fails the build. Do not edit those two files by hand — change the
doc comment above the property or function in the `.gd` file instead. The comments
are also what the Godot inspector shows, so one edit fixes both places.

The generator is deliberately small and stdlib-only: it reads `class_name`,
`extends`, `signal`, `@export_group`, `@export` and `func` declarations, converts
Godot doc BBCode (`[code]`, `[member x]`, `[codeblock]`) to Markdown, and writes
the tables. Anything it cannot parse raises instead of guessing.

## The same text in the editor

Every exported property has a `##` comment, which is what Godot shows in the
inspector tooltip and in the built-in documentation panel. The generator reads
those comments verbatim, so the Markdown and the editor never disagree.
