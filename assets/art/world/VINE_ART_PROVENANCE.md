# Vine art provenance

Generated 2026-10-12 with the built-in Codex `image_gen` tool. The generated
art is project-owned AI output supplied for Beanstalk Escape; no third-party
stock assets or paid generation path were used.

| Asset | Scene use | Source prompt summary | SHA-256 |
| --- | --- | --- | --- |
| `vine_helix_tile_v4.png` | Seamless repeated trunk/branch surface | Three intertwined helical bean-vine strands, diagonal grooves, knots, cylindrical highlight and dark edge | `E1B7775C79EC5C40F7C84FC25FD1AD8DED2401BA93FF3BBB31EE04E6977D3B36` |
| `vine_details_atlas_v2.png` | 4x2 attached leaf/knot/tendril atlas | Four glossy stemmed leaves, two knot ornaments and two curled stemmed tendrils on transparent cells | `8CA102A9D949CD4D4280AE177F3FC664ABFA5BB3350EBDD6356ABC2811C85205` |

Both files were downsampled as PNG for the Compatibility/web memory budget:
surface 512x512, details 1024x512. The surface received a 32 px toroidal edge
blend so opposite border pixels match and repeated sampling has no hard seam.
Runtime import metadata is excluded from source control.

## World art v2 — 2026-10-16

Source: built-in Codex `image_gen`, as requested in
`03-test/dunya-v2-20261016/codex-brif-1.md`.
Style authority: `01-tasarim/dunya-v2/stil-prompt-v1.md`,
`stil-karesi-v1.png`, `stil-karesi-v1-yukseklik.png`, and `ref/logo.png`.
AI-generated project artwork; no stock assets or additional licensed source
was introduced. No human-made-art claim is made. Human gameplay art acceptance
remains **HUMAN REVIEW REQUIRED**.

All final paths below are relative to `assets/art/world/v2/`.

| File | Size | Use | SHA-256 of delivered PNG |
| --- | --- | --- | --- |
| `branch_tile.png` | 256×512, 219990 bytes | Generated finer-fiber variant; intentionally unused to avoid a join seam | `8f93d49d79423d924cdafeab74e14ca271fe5e978108e6018cb211e640720f4f` |
| `far_stalks_a.png` | 512×1024, 364187 bytes | Far parallax silhouettes, 0.06 camera speed | `ddbf3b4c0a83d68cf61679a3b24ab23f684ae971f959849fa5cfc45f74d07090` |
| `far_stalks_b.png` | 512×1024, 497790 bytes | Near parallax silhouettes, 0.14 camera speed | `79a3caac3f89d28bd077aa42a7112c2550129eab297d344d6480e94c278c8996` |
| `fork_collar.png` | 256×192, 39589 bytes | Overlapping sleeve halfway through the Stage 3 narrowing stem | `fc003e50a55c7ded543431ba53d0a1db6b3b27081f2282cbe55dee4c1ee6fb76` |
| `leaves_atlas.png` | 768×512, 269328 bytes | Three leaves and two tendrils, 3×2 atlas; last cell empty | `452a8c869c308c4af2960725d1535f352d9d5e28718465baf8b619cb4ecf666e` |
| `sky_day.png` | 1280×720, 740176 bytes | Day sky, Stages 1–11 | `1358b8aa13b53363942d05de14f77910aadd2a63194f4edbb3af9fdb61946140` |
| `sky_sunset.png` | 1280×720, 785429 bytes | Sunset sky; blend across Stages 12–20, full at 20+ | `eced54f15db2d137676f1993a24092261062a6f51eceb7bfcce3910309d579df` |
| `stalk_tile.png` | 256×512, 196292 bytes | Shared trunk/branch surface, world-Y UVs / 256 px | `690184e8cec81c960009fa14e88e763759c3bf436b5e853428a484bfdfc61986` |

### Processing and integration

- The initial transparent-background requests also produced unwanted sky.
  Dedicated image_gen edits replaced those backgrounds with solid #FF00FF.
  Python/Pillow/NumPy then keyed magenta, unmatted the edges and removed
  purple spill, as explicitly allowed by the brief.
- The branch variant's unwanted sky margins were cropped to its central
  fiber surface. Runtime uses stalk_tile on both trunk and branches:
  the shared image and absolute V phase prevent a material change at the join.
- Both fiber tiles and both parallax tiles use a smoothstep crossfade over
  one sixth of the original height, in premultiplied alpha. They were each
  inspected repeated three times vertically. The temporary texture preview
  was removed; no game screenshot or video was captured.
- Atlas cells were individually trimmed and packed into equal 256×256 cells,
  with each attachment at left-center and a transparent gutter.
  Draw sizes are 58/64 px, capped at 70 px. Nodes use absolute world Y;
  stage numbers and camera-cache clipping do not reseed their phase.
