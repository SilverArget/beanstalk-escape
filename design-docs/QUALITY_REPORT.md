# Quality Report

## Checkpoint: GATE 3A step 1 correction — §12.1 M1/F1 rig pilot (2026-10-11)

| Item ID | Status | Evidence / open work |
|---|---|---|
| Findings 1–5 / §11 / §12.1-3 | PASS rendered | Clear faces; rear harness/wing layering; coherent side/three-quarter climb; four grip/contact poses; no detached red clusters; visible purple wing opening. |
| §5.1-character / VIS02 / VIS11 | PASS pilot | 960×540: 101 px high, 43–47 px wide, center y=396 (73.3%), contour 3 px, grip 12 px, surface overlap 0 px. |
| Joint/contact/wing seam | PASS pilot | Joint gaps 0 px; hand/foot contact 0–2 px; wing-anchor seam 0–2 px. |
| §12.1-5 evidence | PASS | 150 PNG frames/skin; 155-frame 960×540 H.264 MP4/skin at 30 FPS. |
| GA08 windowed | PASS | 5/0 at t=62/64/66/68/70; `ASSERT CHANGE §12.1-2` samples 6 px below the 108 px art bound. |
| Targeted/current regression | PASS | rig 8/0, stage DB 5/0, runtime 5/0, fairness 8/0, gate1 7/0, tur4 7/0, tur3b 5/0; `test_tur3` reached 6/8 with no FAIL before budget interruption. |
| Full Godot regression | NOT RUN complete | `test_tur3` final 2 assertions and subsequent short files were not completed in this correction turn. Do not claim 0 FAIL for the full suite. |
| Web export | PASS | Release PCK SHA-256 `7B95EBEE4BCCD12AF7DA181F0D696BD9F82007CA800D4AEBE689C9463DCB680D`, 15,546,776 bytes. |

Pilot visual findings are closed, but reference status remains gated by the incomplete full regression.

### Superseded initial pilot checkpoint

| Item ID | Status | Evidence / open work |
|---|---|---|
| §12.1-2 / §11 shared rig | PASS automated | `CharacterRig` has 22 named parts/states, one hierarchy/pivot grid, shared 44×108 contract, unchanged 30×86 collider and seven pilot animations. `test_gate3a_rig.gd` 8/0. |
| F1 owner identity | PASS source / HUMAN REVIEW REQUIRED render | F1 sheet was generated from both approved source images; red ponytail + turquoise tunic are present in the generated sheet. Rendered gameplay identity inspection is open. |
| RGBA / no opaque rectangle | PASS automated | Both 1254×1254 sheets are ARGB, >70% sampled alpha=0, all outer corners alpha=0; active main scene no longer executes the `#152238` greybox rectangle. |
| §5.1-character | NOT RUN rendered | Numeric contract remains 15/15; Stage 1/3/storm pilot-art screenshots were not captured or inspected. |
| VIS02 / VIS11 | NOT RUN | No rendered 960×540 pilot measurement. |
| §12.1-3 joint/contact/wing seams | NOT RUN | Requires 30 FPS rendered key/intermediate frames and pixel measurements. |
| T18 partial | PASS automated / NOT RUN visual | Same animation signature mounts on M1/F1; visual skin equivalence is not claimed. |
| GA08 | NOT RUN windowed | Headless trace is 0/0 by design. Windowed run was not launched under the repository's media auto-open rule. |
| Full Godot regression | PASS headless | 17 files: 125 PASS / 0 FAIL; GA08 visual script is 0/0 headless by design. `test_gate_b_fix.gd` initially failed its obsolete `player_visual.gd` path assertion; expectation was migrated with `ASSERT CHANGE §12.1-2` and reran 7/0. |
| Web export | PASS | Fresh debug Web PCK: SHA-256 `C4F8A9AB51ADAC50989041C17C3E232ECC847396EFC5E41539DD58B3CED6E821`, 15,544,072 bytes. |

Reference lock remains `PARTIAL_NOT_LOCKED`; do not start remaining skins or bulk animation states.

## Checkpoint: GATE 2 runtime encounters, spider, and Time Wings — 2026-10-10

