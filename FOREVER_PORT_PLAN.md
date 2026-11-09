# Routes → WoW Forever port plan

**Status:** code port implemented on branch `forever-port`; live-client parity walk pending
**Date:** 2026-11-09
**Source of truth:** `D:\World of Warcraft\_forever_\Interface\AddOns\DevFolder\Routes`
**Target client:** WoW Forever (`_forever_`), build `1.60.1.70862`, Interface `16001`, product `wowf`, `WOW_PROJECT_CAMELOT = 18`

---

## 0. Implementation status (2026-11-09)

The static/code portion of Phases 0–8 is implemented on `forever-port`:

- `16001` is in the TOC alongside every previously supported interface; TOC paths
  use forward slashes; `Bindings.xml` remains auto-loaded (not listed as UI XML).
- `tools/vendor-libs.ps1` stages Ace3, AceHook, and HereBeDragons 2.18+ and fails
  loudly on a missing/old source. `tools/install.ps1` deploys only addon files
  (never WTF) and validates every TOC entry. `tools/package.ps1` builds a zip.
- `C_CVar` helpers replace legacy `GetCVar`; secret-value and `pcall` guards cover
  player position/facing; `IsIndoors()` is preferred over the zoom CVar comparison;
  `WOW_PROJECT_CAMELOT` uses `C_Map.OpenWorldMap`.
- F17 was added after the smoke test showed `WoW90` misclassifying Forever; Camelot
  now takes the modern minimap path.
- `AutoShow` registration is nil-safe, tracking prefers `info.spellID`, and
  enabling/disabling the master toggle registers/unregisters events.
- Minimap drawing supports round/square/rectangular crops, uses
  `GetMinimapShape` when present, infers shape from the mask otherwise, and clips
  segments to `GetHitRectInsets` (EllesmereUI 4:3 mode). Shape/crop changes force
  a redraw.
- Optional plugins are nil-guarded; GatherMate2/HandyNotes handle missing zones
  and empty data; Insert/Delete callbacks ignore unknown zones.
- `/routes selftest` reports client/HBD/zone/minimap/GatherMate2/provider/TSP/
  storage/TomTom/keybind state without changing saved data.
- Static gates: `wow_toc_validate` 0 errors; `wow_lua_lint` 0 errors/0 warnings on
  Forever, Retail, Classic Era, Mists, and TBC; `wow_xml_validate` 0 errors.

Still requires the live Forever client (section 6 matrix): visual minimap/world-map
checks under EllesmereUI, GatherMate2 route creation and live add/delete, edit/
taboo/cluster/TSP, auto show/hide with real tracking, and the TomTom waypoint loop
after installing TomTom 4.4.1. These are marked VERIFY above, not PASS.

---

## 1. Definition of done

The port is done when all of these are true:

- Routes loads on Forever with **zero Lua errors** at login and `/reload`.
- `/routes` opens the full options UI, and every existing options page still works.
- Every feature in the parity matrix below has been exercised in the live Forever
  client and marked **PASS**.
- Routes data is created from the installed GatherMate2 data, optimized, edited,
  clustered, tabooed, hidden/shown, and followed with TomTom waypoints on Forever.
- Route lines render correctly on the **world map**, **zone/battle map**, and
  **minimap** under:
  - the default Forever minimap,
  - the user's installed EllesmereUI minimap (round, square, and rectangular/cropped),
  - minimap rotation on and off,
  - indoors and outdoors.
- Existing `RoutesDB` layouts still load, and legacy `mapFile` zone keys still migrate.
- The addon still loads and behaves on Retail and the currently supported Classic
  flavors; no Forever fix is allowed to regress them.
- A reproducible staging/install path exists (embedded libraries included), and the
  packaged addon contains every file listed in the TOC.
- The saved-variables schema and user-visible behavior are unchanged except for
  compatibility fixes.

---

## 2. Client facts that drive the port

| Item | Value |
| --- | --- |
| Product / folder | `wowf` / `_forever_` |
| Build | `1.60.1.70862` |
| TOC interface | `16001` |
| Game type | `forever` (alias `camelot`) |
| Project ID | `WOW_PROJECT_CAMELOT = 18` |
| API family | Mainline 12.1.5-ish |
| Restrictions | Midnight-style secrets/disarmament rules are active |
| World layout | Old Azeroth / Forever content, built on modern `C_Map` data |
| Installed map/UI dependencies | GatherMate2 (`16001`), LibForeverData, EllesmereUI, FarmHud, WaypointUI, Questie |
| Installed TomTom | **No** (v4.4.1 supports Forever and must be installed for waypoint testing) |
| Installed addon folder | `_forever_\Interface\AddOns`; `DevFolder` is not loaded by the client |

**Important:** `DevFolder\Routes` is not a loaded addon. The client only loads addons at
`AddOns\Routes`. A deploy step is therefore part of the dev loop, not an afterthought.

Forever is **not** Classic. Do not regress the code to Classic globals; it is a
mainline-derived client with a different project ID and a much newer API surface.

---

## 3. What "100% feature parity" means here