- A shared CanvasItem shader selects painted face UVs (U=0..1,
  V=world_y/256) or the #10240f contour encoded in the same mesh.
  Side contours are 3 px plus a 0.75 px alpha fringe. Tapered tips close
  inside that mesh. No caps are added at stage/cache boundaries.
- Texture resources are preloaded once. Runtime creates one mesh per ribbon
  instead of two, and retains the single batched atlas mesh.
- All eight delivered .import files have mipmaps/generate=true.
  The required Godot 4.7.2 headless import ran. The initial cold import
  returned 1; the subsequent import returned 0. Its res:// log-file option
  produced a directory error, so the quick load used an absolute log path.
- Godot's unrelated automatic project/import/UID metadata changes were
  restored or removed; only the brief's files are delivered.

### Scope checklist

| Requirement | Implementation state | Evidence / limit |
| --- | --- | --- |
| Eight generated textures and provenance | UYGULANDI | Paths, source prompts and final hashes below |
| Locked stem/branch geometry and taper | UYGULANDI | 14 geometry/support function bodies equal HEAD |
| World-Y surface, constant contour, collar, sparse attached growth | UYGULANDI | world_visual.gd; gameplay visual acceptance pending |
| Day/sunset, two parallax speeds, lighter storm/flash | UYGULANDI | world_sky_visual.gd; no primitive fog circles |
| Existing qa_* functions and contract keys | UYGULANDI | No contract key removed; support mask retained |
| Rock, character, spider, config and gameplay edits | UYGULANMADI | Locked files have no delivered diff |
| Full regression, route scan, game captures, commit, push | UYGULANMADI | Excluded by this brief |
| Real gameplay art/FPS acceptance | UYGULANMADI | Reserved for owner; no rendered gameplay capture |

### Only quick test

```powershell
& 'E:\Godot4\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\oyunlar\BeanstalkEscape\02-kod-dunya2' --quit-after 3 --log-file 'E:\oyunlar\BeanstalkEscape\02-kod-dunya2\.godot\world-v2-smoke.log'
```

Process exit: **0**, but this is **not a clean game-load result**.
The log contains 27 SCRIPT ERROR entries, including
`SaveManager._sanitize_profile (scripts/save_manager.gd:442)` missing
`progression`, missing `meta`/`owned`/`selected_character`, and
`Economy config could not be loaded`.
Those save/economy/UI files were not edited; baseline causality was not tested.
The full log is `.godot/world-v2-smoke.log` (local ignored engine cache).
There are zero references to either changed visual script in that error log.
No extra gameplay tests were run. GPU shader output, actual gameplay art,
stage joins in motion and FPS remain unverified.

### Exact tool prompts and generated sources

#### sky_day.png

Generated source: `C:\Users\Arget\.codex\generated_images\01a14635-d214-7ab2-b9a8-03028186b494\exec-e4b3adf5-ab63-4198-ab8f-b0b65f9b3c4a.png`

Initial prompt:

```text
Use case: stylized-concept. Generate sky_day.png, ONE landscape 16:9 opaque game background plate. Almost flat cyan-blue sky, very few small simplified soft cream clouds near far left/right edges. Calm open empty center. NO beanstalks, vines, leaves, objects, landscape, sun disc, characters, text or borders. Match the calm blue sky of the provided daylight style reference; use reference only for palette. The following style rules define the asset family; foreground and beanstalk references do NOT mean including any foreground or beanstalk in THIS sky-only asset.
RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
```

Final image_gen edit prompt:

```text
Edit sky background ONLY: remove EVERY beanstalk/vine silhouette at lower left and lower right. Replace those exact regions with matching empty cyan blue sky and simple pale clouds. Keep the existing blue sky, the few cream clouds, calm open middle and landscape framing. Absolutely NO plant, vine, stalk, leaf, character or silhouette anywhere. This must be a reusable sky-only background plate. RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
ASSET OVERRIDE to BACKGROUND sentence above: NO beanstalk silhouettes; they are supplied as separate parallax textures. Do not add any foreground.
```

#### sky_sunset.png

Generated source: `C:\Users\Arget\.codex\generated_images\01a14635-d214-7ab2-b9a8-03028186b494\exec-862a33d5-9f83-4235-ad0c-7cfe9a513a59.png`

Initial prompt:

```text
Use case: stylized-concept. Asset: sky_sunset.png for Beanstalk Escape. ONE opaque landscape 16:9 background plate of quiet high altitude sunset. Almost flat peach/apricot open sky subtly grading to pale muted lilac at top, a broad simple pale peach/lavender cloud deck at bottom quarter only. NO vines or objects, no sun disc or landscape. Empty open center. Use style background rule as family guidance; replace blue with sunset, OMIT ALL beanstalks.
RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
```

