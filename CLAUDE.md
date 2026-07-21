# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ActionbarPlus-ArcLayout is a plugin addon for **ActionbarPlus** (V2) that adds an arc-shaped bar layout: buttons are arranged along a curved 90-degree arc (-45 to 45 degrees) instead of a grid, opening either up or down.

This is a standalone addon, not a module inside the main ActionbarPlus repo. It attaches to ActionbarPlus V2 at runtime via a self-registration pattern — see "Plugin architecture" below.

## Build & Release

### Deployment to local WoW installs

```shell
w-deployer -c ./dev/deployer-config.lua
```

Continuous deploy with 'quiet' -q and 'watch' -w mode:
```shell
w-deployer -c ./dev/deployer-config.lua -qw
```

Never run `w-deployer` yourself unless explicitly asked — the user's deployer typically runs in watch mode already.

### Clean build
```shell
./dev/release-clean.sh
```

### Release process
Same as the main ActionbarPlus repo: create a PR, tag to publish (GitHub Action pushes the tag), verify the CurseForge build is green, then publish the GitHub draft release.

There are no automated tests. Validation is done in-game.

## Architecture

### Plugin registration (no TOC dependency on BarsUI)

This addon declares `OptionalDeps: Ace3, ActionbarPlus-Core` in its TOC — **not** `RequiredDeps`, and it never depends on `ActionbarPlus-BarsUI` directly. At file-load time it self-registers into Core's layout registry:

```lua
if not ABP_Core_2_0 then return end
local cns = ABP_Core_2_0:ns()
local o = {}; cns:RegisterLayout('arc', o)
```

If `ABP_Core_2_0` is nil (Core missing/disabled), the file no-ops immediately — the addon fails soft with no error.

`BarModuleFactory.lua` in `ActionbarPlus-BarsUI` resolves the layout for a bar by key (`ui.layout`, e.g. `'arc'`) via `cns:GetLayout(key)`, falling back to the built-in `GridLayout` if the key isn't registered (e.g. this addon is disabled). Load order between this addon and BarsUI does not matter — resolution happens lazily whenever a bar is rendered/rebuilt, not at load time.

### The `BarLayout_ABP_2_0` interface

Defined in the main ActionbarPlus repo at `ActionbarPlus-Core/Libs/Annotations/ABPV2-Annotations.lua`. Any layout (this one included) must implement:

| Method | Purpose |
|---|---|
| `SupportsBackdrop()` | Whether the layout supports a themed backdrop. Arc: `false` (no rectangular frame edge to anchor to). |
| `SupportsHorizontalSpacing()` | Whether `button.spacing.horizontal` affects this layout. Arc: `true` (used as minimum chord length between adjacent buttons). |
| `SupportsVerticalSpacing()` | Whether `button.spacing.vertical` affects this layout. Arc: `false` (single-axis arc has no separate vertical spacing concept). |
| `GetButtonCount(ui)` | Number of buttons to render. |
| `Apply(frame, ui)` | Positions/sizes all buttons for the given bar config. |
| `ApplyExtraButtons(frame)` | Positions the extra-button row. Arc: hides them (no rectangular edge to anchor to). |
| `ApplyDragHandle(frame, dragAnchor, thickness)` | Positions the drag handle beside the first/last button. |

Keep these methods in sync with the interface if the main repo's annotation changes — check `ABPV2-Annotations.lua` in the `ActionbarPlus` repo when in doubt.

### Arc geometry (`ActionbarPlus-ArcLayout.lua`)

- Buttons are spread evenly across a fixed 90-degree span, from `-45°` to `45°`.
- Radius is computed so adjacent button centers are at least `size + spacing` apart (chord length = `2 * radius * sin(stepDegrees/2)`), never smaller than `size`.
- `ui.arcDirection == 'down'` inverts the arc to open downward instead of upward.
- Masque re-skinning (`cns:IfMasque(...)`) and HotKey font/position scale with button size, matching GridLayout's per-button visual conventions.

### Relationship to the main ActionbarPlus repo

This addon depends on runtime APIs exposed by `ActionbarPlus-Core` (the `ns:RegisterLayout`/`ns:GetLayout` registry, `ns:IfMasque`, `ns:log`, `BarLayout_ABP_2_0` contract) and the `BarFrame_ABP_2_0` / `Button_ABP_2_0_X` widget shapes from `ActionbarPlus-BarsUI`. It does not vendor or duplicate any of that code — when those contracts change in the main repo, this addon may need corresponding updates. The main repo lives at `~/sandbox/github/kapresoft/wow/ActionbarPlus`; check its `CLAUDE.md` and `ABPV2-Annotations.lua` for the authoritative interface definitions.

## Key conventions

- **EmmyLua annotations** — maintain `---@param`/`---@return`/`---@class` on public methods, matching the main repo's style.
- **No unit test framework** — test in-game. Use `/etrace` to watch events, `/fstack` to inspect frames, `/dump` to inspect values.
- **stylua** formatting — see `stylua.toml` (100-col, 2-space indent, single quotes).
- Follow the main ActionbarPlus repo's Lua conventions (mixin-based composition, no inheritance chains) since this addon integrates directly with its widget/mixin shapes.