| Item | Result | Evidence |
|---|---|---|
| G2-RUNTIME-01 | PASS | Stage 1–2 expose five data-owned GUIDE/BULGE features each. Stage 3 derives five FORK support windows from `StageDatabase`; missing supports end visibly for A..A+220 and return afterward. |
| T06 slice | PASS | Six-band pressure data, full speed equation, 420/365 catch-up hysteresis with 0.50 s blend, 5-level gap gauge, three-route claw catch, and retry gaps 240/180 are covered. K1/K2 and 30-stage double-skill simulation remain NOT RUN. |
| T07 slice | PASS | Warning starts at W=A−360, is visible/audible for at least 1.60 active seconds before height-triggered release, one projectile gives one penalty, and bean factor refreshes without stacking for 2.00 active seconds. Fire reaction-budget coverage remains NOT RUN. |
| T10/T12 slice | PASS | TIME unlocks at Stage 5, keyboard/mobile share `dispatch_command`, lasts exactly 10 active seconds, freezes during pause, leaves player/global time unchanged, and halves bean/spider threat movement. Later hazard clocks remain owned by their gates. |
| Targeted Godot | PASS | `test_gate2_runtime.gd` 5/0, `test_gate2_stage_database.gd` 5/0, `test_gate1.gd` 7/0. Existing ObjectDB/resource-exit warnings remain open cleanup work. |

This checkpoint does not claim anti-cheese, ReachabilityValidator/ReplayVerifier, rendered visual acceptance, browser acceptance, K1/K2, or full 30-stage skill simulation.

## Checkpoint: GATE 1 death/confirm/browser closure — 2026-10-10

| Item | Result | Evidence |
|---|---|---|
| T04 death cause/freeze | PASS | `death_cause=FALL`, fall-specific HUD copy, post-death player delta `0.000`; catches require gap `<=28` plus the three-route claw span. |
| Confirm edge | PASS | One Enter keydown and one tap during the guard each produce exactly one restart. |
| Browser | PASS | Fresh PCK `B727F8D...D30D4C6`; single-worker full run 8 PASS / 0 FAIL / 2 expected skips. S1/GPT/GPT-fix each 2/2 complete. |
| Godot | FAIL (timeout) | 13 files exited with zero assertion failures. `test_tur3.gd` passed its first 6 assertions, then exceeded 600 s in the sequential 10-seed/2-pressure matrix. |
| GATE 1 | NOT CLOSED | Browser and product acceptance pass; one requested fresh full Godot file remains incomplete. GATE 2 not started. |

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

## Checkpoint: GATE 1 production greybox — 2026-10-10

Windowed command: `Godot_v4.7.2-stable_win64_console.exe --path . --resolution 960x540 --script res://tests/capture_gate1_frames.gd`. The process saved frames without launching a media viewer and inspected each saved frame by exact pixel sampling.

| Item ID | Status | Evidence / measurement |
|---|---|---|
| T01 | PASS | `tests/test_gate1.gd`: 120 physics ticks climb 180 units; no manual jump/climb actions. |
| T02 | PASS | Production frame: character 44×108, reference y=390, trunk 180; Stage 3 branches 44 with centers 329.5/479.5/629.5. Collider 30×86; trunk safe centers preserve 8-unit inset. |
| T03 | PASS | One press, one adjacent branch, 48 ticks at 120 Hz = 0.400 s; sampled curve error 0.000; final state `SUPPORTED`. |
| T04 | PASS | Missing support enters `FALLING_RECOVERY`, falls 91.042 units, then reaches `PLAYER_DEAD`; no unsupported auto-climb/hover. Later web/breaking-branch hazard integration remains owned by their gates. |
| T05 | PASS | Arrival center error 0.000; shared transform resets; one hit increments one penalty. |
| VIS02 | PASS (greybox) | `production-stage1.png`; rendered bounds/position/trunk pixel span pass. Final-art/anatomy review remains GATE 3A. |
| VIS03 | PASS (greybox) | Supported/mid-transfer/end rendered frames; three 44-unit supports and transfer state/character pixels present. Final-art natural-motion review remains GATE 3A. |
| VIS12 | PASS (greybox) | Two additional 144-unit scroll captures: trunk spans 180 on all sampled rows, seam count 0, `CHANGE BRANCH=false`, alpha holes 0. Final-art seam test remains GATE 3A. |
| GATE 1 | NOT RUN overall / core PASS | Core player/branch/camera/support contract and related unit/render checks pass. Gate closure still requires a fresh web export/browser regression; the existing export predates these source changes. |