#### far_stalks_a.png

Generated source: `C:\Users\Arget\.codex\generated_images\01a14635-d214-7ab2-b9a8-03028186b494\exec-d440d044-d43d-4e37-bb68-2f74ef560810.png`

Initial prompt:

```text
Use case: stylized-concept. Asset: far_stalks_a.png for Beanstalk Escape. ONE game parallax texture, portrait, transparent background. Vertically seamless repeat: two very faint desaturated teal/blue-green giant climbing beanstalk silhouettes confined to outer left and outer right 20 percent of canvas, middle 60 percent fully transparent. Low contrast misty painted soft silhouettes, no dark outlines. Top/bottom stem and foliage patterns must wrap in Y, no caps; vertical plants continue out top and bottom. NO sky, clouds, solid background, floor, text. Background style rules apply to THESE distant silhouettes only.
RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
```

Final image_gen edit prompt:

```text
Asset extraction edit. RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
MANDATORY ASSET BACKGROUND OVERRIDE: The BACKGROUND sentence above describes only the style reference. THIS OUTPUT MUST HAVE A FLAT SOLID #FF00FF MAGENTA BACKGROUND WITH ZERO SKY, CLOUDS, SCENERY OR EXTRA PLANTS.
Replace the ENTIRE blue sky and ALL clouds and tiny distant plants with a perfectly flat solid #FF00FF magenta key background. Keep ONLY the outer left and right edge plants, recolor them desaturated hazy teal-blue, reduce saturation and contrast greatly and REMOVE their dark outlines. No shadow on background. Middle 60 percent MUST be flat #FF00FF; tops/bottoms of plants stay continuous for Y tiling.
```

#### far_stalks_b.png

Generated source: `C:\Users\Arget\.codex\generated_images\01a14635-d214-7ab2-b9a8-03028186b494\exec-04cb1790-5982-4d28-9232-ee1ba118486f.png`

Initial prompt:

```text
Use case: stylized-concept. Asset: far_stalks_b.png for Beanstalk Escape. ONE game parallax texture, portrait transparent background, vertically seamless. Two thin hazy desaturated blue-green distant twisting beanstalks along outermost left/right edges, EMPTY transparent middle 64 percent. This is the nearer of two very restrained silhouette layers; softly painted, low contrast, NO dark outlines, no foreground. Organic leaves and thin tendrils. Stems continue through top/bottom edges in same positions for vertical repetition. No sky, clouds, ground, text.
RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
```

Final image_gen edit prompt:

```text
Asset extraction edit. RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
MANDATORY ASSET BACKGROUND OVERRIDE: The BACKGROUND sentence above describes only the style reference. THIS OUTPUT MUST HAVE A FLAT SOLID #FF00FF MAGENTA BACKGROUND WITH ZERO SKY, CLOUDS, SCENERY OR EXTRA PLANTS.
Replace ALL blue sky and clouds and tiny distant plants with perfectly flat solid #FF00FF magenta key background. Retain only outer left/right edge vines, rendered hazy low contrast desaturated blue-green, no dark contour; transparent silhouette layer later keyed from magenta. Center 60 percent pure #FF00FF, no scenery. Stems continuous top/bottom for Y tiling.
```

#### stalk_tile.png

Generated source: `C:\Users\Arget\.codex\generated_images\01a14635-d214-7ab2-b9a8-03028186b494\exec-5275f513-6c2d-4192-809c-76ee40c3bf7c.png`

Initial prompt:

```text
Use case: stylized-concept. Asset: stalk_tile.png for Beanstalk Escape. ONE rectangular portrait seamless game texture of GREEN STALK SURFACE ONLY filling ENTIRE canvas. Saturated rich green, sculpted hand-painted broad burgled twisted organic longitudinal fibers, bright lime upper left rim light as a broad band ALONG LEFT EDGE, dark green right side shadow. Vertical repeat tile, fibers continuous top/bottom. THIS IS AN UNWRAPPED INTERIOR SURFACE, NO silhouette, no external contour, no black outlines embedded, no leaves, no branch junction, NO background or margins, no horizon, no text. U horizontal across entire stem; V vertical. Style background sentence is asset-family context only: OMIT SKY and silhouettes, green surface fills every pixel.
RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
```

#### branch_tile.png

Generated source: `C:\Users\Arget\.codex\generated_images\01a14635-d214-7ab2-b9a8-03028186b494\exec-098233ce-841a-4161-9b83-31c4ba83ded5.png`

Initial prompt:

