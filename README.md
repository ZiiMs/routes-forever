# Routes for WoW Forever

Community compatibility port of **Routes**, the gathering-route addon created
by **Grum** and **Xinhuan** and maintained upstream at:

<https://github.com/Nevcairiel/Routes>

This repository is not the original project. The upstream addon, its design,
and its original code remain the work of Grum, Xinhuan, and the upstream
contributors. The Forever port changes here are layered on top of that history.

## What this port adds

- WoW Forever (Camelot) interface `16001` support.
- A reproducible library staging/install/package flow.
- Forever-specific API, minimap, secret-value, and optional-plugin fixes.
- `/routes selftest` for in-game diagnostics.

See [README-Forever.md](README-Forever.md) for installation, packaging, and
the live-client test checklist. The full port notes are in
[FOREVER_PORT_PLAN.md](FOREVER_PORT_PLAN.md).

## Upstream credit

Routes is All Rights Reserved by its original authors. This repository is a
community compatibility port and does not claim ownership of the original
addon. Please report upstream bugs to the original project as well; Forever
port issues belong here.
