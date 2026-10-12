# Implementation Progress

## GATE 3A step 1 correction — 2026-10-11

- `§12.1-2/§11/T18-kısmi`: M1/F1 shared rig visual correction complete.
- `§5.1-character/VIS02/VIS11`: PASS at 43–47×101 px, y=396 (73.3%), 3 px contour, 12 px grip.
- `§12.1-3`: PASS at 0 px joint gaps, 0–2 px support contact, 0–2 px wing seam.
- `§12.1-5`: PASS; 150 PNG frames and 30 FPS MP4 per skin.
- `GA08`: windowed 5/0 with documented `ASSERT CHANGE §12.1-2`.
- `REGRESSION`: incomplete; `test_tur3.gd` stopped after 6/8 PASS, and the remaining short files were not rerun in the final batch.
- `WEB`: PASS; PCK `7B95EBEE4BCCD12AF7DA181F0D696BD9F82007CA800D4AEBE689C9463DCB680D`.
- Sıradaki kesin iş: GATE 3A Adım 1 içinde yalnız eksik tam headless regresyonu bitir; 0 FAIL doğrulanınca referans kilidini `PILOT_LOCKED` yap. Adım 2’ye geçme.

## GATE 3A step 2 correction 6 — 2026-10-12

- `§12.1-4 / FAIL D`: CODEX PASS, owner visual verification pending. Exact requested boundary-pair ratios are `98.408 / 98.276 / 98.408 / 98.408%` for Stage 1/split/4/5; rig and pilot lock unchanged.
- `§12 / FAIL E`: CODEX PASS, owner visual verification pending. Transfer UV follows the arch tangent and branch-over-transfer ordering buries bridge feet.
- `VIS12 / FAIL F`: CODEX PASS, owner visual verification pending. Split gap outline waits for an 8 px real opening; Stage 3 branch outlines are trimmed 36 px at the split join.
- Windowed capture `6/6 + 26/26`; isolated GA08 `5/0`; rig `8/0`; scale `15/0 + 2 headless frame NOT RUN`; Gate A `9/0`. No assertion changes. Full 17-file regression remains for owner verification.
- Next exact work: owner opens the final QA frames and runs the complete 17-file regression; on acceptance, close GATE 3A Sıra 2 and continue to Sıra 3.

## GATE 3A step 2 correction 7 — 2026-10-12

- `§21-4 / FAIL D`: CODEX numeric/render PASS, owner visual verification pending. Removed the player-following world patch; fixed-geometry M1/F1 contrast halo gives exact requested game ratios `97.970 / 99.446 / 97.786 / 97.232%` and pilot minima M1 `94.58%`, F1 `93.17%`.
- `§5.1-character`: PASS across all pilot animations: M1 `101..109 × 40..46 px`, F1 `102..109 × 40..47 px`; rig parts/poses/identity and pilot lock unchanged.
- `VIS12 / FAIL F`: CODEX geometry/render PASS, owner visual verification pending. Gap contours derive from exact painted ribbon edges; real branch exterior edges are untrimmed; the player-following per-quad fan source is removed.
- Windowed capture `6/6 + 26/26`; isolated GA08 `5/0`; M1/F1 pilot `150/150` each; rig `8/0`; scale `15/0 + 2 headless frame NOT RUN`; Gate A `9/0`. No assertion changes. Full 17-file regression remains NOT RUN.
- Next exact work: owner opens the final D/F frames and runs the complete 17-file regression; on acceptance, close GATE 3A Sıra 2 and continue to Sıra 3.

## GATE 3A step 2 correction 8 — 2026-10-12

- `§21-4`: stable single-dark character contour restored; deterministic v3 vine value hierarchy passes exact game-frame contrast at `97.238..97.422%` without a player-following world patch.
- `§5.1 / image quality`: all 69 PNG imports now generate mipmaps; relevant CanvasItems use linear mipmapped filtering. 960x540 and 1920x1080 Compatibility captures passed; M1/F1 remain within `96..120 x 36..48 px`.
- `VIS12 / FAIL F`: split is one concave painted polygon with one exterior contour. Interior contour pixels `0`, boundary coverage `533/533`, y=314/y=322 band ratios `1.110x / 1.421x`, sky leak `0`.
- Windowed capture `6/6 + 26/26`; GA08 `5/0`; pilot M1/F1 `150/150` each; rig `8/0`; scale `15/0 + 2 headless frame NOT RUN`; Gate A `9/0`. No assertion changes. Full 17-file regression remains NOT RUN.
- Next exact work: owner opens the mipmap and fork before/after evidence and runs the complete 17-file regression. On acceptance, close GATE 3A Sıra 2 and continue to Sıra 3.