```text
Use case: stylized-concept. Asset: branch_tile.png for Beanstalk Escape. ONE portrait seamless green branch INTERIOR surface texture filling ENTIRE canvas, same palette and lighting as broad saturated green stalk surface, fine twisted longitudinal fibers, painted dimensional shading, bright lime LEFT side band and dark green right side shadow. Seamless vertically continuing top/bottom. No embedded contour lines or silhouettes or margins, no tips, no leaves, no joints, no background or sky. Style background sentence is family context only, do not render sky/silhouettes; every pixel green fiber surface.
RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
```

#### fork_collar.png

Generated source: `C:\Users\Arget\.codex\generated_images\01a14635-d214-7ab2-b9a8-03028186b494\exec-7268b014-d19b-4bb6-9b3a-5762b6c4827c.png`

Initial prompt:

```text
Use case: stylized-concept. Asset: fork_collar.png for Beanstalk Escape. ONE small organic fork collar GAME SPRITE on fully TRANSPARENT background. A short softly tapering green stem node sleeve at a thick stem narrowing to one thinner central ascending branch. Broad lower base, narrow upper end, fills width and height, no detached pieces. Saturated painted green fiber volume, lime upper left edge light, dark green thick curved SIDE contours only. Upper/lower overlapping organic scalloped lip, no horizontal black bars. NO other branches, trunk, sky, scenery, ground, text. The background rule is family context only, output background MUST be transparent.
RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
```

Final image_gen edit prompt:

```text
Asset extraction edit. RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
MANDATORY ASSET BACKGROUND OVERRIDE: The BACKGROUND sentence above describes only the style reference. THIS OUTPUT MUST HAVE A FLAT SOLID #FF00FF MAGENTA BACKGROUND WITH ZERO SKY, CLOUDS, SCENERY OR EXTRA PLANTS.
Extract ONLY the central short green node sleeve/collar, NOT the long trunk above/below it. Render one small green organic tapered collar sprite isolated against perfectly flat solid #FF00FF magenta key background. No sky/clouds/stalk silhouettes/extra objects anywhere. Collar has softly scalloped open ends overlapping existing green stem; width slightly narrower at top. Green fibers, lime left highlight, dark green sides.
```

#### leaves_atlas.png

Generated source: `C:\Users\Arget\.codex\generated_images\01a14635-d214-7ab2-b9a8-03028186b494\exec-7f7801f3-427b-4c6c-bf4b-6eb73aec65ad.png`

Initial prompt:

```text
Use case: stylized-concept. Asset: leaves_atlas.png for Beanstalk Escape. ONE TRANSPARENT sprite atlas, exact 3 columns by 2 rows of equal square cells, each sprite centered and fully contained with transparent gutter. TOP ROW: exactly 3 separate glossy green cartoon leaves of distinct shapes, broad readable veins, chunky dark green contour, bright lime upper-left rim light. BOTTOM ROW: 2 separate curled green tendrils in first and second cells; third cell EMPTY. Each sprite attachment/root at LEFT CENTER of its cell, stem extends from that left-center root toward the right, leaf/curl fills right side. Roots horizontal, sprites point outward to RIGHT; NO extra plants, text, labels, grid, background or drop shadows. Style background rules are family context only; transparent background mandatory.
RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
```

Final image_gen edit prompt:

```text
Asset extraction edit. RENDERING: unify entire foreground into one polished painted cartoon game asset family. Rich green twisted stalk fibers with restrained brush texture and coherent dimensional shading; chunky expressive dark contours, clear highlight along upper left edges, leaf veins painted in broad readable shapes. Crisp silhouettes, no vector tubes, no photorealism, no 3D render camera, no excessive microdetail.
BACKGROUND: simple almost flat cyan-blue cartoon sky; a small number of simplified stylized cloud shapes. Faint desaturated green-blue distant beanstalk silhouettes at two different parallax depths to left and right; low contrast, thin haze, no sharp dark outlines behind play area. Background should be calm and readable. One coherent daylight direction, foreground has greatest contrast.
MANDATORY ASSET BACKGROUND OVERRIDE: The BACKGROUND sentence above describes only the style reference. THIS OUTPUT MUST HAVE A FLAT SOLID #FF00FF MAGENTA BACKGROUND WITH ZERO SKY, CLOUDS, SCENERY OR EXTRA PLANTS.
Keep precisely these THREE leaves top row and TWO curled tendrils bottom row in a 3x2 equal square cell atlas. REMOVE every part of sky, clouds, background beanstalks, scenery and replace with perfectly flat solid #FF00FF magenta chroma key. No antialiasing with blue. Each of five isolated sprites has attachment at LEFT CENTER in its cell; rightmost bottom cell completely empty magenta. No text/grid. Preserve painted bright green/dark contour/lime light style.
```
