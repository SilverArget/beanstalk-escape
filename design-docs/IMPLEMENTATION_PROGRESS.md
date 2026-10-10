# Implementation Progress

## 2026-10-10 — GATE 1 T04 closure checkpoint

- Fixed same-tip recovery looping with red-first coverage: visible physical branch ends, explicit recovery-edge eligibility, 120 u/s initial fall, and 600 u/s² gravity.
- Captured and measured dead-end/fall production frames; migrated named legacy assertions; `sprite_fixes` now exits 21/0 without hanging.
- Fresh PCK SHA-256: `8C2E37DCE7987A25006EC1E2F1F07F081E8823BFDB67C36EDA47AF6D8E32BF80`.
- Final clean single-worker Playwright run did not complete inside the limit; GATE 1 remains open and GATE 2 was not started.

## 2026-10-10 — GATE 1 production checkpoint

- Applied `ScaleLock` to production: rendered character 44×108 at y=390, collider 30×86, trunk 180, branches 44, adjacent centers 150, zoom 1.0, and fully painted viewport.
- Replaced live use of the rejected oversized vine/player textures with reversible vector greybox rendering. Original assets remain untouched for provenance; final art remains GATE 3A work.
- Added `BranchGraph` and explicit `SUPPORTED / TRANSFERRING / FALLING_RECOVERY` state. A single accepted press traverses one adjacent real curve in 0.40 seconds; collider and visual share the player transform; invalid support falls and reaches death instead of hovering.
- `CHANGE BRANCH` is absent in Stage 1–2 and gated in Stage 3 until the split/targets enter the viewport.
- `tests/test_gate1.gd`: T01–T05 = 5 PASS / 0 FAIL. `tests/capture_gate1_frames.gd`: 6 rendered frames = 6 PASS / 0 FAIL using windowed Godot 960×540 and exact pixel scans.
- Evidence: `../03-test/qa/scale/production-measurements.json` plus six PNGs in that directory. Media was not auto-opened; every cited frame was inspected in-process for bounds, pixel spans, opacity, support state, and hint state.
- Known compatibility result: the pre-Gate-1 `test_tur1.gd` produced 7 PASS / 1 FAIL because its 180-iteration assertion assumes 60 physics ticks/sec; the production contract now runs 120 ticks/sec and the new T01 measures 120 ticks as one second. `test_gate_a.gd` was stopped after obsolete 60 Hz/state-name assumptions produced failures; it is not counted as a completed regression run.
- No push, publish, payment, deletion, `master`, `02-kod/docs`, or root `KONTROL-LISTESI.md` change.

## 2026-10-10 — GATE 1 legacy-migration checkpoint

- Added read-only browser field `support_state` while preserving compatibility `transition_state`; Playwright helpers/specs now consume the v1.3 field and use the production `[-150, 0, 150]` branch centers.
- Migrated legacy 60 Hz elapsed-time/frame assertions to `Engine.physics_ticks_per_second` (project value `120`) and migrated support assertions to `SupportState`.
- Fixed two Gate 1 defects exposed by the migration: curved-branch X is re-centered after vertical movement, and simultaneous commands preserve the first accepted direction instead of overwriting it.
- Updated Gate B assertions superseded by §5.1 to the locked `44×108` player, `30×86` collider, `44` branch width, `150` center gap, and fully opaque vector greybox. The displaced assertions and v1.3 replacements are listed in `QUALITY_REPORT.md`.
- Completed final-run results before time limit: Gate B `3/0`, Gate B fix `7/0`, Gate A `9/0`, scale lock `15/0/2 headless-frame NR`, Tur1 `8/0`, Tur2 `5/0`, Gate1 `5/0`. The long Tur3 matrix was interrupted at the 50-minute limit; later files, fresh web export, and Playwright remain NOT RUN.
- GATE 1 remains open. Next command must resume with Tur3 onward, then run windowed visual tests, export Web, record `index.pck` SHA-256, and run `npm.cmd test` per spec.
