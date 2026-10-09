# Decisions

## D-001 — Production authority and scope (2026-10-10)

- Authority order is the owner's `CODEX-30-ETAP-BASLAT.md`, Master Production Brief v1.3, then the preserved identity/mechanics in `SPEC-v0.3.md`.
- The target is the complete 30-stage game. The only planned approval stop is S5 after GATE 3A; GATE 3B must not begin without the owner's dated `DEVAM`.
- Work remains on `full-30-stage`. Local safety branch `backup/full-30-stage-pre-gate0-823401a` preserves the starting point. No push or publication is authorized.

## D-002 — Character F1 identity and shared rig (2026-10-10)

- Owner decision overrides the generic §11 F1 clothing description: F1 keeps the approved GPT reference identity in `../../arastirma/gpt-sprites/raw/01-karakter-ref.png` and `02-poz-sayfasi.png` (red ponytail, turquoise tunic).
- F1 is not a separate frame-by-frame animation set. It will be rebuilt as the same named rig parts, canvas sizes, local pivots, hitbox, and single animation set used by M1–M3/F2–F3.

## D-003 — Artwork production and provenance (2026-10-10)

- Missing raster art is produced only through Codex `image_gen`; no CLI/API key, paid tool, or external asset purchase.
- The tool is asked for rigid rig parts, not poses or animation frames. Every accepted output records `Codex image_gen, <date>, owner decision 2026-10-10`, SHA-256, dimensions, alpha result, and scene usage.
- No artwork is produced until the §5.1 greybox frame measurement is available and reviewed.

## D-004 — §5.1 greybox targets (2026-10-10)

- Canonical targets live in `config/scale_lock.gd`: 108×44 character, 86×30 common collider, 180 trunk, 44 branch, 150 adjacent branch centers, 48 maximum repeated texture element, 12 grip detail, 120 gameplay leaf, 3 outline, zoom 1.0, reference y=390, HUD font 20.
- These values are inside every v1.3 interval. They are greybox targets, not evidence that current production gameplay or art already conforms.

## D-005 — Existing GPT vine art is preserved but rejected for production scale (2026-10-10)

- Existing 06/07/08-derived art stays on disk and remains in history.
- It is not scaled down for reuse: live code renders a ~590-unit trunk and ~182-unit branch with 240-unit centers, and prior owner frames show seams/ghost layers. New modular/seamless art must follow the locked greybox dimensions after Gate 1.