The contract is the feature surface that exists in the current addon (see
`Locales/Locale-enUS.lua`), not new Forever-only features. Features that depend on
third-party addons remain conditional, exactly as they are today:

- **GatherMate2** — installed and must work fully.
- **Gatherer / GatherLite / HandyNotes** — keep the plugin paths and test any that
  are actually installed/available for Forever.
- **TomTom** — do not reimplement TomTom; install v4.4.1 (release notes explicitly
  cover Forever) and verify Routes' existing integration against it.
- **Cartographer** — only mentioned in old help text; no plugin exists today.

A feature that is disabled because its optional dependency is absent is parity, not a
gap. A feature that errors or silently does nothing when the dependency is present is a
gap.

---

## 4. Baseline inventory

### Source files

| File | Role |
| --- | --- |
| `Routes.lua` (~3,777 lines) | Core: map data, drawing, options, route/taboo editing, TSP glue |
| `TSP.lua` (~1,155 lines) | ACO + 2-opt/2.5-opt + background coroutines |
| `Routes.xml` | Two virtual map-pin templates |
| `Modules/AutoShow.lua` | Profession/tracking based route visibility |
| `Modules/TomTom.lua` | Waypoint integration and keybinds |
| `Plugins/GatherMate2.lua` | Node source + live node add/delete callbacks |
| `Plugins/Gatherer.lua`, `GatherLite.lua`, `HandyNotes.lua` | Optional node sources |
| `Locales/*.lua` | AceLocale strings |
| `Bindings.xml` | `ROUTESTTSTART`, `ROUTESTTSTOP`, `ROUTESTTCHANGEDIR` |
| `line.tga` | Route line texture |

### Current TOC