Per-file counts: `tests/test_gate1.gd` 5 PASS / 0 FAIL; `tests/capture_gate1_frames.gd` 6 PASS / 0 FAIL. Compatibility run `../03-test/godot/test_tur1.gd` 7 PASS / 1 FAIL (obsolete 60-tick iteration assumption); partial `test_gate_a.gd` is NOT RUN as a complete file and is not included in pass totals.

## Checkpoint: GATE 1 legacy migration — 2026-10-10

Project physics remains `120 Hz`; legacy elapsed-time assertions now derive seconds and frame budgets from `Engine.physics_ticks_per_second`. Support assertions use `SUPPORTED / TRANSFERRING / FALLING_RECOVERY`, and Playwright reads the new read-only `window.beanstalkState.support_state` field. The compatibility `transition_state` field remains read-only and present.

| Item ID | Status | Evidence / open work |
|---|---|---|
| T01–T05 | PASS | `tests/test_gate1.gd`: 5 PASS / 0 FAIL after exact post-move support-centering and first-command-wins touch arbitration fixes. |
| Legacy-contract-migration | PASS (edited) | External `../03-test` tests migrated from 60-tick timing and `ATTACHED/TRANSITION` assertions; no assertion was silently deleted. |
| Godot-13-file-regression | NOT RUN complete | Completed this call: `test_gate_b` 3/0, `test_gate_b_fix` 7/0, `test_gate_a` 9/0, `test_gate_a_visual` 0/0 headless trace, `test_scale_lock` 15/0/2 headless frames, `test_tur1` 8/0, `test_tur2` 5/0, `test_gate1` 5/0. `test_tur3` was interrupted at the 50-minute call limit; `test_tur3b`, `test_tur4`, `test_gpt_sprites`, and `test_sprite_fixes` were not reached in the final run. |
| Web-export / browser | NOT RUN | Fresh export and `npm.cmd test` were not started before the call limit. Existing `index.pck` is stale: SHA-256 `109fd02a8a80674ccaa897ae85cec3d198e5037c907a22c5c8f098ffb0c49798`. |
| GATE 1 | NOT RUN overall | Cannot close until the 13-file run, fresh export, and per-spec Playwright run complete. |

### Superseded legacy assertions (retained here; no silent deletion)

| Legacy assertion | Replaced by v1.3 |
|---|---|
| Player opaque height `63 px` and capsule `r15/h44` | §5.1 scale lock: character `44×108`, collider `30×86` (`T02`, `VIS02`). |
| Cloud atlas must contain four legacy raster clouds | §5.1 Gate 1 production greybox may be vector/opaque; final art asset acceptance moves to GATE 3A. |
| Legacy Stage 3 branch draw budget tied to old art constants | §5.1 branches `44` wide at `150` centers; final art/performance acceptance moves to GATE 3A. |
| Transfer has zero vertical travel while unsupported | §4.3–4.4: real 0.40 s connection curve, `TRANSFERRING`, then `SUPPORTED` or `FALLING_RECOVERY` (`T03`, `T04`). |

## Checkpoint: GATE 1 T04 closure attempt — 2026-10-10

| Item ID | Status | Evidence / open work |
|---|---|---|
| T04 | PASS (Godot/render) | Red test reproduced 35 recovery entries/70 false-supported frames. Fix gives one recovery, zero reattach, initial `vy=120`, gravity `600`, 79.625-unit fall, 0.350 s death. |
| VIS03-end/fall | PASS | Windowed 960×540: dead branch absent above its visible cap, adjacent branch width 44; fall frame `FALLING_RECOVERY`, `vy=215`, remaining 0.192 s. |
| Godot-13-file-regression | PASS before final summit fix | 3/0, 7/0, 9/0, visual trace, 15/0, 8/0, 5/0, 6/0, 5/0, 9/0, 7/0, 21/0, 5/0. Post-fix Gate1 rerun 5/0; complete post-fix rerun NOT RUN. |
| Legacy migration | PASS (edited) | A10b 0.400 s; A15/A15_full → §6/T06; A18/GA10 → §4.4; GPT/FIX IDs retained with §5.1/ART_ASSET_GAP replacements. `sprite_fixes` exits 21/0 without hang. |
| Web export | PASS | PCK SHA-256 `8C2E37DCE7987A25006EC1E2F1F07F081E8823BFDB67C36EDA47AF6D8E32BF80`. |
| Browser regression | NOT RUN complete | Final clean single-worker `npm.cmd test` did not finish inside the call limit; four-worker real-time run was invalid under contention. |
| GATE 1 | NOT RUN overall | T01–T05/render pass; closure still requires one clean single-worker browser run. GATE 2 not started. |

