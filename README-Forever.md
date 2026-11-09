# Routes on WoW Forever

This branch adds WoW Forever (`_forever_`, build 1.60.1.70862, Interface `16001`,
`WOW_PROJECT_CAMELOT`) support without dropping Retail or Classic.

## Install for development

From this folder:

```powershell
# Copy Ace3, AceHook, and HereBeDragons 2.18+ into .\Libs, then install
.\tools\install.ps1 -Flavor forever
```

The script only writes `_forever_\Interface\AddOns\Routes`. It never touches
`WTF` or `RoutesDB`. `Libs/` is generated and gitignored; run
`tools/vendor-libs.ps1` once after a fresh checkout (the install/package
scripts run it automatically when it is missing).

In game:

```
/console scriptErrors 1
/reload
/routes selftest
/routes
```

`/routes selftest` prints client/build, HereBeDragons map counts, the current
zone, minimap shape/crop/rotation, GatherMate2 counts, the world-map data
provider state, a small TSP smoke test, route storage round-trip, and TomTom
availability. It is read-only.

## Install from a package

```powershell
.\tools\package.ps1
```

Extract the resulting `dist\Routes-<version>.zip` into
`Interface\AddOns`, then `/reload`. The zip includes every file in `Routes.toc`
and the embedded libraries.

## Dependencies on Forever

- **HereBeDragons 2.18+** is required. The vendor script checks the version and
  refuses older copies; 2.18 is the first release with Forever map data.
- **GatherMate2** is the primary node source and is already Forever-aware.
- **TomTom 4.4.1+** is optional. Install it to test waypoints; without it the
  TomTom options are disabled and Routes prints the existing "missing or
  disabled" message instead of erroring.
- **HandyNotes**, **Gatherer**, and **GatherLite** remain optional. Their
  plugins are nil-guarded and do nothing when the addon is absent.

## Minimap notes

The stock Forever minimap is round. EllesmereUI's round, square, and
rectangular/4:3 modes are supported:

- `GetMinimapShape` is used when an addon provides it (EllesmereUI does).
- When it is absent, the mask texture is used to infer round/square.
- Rectangular mode reports `SQUARE` but crops the canvas with
  `SetHitRectInsets`; Routes clips minimap line segments to the visible band.
- Rotation is read through `C_CVar` and facing is guarded with
  `issecretvalue`/`pcall`, so restricted encounter values hide the minimap
  lines instead of throwing.

## What still needs a live client pass

The static port is complete. The parity matrix in `FOREVER_PORT_PLAN.md` (section
6) still needs to be walked in game for screenshots/PASS evidence, especially:

- world map, battlefield map, and minimap drawing with EllesmereUI;
- GatherMate2 route creation and live add/delete callbacks;
- manual edit, taboo, cluster, and foreground/background TSP;
- auto show/hide with Herbalism/Mining tracking;
- TomTom start/arrive/advance/reverse/stop after installing TomTom 4.4.1.
