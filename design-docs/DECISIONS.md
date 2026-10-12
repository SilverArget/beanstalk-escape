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

## D-006 — GATE 1 production greybox and support model (2026-10-10)

- GATE 1 uses vector-drawn production greybox geometry until GATE 3A final art: 180-unit continuous trunk, 44-unit branches, and centers `[-150, 0, 150]`. The rejected source textures remain untouched and are not scaled down.
- Stage 1–2 player center is clamped to ±67, which keeps the 30-unit collider at least 8 units inside the 180-unit trunk. Ek A.1 safe centers map to world x `[-54, 0, 54]` for normalized `.20/.50/.80`.
- `BranchGraph` owns adjacent support connectivity and the 0.40-second transfer curve. `SupportState` explicitly records `SUPPORTED`, `TRANSFERRING`, and `FALLING_RECOVERY`; legacy movement names remain only as a compatibility surface for older QA scripts.
- Camera zoom remains 1.0 and smoothing is disabled while it is parented directly to the player; this removes the measured 12-pixel steady-state lag and locks the grip reference to rendered y=390. A later camera refactor may add independent soft x follow without changing this scale lock.
- No later-gate values were changed: vertical speed, stage count/length, spider, bean, wings, and hazard balance remain owned by their scheduled gates.

## D-007 — GATE 3A world ribbon UV and decoration correction (2026-10-12)

- Preserve the accepted `vine_surface_tile.png`, `foliage_atlas.png`, atmosphere plate, and M1/F1 reference lock; this correction generates no replacement art.
- Bind the atmosphere plate to the actual Camera2D screen center so branch-follow x movement cannot expose the project clear color.
- Map vine texture distance along each ribbon tangent, clamp the scale so a 52 px source element never exceeds the §5.1 54 px ceiling, and use two low-opacity non-mirrored phases on wide trunk/fork surfaces to suppress the source tile's centered chevron repetition.
- Do not place foliage-atlas cells at transfer midpoints or ordinary branch tips: their transparent padding makes the painted spiral appear unsupported. Split/branch silhouettes remain the gameplay support indicator; later decoration may return only with an explicit attachment anchor and rendered evidence.