Additional retained supersessions: A15/A15_full max distance 288 → §6/T06; A18 stop/resume and GA10 same-support recovery → §4.4; GPT/FIX texture/hitbox contracts → §5.1 plus ART_ASSET_GAP/GATE 3A.

### Gate 2 legacy supersessions retained at closure

| Legacy assertion | v1.3 replacement and active coverage |
|---|---|
| A08 seeded RNG must produce multiple patterns | Ek A fixed `canonical_v1` + `mirror_v1` catalog; `A08_v13`, `G2-DATA-04`. |
| A17 Stage 2 center-first / Stage 3 ordered random closures | Ek A encounter recipes and Stage 3 FORK windows; `A17_v13`, `G2-DATA-03/04`, `G2-RUNTIME-01`. |
| A14 spider ratio capped at 1.0 above 420 px | §6 catch-up hysteresis/full formula; `A14`, `T06`. |
| A20 TIME ratio measured against fixed 0.88 base | §6 gap/catch-up formula, then §9 0.50 threat factor; `A20`, `T10`. |
| FIX11/FIX14/FIX21 GPT source-string contracts | §5.1, §4.4, `T04`, `VIS03`, `G2-RUNTIME-01`; final art remains GATE 3A. |

Active migrated behavior remains asserted: GA03 samples an actual open FORK interval; GA06/GA07 follow the Ek A witness; A10 isolates the 1.15 bean factor below catch-up; A10b observes no climb/transfer during stun then a 0.400 s transfer; A11b requests release and measures the 1.600 s warning; A14/A20 compare against the complete §6 formula.

## Checkpoint: GATE 2 fairness/replay slice — 2026-10-10

| Item ID | Status | Evidence / open work |
|---|---|---|
| T14 deterministic Stage 1–5 | PASS | Five fixed agents × `canonical_v1`/`mirror_v1` = 10/10 failed before completing Stage 5; no input-specific runtime traps were added. |
| T14 random experiment | NOT RUN for 30-stage acceptance | Descriptive Stage 1–5 partial: 3,000/3,000 attempts, 9 completions, rate 0.300%, one-sided 95% Clopper–Pearson upper 0.523%. The v1.3 threshold applies to full 30-stage attempts and is not claimed here. |
| T15 Stage 1–5 | PASS (slice) | Both catalog entries completed two independent real gameplay-scene replays through the shared command router at 120 Hz; 15/15 route/support checkpoint hashes matched per entry, 0 hits, no skill, minimum gap 240.044. Full physics-snapshot search, stages 6–30, boundary states, and uninterrupted 30-stage replay remain NOT RUN. |
| T06 K1/K2 Stage 1–5 | PASS | Active P=0 band bean-penalty simulation: minimum gap 181.956, post-penalty 184.621, after 5 s 214.927. Both skill-less damage-free catalog replays stayed at minimum gap 240.044. All six future-band equilibrium equations produced 288/261/234/210/162/210; their hazard simulations remain later-stage work. |
| T06 three-route catch | PASS | L/C/R and both adjacent transfer midpoints caught at gap 28; x outside the real claw span did not. |
| T07 audio observability | PASS | Bounded 24-entry read-only `audio_events` snapshot exposes `{event,t}` records; bean warning is observable without a production setter. |
| T10 pause | PASS | 240 explicit paused physics ticks left Time Wings remaining time unchanged. |

Targeted Godot results: `tests/test_gate2_fairness.gd` 8 PASS / 0 FAIL; `tests/test_gate2_runtime.gd` 5/0; `tests/test_gate2_stage_database.gd` 5/0; `tests/test_gate1.gd` 7/0. The first red run failed because the new classes/API did not exist; the first replay run then exposed a witness command attempted while its target support was still closed, and the validator was corrected to wait for a real connected support window.
