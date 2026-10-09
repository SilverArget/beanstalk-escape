# Quality Report

## Checkpoint: GATE 0 complete / GATE 1 §5.1 started — 2026-10-10

Environment: Windows, Godot `4.7.2.stable.official.ed1daf0bf`, branch `full-30-stage`, start HEAD `823401a63788ff842f4e0748c142a94c59af27bb`. Backup branch: `backup/full-30-stage-pre-gate0-823401a`.

### Item status

| Item ID | Status | Evidence / finding |
|---|---|---|
| GATE 0 | PASS | Required v1.3/spec/prior-report/live source/license audit completed; safety branch, import, test baseline, correction matrix, repo rules, decisions, and progress record created. |
| GATE 1 | NOT RUN | Only the first §5.1 numeric greybox substep has started; transfer/camera/support production changes are not part of this checkpoint. |
| §5.1-greybox-numeric | PASS | `../03-test/qa/scale/measurements.json`; 15/15 numeric checks within v1.3 intervals. |
| §5.1-greybox-frame | NOT RUN | Headless renderer produces no frame; opening a visible media window is forbidden by project instructions. No visual result is claimed. |
| T02 | NOT RUN | Greybox numeric targets exist, but current gameplay/art still violates scale and no rendered frame was inspected. |
| VIS02 | FAIL | Live code/current known frames: character ~63 px; trunk ~590; fails v1.3 scale. |
| VIS11 | NOT RUN | Requires inspected annotated real gameplay frames for Stage 1, Stage 3, and storm. |
| VIS12 | FAIL | Owner evidence records seams/ghost layers at Stage 2 right and 2→3, 3→4, 4→5 boundaries. |
| T23-real-Android | NOT RUN | Real Android hardware is owned by the main session; no emulator can close this row. |
| §22-no-push | PASS | No push/publish/submit/payment performed. |

### Baseline tests

Command pattern: `Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path 02-kod --script <test>`.

| File | PASS | FAIL | NOT RUN / note |
|---|---:|---:|---|
| `03-test/gate-b/test_gate_b.gd` | 3 | 0 | 0 |
| `03-test/gate-b/test_gate_b_fix.gd` | 7 | 0 | 0 |
| `03-test/godot/test_gate_a.gd` | 9 | 0 | 0 |
| `03-test/godot/test_gate_a_visual.gd` | 0 | 0 | 1 — headless trace only, no visual claim |
| `03-test/godot/test_tur1.gd` | 8 | 0 | 0 |
| `03-test/godot/test_tur2.gd` | 5 | 0 | 0 |
| `03-test/godot/test_tur3.gd` | 8 | 0 | 0 |
| `03-test/godot/test_tur3b.gd` | 5 | 0 | 0 |
| `03-test/godot/test_tur4.gd` | 9 | 0 | 0 |
| `03-test/gpt-sprite/test_gpt_sprites.gd` | 7 | 0 | 0 |
| `03-test/gpt-sprite-duzeltme/test_sprite_fixes.gd` | 21 | 0 | 0 |
| `03-test/godot/test_scale_lock.gd` | 15 | 0 | 2 — Stage 1/3 frames NOT RUN |

Godot import: PASS. Existing suites emit ObjectDB/resource leak warnings and `Image.load` export warnings; these are open cleanup defects, not hidden FAILs.

Browser baseline: `npm.cmd test` in `03-test/playwright` — 8 PASS, 0 FAIL, 2 expected project-bucket skips in 13.1 minutes. Per file: `desktop.spec.js` 4/0/0, `gpt-doku.spec.js` 1/0/0, `gpt-doku-duzeltme.spec.js` 1/0/0, `mobile.spec.js` 2/0/2. Generated screenshots/videos were not opened, so these runs support state/input regression only; they are not a visual-review or real-device PASS.

Report discrepancy: Playwright CLI reports 8 passed, but `03-test/playwright/RAPOR.md` records only the six S1–S6 scenarios; the two GPT texture specs do not register themselves in that custom report. CLI output is the authoritative count for this checkpoint; report plumbing remains an open test-infrastructure fix.

### Live code vs v1.3 correction matrix

| Item ID | Live HEAD finding | v1.3 target | Next correction |
|---|---|---|---|
| T01/T13 | `PLAYER_VERTICAL_SPEED=180`, `STAGE_COUNT=5`, 5400-unit stages | 100 units/s; 30 stages; 2800/3000 lengths | Data/physics migration after Gate 1 core support model. |
| T02/VIS02 | Player ~63 px, trunk 590, branch 182, centers 240 | 108×44, trunk 180, branch 44, centers 150 | Apply `ScaleLock` targets to actual player/branch/camera geometry. |
| T03 | Transition is 0.30 s and X interpolation; baseline one press works | 0.40 s on real branch connection/spline, swept collision | Replace lane-only interpolation with BranchGraph support transfer. |
| T04 | `on_support=false` freezes vertical movement during transition; nearest-X route still central | Explicit support state, bounded transfer, falling recovery | Implement support/transfer/recovery state machine. |
| T06 | Old 0.88→1.0 ramp, max 288; no pressure bands/catch-up | §6 full formula, pressure table, K1/K2 | Gate 2. |
| T07 | Warning 0.60 s; current tests assert 0.50–0.70 | ≥1.60 s visible warning and reaction budget | Gate 2; old tests must be superseded, not silently edited. |
| T10/T12 | Time exists; touch path is split between direct call and synthetic actions | Shared command router, 10 s active time | Gate 2. |
| T11/T13 | Fire/H and stages 6–30 absent | Fire at Stage 10; all 30 data-driven stages | Gates 4–6. |
| T18 | One combined pose set, no shared-part rig/six skins | One rig, six skins, identical parts/pivots/hitbox | Gate 3A/3B after scale frame. |
| VIS12 | Existing textures have known seams/ghost layers | Three-module seam count 0 | Replace art after Gate 1, then inspect real frames. |