`Routes.toc:1` targets `120005, 120007, 11508, 50503, 20505`. It does **not** list
`16001`, so Forever treats the addon as out of date (and may not enable it depending on
the user's out-of-date setting).

### Libraries are not in the working tree

The TOC references `Libs\...`, but there is no `Libs` folder in `DevFolder\Routes`.
`.pkgmeta` fetches Ace3 and HereBeDragons externals for release builds; the local dev
tree has never been staged. The addon cannot run until that is fixed.

For local staging, the installed addons already contain compatible copies:

- Ace3 components: `GatherMate2\Libs\...`
- `AceHook-3.0`: `NaowhUI\Libs\AceHook-3.0`
- HereBeDragons: `GatherMate2\Libs\HereBeDragons` — **2.18-release**, which explicitly
  supports `WOW_PROJECT_CAMELOT` and has Forever-specific `worldMapData`.

Pin HBD 2.18 or newer; older HBD does not know Forever.

### Existing user data

- `_forever_\WTF\Account\...\SavedVariables\GatherMate2.lua` exists and contains
  imported herb data keyed by modern `uiMapID` values. That is enough to create a real
  test route on day one.
- No `RoutesDB.lua` exists yet, so the first run is a clean install. Test migration
  separately with a synthetic old-format DB.

### Current UI

`EllesmereUIMinimap` reparents the global `Minimap`, resizes it, and applies circle,
square, or 4:3-cropped masks. It also defines `GetMinimapShape` (`ROUND` or `SQUARE`),
which Routes already reads. The rectangular mode crops the square canvas with
`Minimap:SetHitRectInsets`; Routes does not currently account for that crop.

---

## 5. Findings: what must change, and why

Severity: **P0** = addon cannot load or the feature is broken; **P1** = likely broken or
unsafe on Forever; **P2** = polish/robustness.

| ID | Severity | Finding | Evidence | Fix |
| --- | --- | --- | --- | --- |
| F1 | P0 | TOC does not include Interface `16001`. | `Routes.toc:1`; `wow_toc_validate` reports the Forever client is not targeted. | Add `16001` and current build numbers; keep multi-flavor support. |
| F2 | P0 | `Libs` is absent from the source tree. | TOC lines 36–47; `wow_toc_validate` reports 12 missing files. | Stage/pin libs and add a reproducible vendor/install script. |
| F3 | P0 | `AutoShow` indexes tables with `GetSpellName(...)` results that may be `nil`. | `Modules/AutoShow.lua:26–29, 43–52`; `C_Spell.GetSpellName` returns nil for unknown spells. `Extract Gas` (`4036`) is TBC-era and GatherMate2 on Forever registers only Herb/Mining/Fishing/Treasure, so this is a real load-time crash candidate. | Nil-safe registration; map tracking by spell ID where possible. |
| F4 | P1 | The “edit taboo / route” path uses the non-mainline branch on Forever. | `Routes.lua:3155–3160`: `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` is false for `CAMELOT`, so it calls `ShowUIPanel(WorldMapFrame)` + `WorldMapFrame:SetMapID(zone)`. | Add `WOW_PROJECT_CAMELOT` to the retail-like branch and use `C_Map.OpenWorldMap(zone)`; keep the old branch for true Classic. |
| F5 | P1 | `GetCVar` is a legacy alias on current clients; lint flags it as moved. | `Routes.lua:417, 1086, 1089, 1248, 1560`; `wow_lua_lint` warnings. The global still exists in `Blizzard_SharedXMLBase/CvarUtil.lua`, but the namespaced form is the supported path. | Small helper: `C_CVar.GetCVar` with global fallback; prefer `C_CVar.GetCVarBool` for booleans. |
| F6 | P1 | Secret/restricted values can reach arithmetic. | Forever inherits Midnight secrets; minimap rotation is restricted during encounters. `Routes.lua:369–372` calls `GetPlayerFacing`; `Routes.lua:407` consumes HBD positions. | Guard with `issecretvalue`, `pcall` the HBD position read, and hide lines gracefully when values are secret. |
| F7 | P1 | Minimap shape/crop detection is incomplete. | `GetMinimapShape` is not a Forever global. Default minimap is round, Ellesmere defines it, but rectangular mode is reported as `SQUARE` with hit-rect crop. | Keep the guard, add mask/hit-rect fallback and crop-aware clipping. |
| F8 | P1 | Indoor/outdoor detection relies on comparing two CVars to `Minimap:GetZoom()`. | `Routes.lua:417`; `minimapZoom` and `minimapInsideZoom` are per-character and both default to 0, while custom minimap addons set zoom directly. | Prefer `IsIndoors()` when available, fall back to the old check. |
| F9 | P2 | Zero-length line path uses `cx, cy` before they are declared. | `Routes.lua:3695–3700` vs. `3703`. | Calculate the midpoint before the zero-length early return, or return early after clearing anchors. |
| F10 | P1 | An unsupported `GetMinimapShape` / `GetTrackingTexture` / `IsPlayerSpell` is reported by lint. | `Routes.lua:348`, `AutoShow.lua:69,100`. The first is guarded; the last two are in Classic-only branches. | Keep guards; ensure Forever never enters those branches. |
| F11 | P1 | TomTom is not installed, so the feature cannot be tested yet. | `_forever_/Interface/AddOns` listing. TomTom v4.4.1 release notes cover Forever. | Install TomTom v4.4.1 for tests; verify its `SetCustomWaypoint`/`RemoveWaypoint`/callback API. Contingency only: native `C_Map.SetUserWaypoint` fallback. |
| F12 | P1 | Optional plugins assume their addon is present in ways that can break on missing/updated addons. | `Plugins/*.lua:22` uses `UnitName("player")`; HandyNotes uses old `GetNodes2` but current HandyNotes master still provides it; HandyNotes iterator errors on zones with no data. | Guard plugin setup, nil-check iterator data where cheap; test only installed sources. |
| F13 | P2 | TOC uses Windows backslashes and a literal `@project-version@`. | TOC lines 36–74; `wow_toc_validate` warnings. | Normalize to forward slashes; keep the token for packaging or set a dev version. |
| F14 | P2 | `Bindings.xml` is not listed in the TOC. | TOC validator note. The client normally auto-loads `Bindings.xml`; verify keybinds appear. | Verify in client; do not add it to the TOC without confirming the schema behavior. |
| F15 | P2 | `GetTrackingInfo` is matched by localized name, not spell ID. | `Modules/AutoShow.lua:43–52, 83–93`. | Match `info.spellID` first, name fallback. |
| F16 | P2 | `G:DrawLine` uses a pooled texture and 8-argument `SetTexCoord`. | `Routes.lua:3670–3757`; 8-arg form is still used by Blizzard UI, so this is safe. | No API change, but keep the zero-length fix. |
| F17 | P0 | `WoW90` is derived from the TOC number (`>= 90000`), which is false for Forever's `16001`. The addon then runs pre-9.0 minimap paths on a mainline-derived client. | `Routes.lua:70`, `684`, `1365`, `1531`; the ad-hoc fengari smoke test failed at `Minimap:SetZoom` until this was fixed. | Treat `WOW_PROJECT_CAMELOT` as 9.0+ so `C_Minimap.GetViewRadius`/`IsIndoors` are used. |

### What is already healthy

Static analysis of the current source against the Forever API index found **no fatal
call sites**:

- `wow_lua_lint`: `Routes.lua` 0 errors / 9 warnings; `TSP.lua` 0/0; plugins 0/0;
  `AutoShow.lua` 0 errors / 2 warnings.
- `wow_xml_validate`: `Routes.xml` 0 errors / 1 harmless schema-location warning.
- Forever has `MapCanvasDataProviderMixin`, `WorldMapFrame:AddDataProvider`,
  `PIN_FRAME_LEVEL_MAP_HIGHLIGHT`, `PIN_FRAME_LEVEL_AREA_POI_BANNER`,
  `BattlefieldMapFrame`, `Minimap:GetZoom`, `C_Minimap.*`, `C_Map.*`,
  `C_SuperTrack.*`, `GetProfessions`, and `GetProfessionInfo`.
- HBD 2.18 provides Forever map data; GatherMate2 and HandyNotes are already
  Forever-aware.
- TomTom v4.4.1 explicitly supports Forever.

This is a **small, targeted port plus testing**, not a rewrite.

---

## 6. Feature parity matrix

Legend: **FIX** = known code change; **VERIFY** = must be tested in the live client;
**PASS** only after the evidence is recorded.

### 6.1 Drawing

| Feature | Required behavior | Status |
| --- | --- | --- |
| World map routes | Lines draw on the current world map, colors/widths per route and global defaults. | VERIFY |
| Zone / battlefield map | Battlefield map data provider draws routes on the zone map when available. | VERIFY |
| Minimap routes | Lines draw around the player on the minimap, including line gaps. | VERIFY |
| Minimap rotation | Lines rotate with `rotateMinimap`; no errors when facing is restricted. | FIX/VERIFY |
| Minimap shape | Round, square, and 4:3-cropped minimaps clip correctly. | FIX/VERIFY |
| Indoors | `draw_indoors` controls minimap drawing correctly. | FIX/VERIFY |
| Hidden routes | `Show hidden routes` and per-route hide behave as before. | VERIFY |
| Line gaps | Gaps around nodes; cluster gap skip setting works. | VERIFY |
| Widths/colors | Global and per-route world/minimap/zone-map widths and colors work. | VERIFY |
| Performance | Minimap redraw throttling; no per-frame table/string churn introduced. | VERIFY |
| Reparented minimap | Works after EllesmereUI reparents the global `Minimap`. | VERIFY |

### 6.2 Route creation and data sources

| Feature | Required behavior | Status |
| --- | --- | --- |
| GatherMate2 summary | Lists available node types/counts in the selected zone. | VERIFY |
| GatherMate2 append | Creates a route from selected GatherMate2 nodes. | VERIFY |
| GatherMate2 live add/delete | New/deleted nodes update matching routes via messages. | VERIFY |
| Gatherer plugin | Conditional; same summary/append/callback behavior. | VERIFY (if installed) |
| GatherLite plugin | Conditional; same. | VERIFY (if installed) |
| HandyNotes plugin | Conditional; notes summary/append; no errors in zones with no notes. | VERIFY/FIX |
| Create bare route | 3-point starter route creation. | VERIFY |
| Overwrite route | Name collision confirmation and overwrite. | VERIFY |
| Recreate route | Rebuilds from the original source selection. | VERIFY |
| Zone dropdown | Every Forever map with data is selectable, including duplicate names. | VERIFY |

### 6.3 Route management

| Feature | Required behavior | Status |
| --- | --- | --- |
| Per-route settings | Color, widths, hide, delete, reset. | VERIFY |
| Manual edit | Open map, drag nodes, left-click insert, right-click delete, save/cancel. | VERIFY |
| Taboo regions | Create, edit vertices, save/cancel, delete. | VERIFY |
| Apply taboo | Nodes inside taboo removed; new nodes refused; route avoids region where possible. | VERIFY |
| Clustering | Cluster, cluster in background, uncluster; metadata and radius. | VERIFY |
| TSP foreground | Optimizes and reports length/time. | VERIFY |
| TSP background | Non-blocking optimization, progress, completion/error messages. | VERIFY |
| Extra optimization | 2.5-opt toggle changes output. | VERIFY |
| Node cap / error paths | >724 nodes error and coroutine error reporting still work. | VERIFY |
| Route data integrity | Save/reload preserves nodes, metadata, taboos, visibility. | VERIFY |

### 6.4 Visibility, waypoints, UI

| Feature | Required behavior | Status |
| --- | --- | --- |
| Auto show/hide toggle | Master toggle works. | VERIFY |
| Profession visibility | Herbalism/Mining/Fishing/Treasure/others as configured. | FIX/VERIFY |
| Tracking visibility | Updates when tracking changes; matches Forever tracking info. | FIX/VERIFY |
| Skill changes | Updates when professions change. | VERIFY |
| TomTom start | Finds nearest visible node and sets waypoint. | VERIFY (TomTom 4.4.1) |
| TomTom stop | Removes the queued waypoint. | VERIFY |
| TomTom direction | Reverses node order. | VERIFY |
| TomTom hit distance | Advances when within configured yards. | VERIFY |
| Keybinds | All three Routes keybinds appear and work. | VERIFY |
| Options UI | All pages, tooltips, color pickers, dropdowns, keybinding widgets. | VERIFY |
| Slash commands | `/routes` opens options; `/routes <cmd>` works; localized command aliases. | VERIFY |
| Help file | All help pages render and scroll. | VERIFY |
| Localization | Fallbacks work on non-enUS clients; no missing-string errors. | VERIFY |
| SavedVariables | `RoutesDB` saves/reloads; legacy mapFile keys migrate. | VERIFY |

### 6.5 No-regression

| Feature | Required behavior | Status |
| --- | --- | --- |
| Retail 12.1.5 | Still loads and lints clean; no Forever-only branches fire. | VERIFY |
| Classic Era / Mists / TBC TOCs | Static validation and load where installed. | VERIFY |
| Multi-flavor TOC | Unsuffixed TOC still targets all listed interfaces. | VERIFY |
| Packaging | TOC files all exist; libs included; no backslash path failures. | VERIFY |

---

## 7. Implementation plan

Work in a branch named `forever-port`. Keep changes minimal and conditional; never
replace a multi-flavor code path with a Forever-only one.

### Phase 0 — Harness and baseline (before functional edits)

- [ ] Create branch `forever-port`.
- [ ] Add `tools/vendor-libs.ps1`:
  - copy Ace3 dirs from `GatherMate2\Libs`,
  - copy `AceHook-3.0` from `NaowhUI\Libs`,
  - copy HBD 2.18 `HereBeDragons-2.0.lua`, `HereBeDragons-Migrate.lua` (and optionally
    the full HBD dir) from `GatherMate2\Libs\HereBeDragons`,
  - fail loudly if a source is missing or HBD is older than 2.18.
- [ ] Add `tools/install.ps1 -Flavor forever|retail|classic`:
  - copy the source (including `Libs`) to the target `Interface\AddOns\Routes`,
  - preserve `WTF` (never touch saved variables),
  - print the exact `/reload` instruction.
- [ ] Add a dev-only `/routes selftest` module (can be disabled in release) that prints:
  - client build/interface/project ID,
  - HBD version and `mapData` zone count,
  - current zone name/ID, zone size, player position,
  - minimap shape/zoom/scale/size/view radius/rotation,
  - GatherMate2 active state and per-type counts for the current zone,
  - `WorldMapFrame` data provider/pin state,
  - TSP smoke test (synthetic 8–10 node route),
  - route storage round-trip,
  - TomTom presence/version and API surface.
- [ ] Run the static gates and record the baseline:
  - `wow_toc_validate` (expected: missing libs until staged),
  - `wow_lua_lint` per Lua file,
  - `wow_xml_validate` on `Routes.xml`.
- [ ] Install the staged addon with the current TOC and capture the first live
  load/reload errors with BugSack/`/console scriptErrors 1`. This is the baseline
  failure list, not a fix.

**Exit criteria:** reproducible staging, a baseline error log, and a selftest command.

### Phase 1 — Loadability and API shims

Files: `Routes.toc`, `Routes.lua`, `Modules/AutoShow.lua` (plus a small helper module if
it keeps the core readable).

- [ ] TOC: add `16001`; update current build numbers (`120100`, `11509`, `50504`,
  `20506`); keep the unsuffixed multi-flavor TOC. Normalize paths to `/` if packaging
  is in scope.
- [ ] Add `GetCVar` / `GetCVarBool` helpers using `C_CVar` with legacy fallback; replace
  the five direct calls.
- [ ] Add secret-value helpers:
  - `IsSecret(v)` using `issecretvalue` when present,
  - safe `GetFacing` (pcall + secret check),
  - safe HBD `GetPlayerZonePosition` read (pcall + secret check; hide lines on failure).
- [ ] Nil-safe `AutoShow` spell registration:
  - helper `AddProfession(name, spellIDs...)` only assigns when a spell name exists,
  - helper `AddTracking(type, spellID)` only assigns when present,
  - add a spell-ID → type table for tracking and use `info.spellID` first.
- [ ] Add `WOW_PROJECT_CAMELOT` to the retail-like map-open branch; use
  `C_Map.OpenWorldMap(zone)` there, keep `ShowUIPanel`/`SetMapID` for true Classic.
- [ ] Verify `GetMinimapShape` guard and add a fallback shape detector
  (`GetMinimapShape` → mask/hit-rect inference → round).
- [ ] Replace indoor detection with `IsIndoors()` when available, old CVar comparison
  otherwise.
- [ ] Fix the zero-length `G:DrawLine` midpoint bug.
- [ ] Ensure all new strings are added to `Locale-enUS.lua` (and leave other locales to
  AceLocale fallback).

**Exit criteria:** login and `/reload` produce no Lua errors; `/routes` opens; TOC
validator only reports non-fatal notes; selftest passes the load checks.

### Phase 2 — Map data and world map

Files: `Routes.lua` (map processing, data provider), `Routes.xml`, `Routes.toc`.

- [ ] Confirm HBD 2.18 is staged; verify `Routes.Dragons.mapData` has a non-zero zone
  count on Forever and that `processMapEntries()` populates `Routes.LZName`.
- [ ] Confirm a known zone (e.g. the user's herb-data zone) resolves name → `uiMapID` →
  HBD zone size; confirm no duplicate-name collisions break the dropdown.
- [ ] Confirm `WorldMapFrame:AddDataProvider` attaches the Routes provider at
  `PLAYER_LOGIN`; verify pins/refresh after map changes.
- [ ] Verify `RoutesPinMixin` uses `PIN_FRAME_LEVEL_MAP_HIGHLIGHT` and that lines render
  above terrain but below UI.
- [ ] Verify `BattlefieldMapFrame` provider creation and removal on enable/disable.
- [ ] Verify `Routes:DrawWorldmapLines` after zone changes, route edits, and options
  changes.
- [ ] Verify legacy `RoutesDB` mapFile keys migrate through HBD-Migrate; verify a
  duplicate-name zone does not merge routes.
- [ ] Add a debug dump (selftest) of zone count and current zone identity.

**Exit criteria:** a real route draws on the Forever world map in the correct zone;
navigating maps and reloading does not error; no zone is lost.

### Phase 3 — Minimap rendering

Files: `Routes.lua` (minimap draw), possibly a small shape helper.

- [ ] Validate `C_Minimap.GetViewRadius`, `Minimap:GetZoom`, `GetWidth/Height`,
  `GetScale`, `GetFacing` on Forever.
- [ ] Default round minimap: lines match route geometry and line gaps.
- [ ] Ellesmere round: same.
- [ ] Ellesmere square: same, corners included.
- [ ] Ellesmere rectangular/4:3: clip to the visible hit-rect height; no lines in the
  cropped bands (add a mask or crop-aware endpoint clipping).
- [ ] Rotation on: lines rotate with the map; rotation off: no rotation.
- [ ] Restricted-rotation encounter: no Lua error; either hide lines or draw unrotated
  in a defined fallback.
- [ ] Indoors/outdoors: `draw_indoors` behavior matches the option.
- [ ] Zoom changes and `MINIMAP_UPDATE_ZOOM` force a redraw.
- [ ] Performance: 60+ nodes in zone, no frame drops; no per-frame allocations added.
- [ ] `ReparentMinimap` path still works for UI addons that call it.

**Exit criteria:** visual parity across the four minimap configurations, no errors
during combat/encounters.

### Phase 4 — Data sources and route creation

Files: `Plugins/*.lua`, `Routes.lua` (source tables, route creation).

- [ ] GatherMate2:
  - verify `IsActive()`, `Summarize`, `AppendNodes`,
  - create a route from the user's existing herb data,
  - add/delete a node in GatherMate2 and verify the route updates,
  - verify `GetNodesForZone`, `DecodeLoc`, `GetNameForNode`, `GetIDForNode` still match
    the installed GatherMate2.
- [ ] Gatherer/GatherLite: keep conditional; if installed/available for Forever, test
  summary/append; otherwise mark “not installed” and verify no errors.
- [ ] HandyNotes: if installed, test `GetNodes2` and summaries; add a nil-zone guard so
  a zone with no notes does not error.
- [ ] Verify route creation with zero data shows the existing “No data found” message.
- [ ] Verify bare route creation, overwrite confirmation, recreate route.
- [ ] Verify auto add/delete callbacks are registered/unregistered with the options
  checkbox.

**Exit criteria:** at least one real route created from GatherMate2; auto-update works.

### Phase 5 — Route management and algorithms

Files: `Routes.lua`, `TSP.lua` (only if a real bug is found).

- [ ] Manual edit: open map, drag real/helper nodes, insert/delete, save/cancel.
- [ ] Taboo: create, edit vertices, save/cancel, delete, apply to route, node removal.
- [ ] Cluster: foreground and background; verify metadata, radius, line gaps.
- [ ] TSP foreground: verify result, length, time, and no hang on ~100 nodes.
- [ ] TSP background: verify progress, completion, and error reporting; ensure only one
  background job.
- [ ] Extra optimization toggle.
- [ ] Node cap >724 error path.
- [ ] Save/reload and verify all data survives.

**Exit criteria:** every route-management action completes without errors and the
saved data is structurally identical to the pre-port format.

### Phase 6 — Auto show/hide

Files: `Modules/AutoShow.lua`.

- [ ] Verify `GetProfessions`/`GetProfessionInfo` names on Forever and mapping to
  Herbalism/Mining/Fishing/ExtractGas/Archaeology.
- [ ] Verify tracking info fields (`name`, `active`, `spellID`) and the `MINIMAP_UPDATE_TRACKING` event.
- [ ] Verify “Always”, “With Profession”, “When active”, “Never” for each available type.
- [ ] Verify routes with multiple types show when any type qualifies.
- [ ] Verify skill changes update visibility.
- [ ] Verify hidden routes and `show_hidden` interaction.

**Exit criteria:** toggling herb/mining tracking on Forever changes route visibility
correctly; no load-time spell errors.

### Phase 7 — Waypoints (TomTom)

Files: `Modules/TomTom.lua`, `Bindings.xml` (only if binding loading is broken).

- [ ] Install TomTom v4.4.1 for Forever and confirm it loads.
- [ ] Verify `TomTom:SetCustomWaypoint(zone, x, y, opts)` and
  `TomTom:RemoveWaypoint(uid)` exist and accept Routes' options.
- [ ] Verify distance callbacks advance to the next node at the configured hit distance.
- [ ] Verify start/stop/change direction via options and keybinds.
- [ ] Verify `TomTom is missing or disabled` and “updated copy required” messages when
  TomTom is absent/old.
- [ ] Only if v4.4.1 breaks the old API: implement a native fallback using
  `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint`; keep the
  TomTom path first.

**Exit criteria:** full waypoint loop: start, arrive, auto-advance, reverse, stop.

### Phase 8 — Polish and packaging

- [ ] Update new/changed strings in `Locale-enUS.lua`; verify other locales fall back.
- [ ] Update help text if a behavior is clarified (no feature added).
- [ ] Set a sane development `## Version` or keep the packaging token.
- [ ] Normalize TOC paths to forward slashes.
- [ ] Confirm every TOC-listed file exists; confirm `Bindings.xml` auto-loads.
- [ ] Remove/disable selftest from release if desired, or keep it behind a debug flag.
- [ ] Package a zip that includes `Libs`; install from the zip into a clean addon folder
  and reload.
- [ ] Add a short `README`/install note for the Forever build.

**Exit criteria:** clean install from the package works; no missing-file errors.

### Phase 9 — Final parity sign-off

- [ ] Run the full matrix (section 6) in the live client.
- [ ] Run static gates on all flavors.
- [ ] Test with a clean `WTF` (no RoutesDB) and with a synthetic legacy DB.
- [ ] Test with the user's current EllesmereUI setup and with the default minimap.
- [ ] Test at least one indoor location, one outdoor zone, and one encounter/restricted
  situation.
- [ ] Record evidence (screenshots/selftest output) per row.
- [ ] Update this plan with PASS/FAIL and any accepted deviations.

**Exit criteria:** all rows PASS or explicitly accepted by the user.

---

## 8. Test plan

### Static gates (run after every meaningful change)

- `wow_toc_validate` on `Routes.toc` for `forever`, `mainline`, `classic`.
- `wow_lua_lint` on `Routes.lua`, `TSP.lua`, `Modules/*.lua`, `Plugins/*.lua`.
- `wow_xml_validate` on `Routes.xml`.
- `wow_api_diff` for every changed API call.

### In-game smoke tests

1. Back up `_forever_\WTF\...\SavedVariables` if a RoutesDB exists.
2. Install to `_forever_\Interface\AddOns\Routes`.
3. `/console scriptErrors 1`; `/reload`.
4. Check BugSack for zero errors.
5. `/routes selftest`.
6. `/routes`; open every options page.
7. Create a route from existing GatherMate2 herb data.
8. Optimize (background and foreground).
9. Edit a route; save; reload; verify.
10. Create a taboo; apply; verify nodes removed.
11. Cluster/uncluster; verify.
12. Toggle auto show/hide and tracking; verify.
13. Start/stop/reverse TomTom waypoints; verify auto-advance.
14. `/reload` and verify everything persists.

### UI configurations

| Config | Why |
| --- | --- |
| Default Forever minimap, round | Baseline |
| EllesmereUI round | User's actual UI |
| EllesmereUI square | Square shape path |
| EllesmereUI rectangular/4:3 | Crop path |
| Rotation on | `GetPlayerFacing` + rotation math |
| Rotation off | No rotation math |
| Indoors | `draw_indoors` |
| Combat/encounter | Secret/restricted values |

### Data scenarios

- Existing GatherMate2 herb data (the user's DB).
- A zone with no route/data (empty-state messages).
- A route with 3 nodes (edit minimum).
- A route with 100+ nodes (TSP/background).
- Duplicate zone names (collision handling).
- Legacy mapFile-keyed DB (migration).
- A route with a taboo and clustered metadata.
- A hidden route under `show_hidden` on/off.

### Negative scenarios

- TomTom absent / old.
- GatherMate2 absent.
- HandyNotes absent or installed with no notes in the zone.
- World map opened before/after player login.
- Minimap hidden or reparented by Ellesmere.
- Combat during route drawing/context menu.
- `/reload` while a background TSP job is marked running (should be cleaned).

---

## 9. Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Midnight secret values restrict map position/facing | Route draw errors or blank minimap | pcall + `issecretvalue`; hide lines in restricted contexts; test in encounter |
| HBD map data differs on Forever | No zones / wrong zone sizes | Pin HBD 2.18; selftest zone count and zone size; verify with GatherMate2 data |
| TomTom v4.x API changes | Waypoint feature broken | Pin/test v4.4.1; verify methods/callbacks before coding; native fallback contingency |
| Ellesmere/other UI replaces minimap | Lines missing or clipped | Use global `Minimap`; support `ReparentMinimap`; test all shapes/crops |
| TOC/interface changes in future Forever patches | Addon marked out of date | Include current interface; make a version check in selftest; update TOC per patch |
| Scope creep into upstream bugs | Port never ships | Fix only blockers; log unrelated bugs in a separate list |
| No automated UI test harness | Regressions slip | Selftest + explicit parity matrix + screenshots |

---

## 10. Open questions to answer in the live client

These are cheap `/dump`-style checks that decide code shape:

1. Does `GetSpellName(4036)` (`Extract Gas`) return nil on Forever? (Almost certainly
   nil; the guard is needed either way.)
2. What do `C_Minimap.GetTrackingInfo(i)` entries look like on Forever — are `name`,
   `active`, and `spellID` populated as expected?
3. Is `GetMinimapShape` nil under the default Forever minimap, and what does Ellesmere
   return in square/rectangular modes?
4. Does `IsIndoors()` match the old `minimapZoom` comparison in Forever caves/cities?
5. Is `WorldMapFrame` available at `PLAYER_LOGIN` (and does `AddDataProvider` work
   without a forced load)?
6. Does `BattlefieldMapFrame` exist/enable in Forever, and does the zone-map provider
   attach?
7. Does `TomTom:SetCustomWaypoint` in v4.4.1 accept Routes' 4-argument call and callbacks?
8. Do the `Bindings.xml` actions appear in the Forever keybindings UI without being
   listed in the TOC?
9. Are `minimapZoom`/`minimapInsideZoom` reliable with Ellesmere, or is `IsIndoors()`
   the only correct source?
10. What is the actual map ID/name of the user's herb-data zone, and does
    `Routes.LZName` round-trip it?

---

## 11. Deployment and dev loop

```
Source:  D:\World of Warcraft\_forever_\Interface\AddOns\DevFolder\Routes
Target:  D:\World of Warcraft\_forever_\Interface\AddOns\Routes
```

1. `tools/vendor-libs.ps1` (once, or after library updates).
2. `tools/install.ps1 -Flavor forever`.
3. In game: `/console scriptErrors 1`, `/reload`.
4. BugSack: check for errors.
5. `/routes selftest`.
6. After fixes: repeat install + `/reload`.

Never edit the installed copy as the source of truth. Do not touch `WTF` from scripts.
For packaging, produce a zip with `Routes.toc`, `Routes.lua`, `Routes.xml`, `TSP.lua`,
`Bindings.xml`, `line.tga`, `Locales`, `Modules`, `Plugins`, and `Libs`.

---

## 12. Appendix A — API evidence summary

- **TOC validator:** 12 errors (all missing `Libs` files), 27 backslash warnings, no
  Forever interface. This is expected before staging.
- **Lint:** `Routes.lua` 0 errors / 9 warnings (`GetCVar`, `OpenWorldMap`,
  `ShowUIPanel`, `GetMinimapShape`); `AutoShow.lua` 0 errors / 2 warnings
  (`IsPlayerSpell`, `GetTrackingTexture`); `TSP.lua` and plugins 0/0.
- **Forever API index:** 6,617 functions / 1,815 events / 1,759 tables; includes
  `C_Map`, `C_Minimap`, `C_SuperTrack`, `C_CVar`, `C_AddOns`, `C_KeyBindings`,
  `GetProfessions`, `GetProfessionInfo`, `IsIndoors`.
- **Forever UI source:** `WorldMapFrame:AddDataProvider`,
  `MapCanvasDataProviderMixin`, `PIN_FRAME_LEVEL_MAP_HIGHLIGHT`,
  `PIN_FRAME_LEVEL_AREA_POI_BANNER`, `BattlefieldMapFrame`, `Minimap:GetZoom`,
  `ToggleWorldMap`/`OpenWorldMap` are present.
- **HBD 2.18:** `WoWForever = (WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)` and a dedicated
  Forever `worldMapData` block; used successfully by GatherMate2 on this client.
- **GatherMate2:** TOC `16001`; only Herb Gathering / Mining / Fishing / Treasure db
  types; has imported herb data in the user's SavedVariables.
- **HandyNotes master:** `WOW_PROJECT_CAMELOT` support and `GetNodes2` still present.
- **TomTom v4.4.1:** release notes explicitly cover Forever and say existing addon
  hooks still work; not installed locally yet.

---

## 13. Appendix B — parity feature inventory source

Feature names and behavior above come from:

- `Routes.lua` options tree (`options.args`), route/taboo edit handlers, and drawing.
- `Locales/Locale-enUS.lua`:
  - Map Drawing: worldmap, minimap, zone map, indoors, widths, colors, hidden routes,
    line gaps.
  - Auto show/hide: Fishing, ExtractGas, Herbalism, Mining, Treasure, Archaeology,
    Note, Logging; Always / With Profession / When active / Never.
  - TomTom: start/stop/change direction, hit distance, keybinds.
  - Add: route name, zone, sources, data selection, bare route, overwrite, recreate.
  - Route config: line settings, hide, delete, reset, optimize, cluster, edit.
  - Taboo: create, edit, save/cancel, delete, apply.
  - Help: overview, route creation, optimization, display, taboos, waypoints,
    automatic updating, FAQ.
- `TSP.lua`: ACO, 2-opt, 2.5-opt, background coroutines, clustering.
- `Plugins/*.lua`: GatherMate2, Gatherer, GatherLite, HandyNotes.

---

## 14. Appendix C — references

- Installed client: `D:\World of Warcraft\_forever_` (1.60.1.70862, product `wowf`).
- Forever research brief:
  `D:\World of Warcraft\_forever_\Interface\AddOns\DevFolder\_research\wow-forever-tooling.md`.
- Warcraft Wiki 1.60.1 API changes:
  <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes>
- Gethe Forever UI source:
  <https://github.com/Gethe/wow-ui-source/tree/forever>
- HereBeDragons 2.18 (installed with GatherMate2).
- TomTom v4.4.1 release notes (WowInterface): <https://www.wowinterface.com/downloads/info7032-TomTom.html>
- HandyNotes master: <https://github.com/Nevcairiel/HandyNotes>

---

## 15. Immediate next actions

1. Stage the libraries and get the addon to load on Forever (Phases 0–1). This is the
   only work needed to turn “nothing loads” into “options open and a route can be made.”
2. Fix the `AutoShow` nil-spell load risk and the `CAMELOT` map-open branch before the
   first in-game test.
3. Create one real route from the installed GatherMate2 herb data and draw it on the
   world map and minimap.
4. Add TomTom v4.4.1 and test the waypoint loop.
5. Walk the parity matrix top to bottom; record PASS/FAIL in section 6.
