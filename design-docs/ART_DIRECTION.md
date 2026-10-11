# Art Direction

## GATE 3A §12.1 pilot correction checkpoint — 2026-10-11

- `§12.1-2/§11` PASS rendered: M1/F1 share one 22-part rig and the approved F1 red-ponytail/turquoise identity.
- `§12.1-3` PASS rendered: harness/wing anchor is behind the torso, face is unobstructed, detached atlas-border fragments are clipped, joint gaps are 0 px, contact is 0–2 px, and wing seam is 0–2 px.
- `§12/§12.1-3` PASS motion: four contact poses alternate reach/pull with gripped hands; root travel is 1 px rather than a body bounce.
- `§5.1/VIS02/VIS11` PASS pilot: 43–47×101 px, center y=396/73.3%, 3 px contour and 12 px grip detail in 960×540 evidence.
- `§12.1-5` PASS evidence: 150 PNG frames and one 155-frame 30 FPS H.264 MP4 per skin. Flat storm fallback remains `#313C68`.
- Full regression is incomplete in this checkpoint; remaining-skin/bulk production must not begin until the requested complete rerun is green.

### Superseded initial pilot record

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
