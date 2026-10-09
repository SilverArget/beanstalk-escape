# Implementation Progress

## 2026-10-10 — GATE 1 production checkpoint

- Applied `ScaleLock` to production: rendered character 44×108 at y=390, collider 30×86, trunk 180, branches 44, adjacent centers 150, zoom 1.0, and fully painted viewport.
- Replaced live use of the rejected oversized vine/player textures with reversible vector greybox rendering. Original assets remain untouched for provenance; final art remains GATE 3A work.
- Added `BranchGraph` and explicit `SUPPORTED / TRANSFERRING / FALLING_RECOVERY` state. A single accepted press traverses one adjacent real curve in 0.40 seconds; collider and visual share the player transform; invalid support falls and reaches death instead of hovering.
- `CHANGE BRANCH` is absent in Stage 1–2 and gated in Stage 3 until the split/targets enter the viewport.
- `tests/test_gate1.gd`: T01–T05 = 5 PASS / 0 FAIL. `tests/capture_gate1_frames.gd`: 6 rendered frames = 6 PASS / 0 FAIL using windowed Godot 960×540 and exact pixel scans.
- Evidence: `../03-test/qa/scale/production-measurements.json` plus six PNGs in that directory. Media was not auto-opened; every cited frame was inspected in-process for bounds, pixel spans, opacity, support state, and hint state.
- Known compatibility result: the pre-Gate-1 `test_tur1.gd` produced 7 PASS / 1 FAIL because its 180-iteration assertion assumes 60 physics ticks/sec; the production contract now runs 120 ticks/sec and the new T01 measures 120 ticks as one second. `test_gate_a.gd` was stopped after obsolete 60 Hz/state-name assumptions produced failures; it is not counted as a completed regression run.
- No push, publish, payment, deletion, `master`, `02-kod/docs`, or root `KONTROL-LISTESI.md` change.
