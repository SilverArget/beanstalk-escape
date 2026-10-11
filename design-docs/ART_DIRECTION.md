# Art Direction

## GATE 3A §12.1 pilot checkpoint — 2026-10-11

- `§12.1-2` PARTIAL PASS: M1 and owner-approved F1 identities were produced only with built-in `image_gen` as transparent rigid-part sheets. No CLI/API-key/paid fallback was used.
- `§11-F1` PASS (source/contract): F1 uses the approved red ponytail and turquoise tunic identity. The generic green-cream F1 clothing line remains overridden by D-002.
- `§11-rig` PASS (automated): one `CharacterRig` hierarchy, one zero-local-pivot grid, one 44×108 visible contract, one 30×86 collider and seven pilot animations serve M1/F1 without animation mutation.
- `§12.1-3` NOT RUN visually: automated RGBA/atlas checks pass, but zero visible joint gap, ≤2 px hand/foot contact, ≤2 px wing seam, clipping and anatomy require rendered-frame inspection.
- `§12.1-4` NOT RUN: sunny/storm silhouette-boundary contrast and grayscale hazard distinction have no rendered evidence.
- `§12.1-5` NOT RUN: 30 FPS key/intermediate frame sequences and MP4 inspection were not executed.
- `§12.1-6` NOT RUN on pilot art: ScaleLock numeric contract remains 15/15, but Stage 1/3/storm rendered measurement frames were not captured.
- Storm pilot note: no storm art exists at this gate; the prepared QA capture uses permitted flat `#313C68`.
- Reference status is `PARTIAL_NOT_LOCKED`; bulk animation/remaining skins must not begin.

Palette anchors: M1 green family follows vine-primary harmony; F1 turquoise preserves the approved identity; outline is dark navy; Time Wings use `#9969EC`; QA storm fallback is `#313C68`.
