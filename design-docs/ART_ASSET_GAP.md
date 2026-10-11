# Art Asset Gap

Status at GATE 0 / start of GATE 1, 2026-10-10. No art was generated in this checkpoint.

| Asset / source | Current issue | Required resolution | Status |
|---|---|---|---|
| `assets/art/gpt/world/trunk_wide.png` (raw 06 lineage) | Live width is ~590 units; owner frames show oversized/blurry detail and ghost layering. | Preserve original; replace with seamless modular trunk authored for 160–200 units. | GAP |
| `assets/art/gpt/world/branch_woven.png` (raw 07 lineage) | Live width is ~182 units vs 36–56 target; centers are 240 vs 130–180. | Preserve original; replace with spline/module art at 44-unit target. | GAP |
| `assets/art/gpt/world/split_transition.png` (raw 08 lineage) | Prior frames show hard cuts/double layers at 2→3 and later boundaries. | Replace with a scale-locked organic trunk-to-three-branch module; three-module seam test required. | GAP |
| `assets/art/gpt/player/*.png` | Current combined pose art measures ~63 px high, not 96–120; it is not the required shared-part rig. | Rebuild approved F1 identity and five other skins as the common §11 part set after reference lock. | GAP |
| Current world/player pairing | Different detail scale/style; current visual frames are known FAIL. | Apply one contour/light/detail family after greybox and §12.1 pilot. | GAP |

Do not delete or overwrite originals. Do not count recoloring, cropping, or shrinking these files as resolution.

## GATE 3A Sıra 2 resolution (2026-10-11)

- Raw `04-sirik-kiti.png`, `06-genis-govde.png`, `07-dal.png`, and `08-ayrilma.png` remain preserved and unused: their authored scale and baked transitions do not meet §5.1 or the pixel-continuous module requirement.
- The live Stage 1–2 trunk is now a continuous 172–188 px procedural ribbon with a 52 px feature rhythm; it is not a scaled/repeated raw illustration.
- The Stage 3 split and Stage 3–5 branches use the existing gameplay centers and widths with a continuous organic ribbon/vein treatment.
- `assets/art/world/sunny_atmosphere.png` is a new built-in image_gen background plate; deterministic gradient, cloud and parallax foliage layers are composited by `world_visual.gd`.
