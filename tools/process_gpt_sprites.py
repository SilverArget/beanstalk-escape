#!/usr/bin/env python3
"""Deterministic GPT sprite extraction for the approved 09.10.2026 sheets.

The source files are read-only inputs. Output pages and sprites are written to
arastirma/gpt-sprites/cut and assets/art/gpt respectively.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageFilter


RAW_NAMES = {
    "player": "02-poz-sayfasi.png",
    "spider": "03b-orumcek-sayfasi-duzeltme.png",
    "world": "04-sirik-kiti.png",
    "items": "05-esyalar.png",
    "trunk_wide": "06-genis-govde.png",
    "branch_woven": "07-dal.png",
    "split_transition": "08-ayrilma.png",
}
PLAYER_NAMES = [
    "climb_right", "climb_alt", "jump", "climb_left",
    "hurt", "fall", "cheer", "idle",
]
SPIDER_NAMES = [
    "climb_1", "climb_2", "climb_3", "climb_4",
    "attack", "angry", "stunned", "idle",
]
ITEM_NAMES = [
    "bean_0", "bean_45", "bean_90", "bean_burst",
    "warning_badge", "landing_shadow", "warning_arrow", None,
    "wing_open", "wing_closed", "wing_orb", None,
    "cloud_1", "cloud_2", "cloud_3", "cloud_4",
]

# The approved item sheet is free-form (4/3/3/4 objects by row), not a 4x4
# grid. These gaps separate object groups after connected-component analysis.
ITEM_ROW_Y_SPLITS = (315, 540, 800)
ITEM_ROW_X_SPLITS = (
    (430, 750, 1000),
    (500, 1000),
    (650, 1000),
    (450, 750, 1180),
)


def estimate_background(rgb: np.ndarray) -> np.ndarray:
    edge = 24
    samples = np.concatenate(
        [
            rgb[:edge, :edge].reshape(-1, 3),
            rgb[:edge, -edge:].reshape(-1, 3),
            rgb[-edge:, :edge].reshape(-1, 3),
            rgb[-edge:, -edge:].reshape(-1, 3),
        ],
        axis=0,
    )
    return np.median(samples, axis=0).astype(np.float32)


def matte(path: Path, bg_threshold: float = 5.0, fg_threshold: float = 34.0) -> tuple[np.ndarray, np.ndarray]:
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    background = estimate_background(rgb)
    distance = np.max(np.abs(rgb - background), axis=2)
    alpha = np.clip((distance - bg_threshold) / (fg_threshold - bg_threshold), 0.0, 1.0)
    alpha = alpha * alpha * (3.0 - 2.0 * alpha)
    # Very low coverage pixels retain the source sheet's gray background even
    # after unmixing and become visible as translucent rectangular bands when
    # the texture repeats.  Keep antialiasing, but discard that gray fringe.
    alpha[alpha < 0.08] = 0.0
    # Reverse the flat-background blend so antialiased edge RGB is not gray.
    safe_alpha = np.maximum(alpha[..., None], 0.08)
    foreground = (rgb - (1.0 - alpha[..., None]) * background) / safe_alpha
    foreground = np.clip(foreground, 0.0, 255.0)
    foreground[alpha == 0.0] = 0.0
    rgba = np.dstack((foreground.astype(np.uint8), np.round(alpha * 255.0).astype(np.uint8)))
    return rgba, background


def alpha_bbox(rgba: np.ndarray, threshold: int = 10, padding: int = 8) -> tuple[int, int, int, int] | None:
    ys, xs = np.nonzero(rgba[..., 3] > threshold)
    if xs.size == 0:
        return None
    h, w = rgba.shape[:2]
    return (
        max(int(xs.min()) - padding, 0),
        max(int(ys.min()) - padding, 0),
        min(int(xs.max()) + padding + 1, w),
        min(int(ys.max()) + padding + 1, h),
    )


def crop_alpha(rgba: np.ndarray, padding: int = 8) -> np.ndarray | None:
    bbox = alpha_bbox(rgba, padding=padding)
    if bbox is None:
        return None
    x0, y0, x1, y1 = bbox
    return rgba[y0:y1, x0:x1]


def remove_small_components(rgba: np.ndarray, minimum_area: int = 20) -> np.ndarray:
    """Remove isolated generation specks without touching real sprite parts."""
    cleaned = rgba.copy()
    mask = (cleaned[..., 3] > 32).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    for index in range(1, count):
        if int(stats[index, cv2.CC_STAT_AREA]) < minimum_area:
            cleaned[labels == index] = 0
    return cleaned


def keep_largest_component(rgba: np.ndarray) -> np.ndarray:
    """Keep the principal silhouette and discard detached generation debris."""
    mask = (rgba[..., 3] > 1).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    if count <= 2:
        return rgba
    largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    cleaned = np.zeros_like(rgba)
    cleaned[labels == largest] = rgba[labels == largest]
    return cleaned


def save_rgba(path: Path, rgba: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)


def crop_x_centered(rgba: np.ndarray, center_x: int, padding: int = 10) -> np.ndarray:
    """Crop transparent sides symmetrically while preserving the vine center."""
    _, xs = np.nonzero(rgba[..., 3] > 10)
    if xs.size == 0:
        raise RuntimeError("Cannot crop an empty vine image")
    radius = max(center_x - int(xs.min()), int(xs.max()) - center_x) + padding
    x0 = max(center_x - radius, 0)
    x1 = min(center_x + radius + 1, rgba.shape[1])
    cropped = rgba[:, x0:x1]
    # Alpha must stay clear at the side borders for the extraction QA.
    return np.pad(cropped, ((0, 0), (2, 2), (0, 0)), mode="constant")


def make_vertical_seamless(rgba: np.ndarray, band: int = 192) -> np.ndarray:
    """Blend matching cut edges without mirroring the approved artwork."""
    output = rgba.astype(np.float32).copy()
    height = output.shape[0]
    band = min(band, height // 3)
    for offset in range(band):
        progress = float(offset) / float(max(band - 1, 1))
        smooth = progress * progress * (3.0 - 2.0 * progress)
        top = output[offset].copy()
        bottom = output[height - 1 - offset].copy()
        seam = (top + bottom) * 0.5
        output[offset] = seam * (1.0 - smooth) + top * smooth
        output[height - 1 - offset] = seam * (1.0 - smooth) + bottom * smooth
    result = np.clip(np.round(output), 0, 255).astype(np.uint8)
    result[-1] = result[0]
    return result


def resize_rgba(rgba: np.ndarray, scale: float, match_vertical_edges: bool = True) -> np.ndarray:
    width = max(1, round(rgba.shape[1] * scale))
    height = max(1, round(rgba.shape[0] * scale))
    resized = np.array(Image.fromarray(rgba, "RGBA").resize((width, height), Image.Resampling.LANCZOS), copy=True)
    resized[resized[..., 3] < 2] = 0
    if match_vertical_edges:
        resized[-1] = resized[0]
    return resized


def process_new_vines(raw_dir: Path, cut_dir: Path, game_dir: Path) -> dict[str, np.ndarray]:
    """Process manager-approved 06/07/08 geometry without touching originals."""
    trunk, _ = matte(raw_dir / RAW_NAMES["trunk_wide"])
    trunk = remove_small_components(trunk)
    trunk = crop_x_centered(trunk, 498)
    trunk = resize_rgba(make_vertical_seamless(trunk), 2.0)

    branch, _ = matte(raw_dir / RAW_NAMES["branch_woven"])
    branch = remove_small_components(branch)
    branch = crop_x_centered(branch, 501)
    branch = resize_rgba(make_vertical_seamless(branch), 1.4)

    split, _ = matte(raw_dir / RAW_NAMES["split_transition"])
    split = remove_small_components(split)
    # Remove the approved sheet's small lower-right curl touching the cut edge.
    split[1450:, 653:] = 0
    split = crop_x_centered(split, 510)
    base_alpha = split[-1, :, 3] > 128
    base_positions = np.where(base_alpha)[0]
    base_width = int(base_positions.max() - base_positions.min() + 1) if base_positions.size else 277
    split = resize_rgba(split, 590.0 / float(base_width), match_vertical_edges=False)
    # Lanczos can separate a few antialiased pixels from the silhouette after
    # the large uniform resize. Remove only those post-resize crumbs.
    split = remove_small_components(split, minimum_area=100)

    outputs = {
        "trunk_wide": trunk,
        "branch_woven": branch,
        "split_transition": split,
    }
    for name, sprite in outputs.items():
        save_rgba(cut_dir / f"{name}.png", sprite)
        save_rgba(game_dir / f"{name}.png", sprite)
    write_checker_preview(cut_dir / "qa-dark-light-new-vines.png", list(outputs.values()))
    return outputs


def grid_cells(rgba: np.ndarray, columns: int, rows: int) -> list[np.ndarray]:
    height, width = rgba.shape[:2]
    result = []
    for row in range(rows):
        y0 = round(row * height / rows)
        y1 = round((row + 1) * height / rows)
        for column in range(columns):
            x0 = round(column * width / columns)
            x1 = round((column + 1) * width / columns)
            result.append(rgba[y0:y1, x0:x1])
    return result


def normalize_frames(crops: list[np.ndarray], standing_indices: list[int], target_height: int, canvas: tuple[int, int]) -> list[np.ndarray]:
    reference_heights = [crops[index].shape[0] for index in standing_indices]
    scale = target_height / float(np.median(reference_heights))
    canvas_width, canvas_height = canvas
    normalized = []
    for crop in crops:
        width = max(1, round(crop.shape[1] * scale))
        height = max(1, round(crop.shape[0] * scale))
        resized = np.asarray(Image.fromarray(crop, "RGBA").resize((width, height), Image.Resampling.LANCZOS))
        if width > canvas_width or height > canvas_height:
            fit = min(canvas_width / width, canvas_height / height)
            width = max(1, round(width * fit))
            height = max(1, round(height * fit))
            resized = np.asarray(Image.fromarray(resized, "RGBA").resize((width, height), Image.Resampling.LANCZOS))
        frame = np.zeros((canvas_height, canvas_width, 4), dtype=np.uint8)
        x = (canvas_width - width) // 2
        y = canvas_height - height - 6
        frame[y:y + height, x:x + width] = resized
        normalized.append(frame)
    return normalized


def write_checker_preview(path: Path, sprites: list[np.ndarray]) -> None:
    cell_w = max(sprite.shape[1] for sprite in sprites)
    cell_h = max(sprite.shape[0] for sprite in sprites)
    columns = 4
    rows = (len(sprites) + columns - 1) // columns
    preview = np.zeros((rows * cell_h, columns * cell_w, 4), dtype=np.uint8)
    for index, sprite in enumerate(sprites):
        y = (index // columns) * cell_h
        x = (index % columns) * cell_w
        base = 32 if (index // columns + index % columns) % 2 == 0 else 228
        preview[y:y + cell_h, x:x + cell_w, :3] = base
        preview[y:y + cell_h, x:x + cell_w, 3] = 255
        alpha = sprite[..., 3:4].astype(np.float32) / 255.0
        preview[y:y + sprite.shape[0], x:x + sprite.shape[1], :3] = (
            sprite[..., :3] * alpha + preview[y:y + sprite.shape[0], x:x + sprite.shape[1], :3] * (1.0 - alpha)
        ).astype(np.uint8)
    save_rgba(path, preview)


def component_boxes(rgba: np.ndarray, minimum_area: int = 80) -> list[tuple[int, int, int, int, int]]:
    mask = (rgba[..., 3] > 24).astype(np.uint8)
    count, _, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    boxes = []
    for index in range(1, count):
        x, y, width, height, area = [int(value) for value in stats[index]]
        if area >= minimum_area:
            boxes.append((x, y, width, height, area))
    return sorted(boxes, key=lambda box: (box[1], box[0]))


def component_records(rgba: np.ndarray, minimum_area: int = 20) -> tuple[list[dict[str, int]], np.ndarray]:
    mask = (rgba[..., 3] > 32).astype(np.uint8)
    count, labels, stats, centroids = cv2.connectedComponentsWithStats(mask, connectivity=8)
    records: list[dict[str, int]] = []
    for index in range(1, count):
        area = int(stats[index, cv2.CC_STAT_AREA])
        if area < minimum_area:
            continue
        records.append(
            {
                "label": index,
                "x": int(stats[index, cv2.CC_STAT_LEFT]),
                "y": int(stats[index, cv2.CC_STAT_TOP]),
                "w": int(stats[index, cv2.CC_STAT_WIDTH]),
                "h": int(stats[index, cv2.CC_STAT_HEIGHT]),
                "area": area,
                "cx": int(round(centroids[index][0])),
                "cy": int(round(centroids[index][1])),
            }
        )
    return records, labels


def interval_index(value: int, splits: tuple[int, ...]) -> int:
    return sum(value >= split for split in splits)


def process_items(rgba: np.ndarray, cut_dir: Path, game_dir: Path) -> list[np.ndarray]:
    """Extract the free-form 4/3/3/4 item layout by semantic components."""
    records, labels = component_records(rgba)
    groups: dict[tuple[int, int], list[dict[str, int]]] = {}
    for record in records:
        row = interval_index(record["cy"], ITEM_ROW_Y_SPLITS)
        column = interval_index(record["cx"], ITEM_ROW_X_SPLITS[row])
        groups.setdefault((row, column), []).append(record)

    expected_counts = (4, 3, 3, 4)
    if tuple(sum(key[0] == row for key in groups) for row in range(4)) != expected_counts:
        raise RuntimeError(f"Unexpected item groups: {sorted(groups)}")

    sprites: list[np.ndarray] = []
    names = [name for name in ITEM_NAMES if name is not None]
    for name, key in zip(names, sorted(groups)):
        members = groups[key]
        x0 = max(min(record["x"] for record in members) - 8, 0)
        y0 = max(min(record["y"] for record in members) - 8, 0)
        x1 = min(max(record["x"] + record["w"] for record in members) + 8, rgba.shape[1])
        y1 = min(max(record["y"] + record["h"] for record in members) + 8, rgba.shape[0])
        selected = np.zeros_like(rgba)
        selected_labels = np.isin(labels, [record["label"] for record in members])
        selected[selected_labels] = rgba[selected_labels]
        sprite = selected[y0:y1, x0:x1]
        sprites.append(sprite)
        save_rgba(cut_dir / f"{name}.png", sprite)
        save_rgba(game_dir / f"{name}.png", sprite)
    write_checker_preview(cut_dir / "qa-dark-light.png", sprites)
    return sprites


def crop_box(rgba: np.ndarray, box: tuple[int, int, int, int, int], padding: int = 8) -> np.ndarray:
    x, y, width, height, _ = box
    image_height, image_width = rgba.shape[:2]
    x0 = max(x - padding, 0)
    y0 = max(y - padding, 0)
    x1 = min(x + width + padding, image_width)
    y1 = min(y + height + padding, image_height)
    return rgba[y0:y1, x0:x1]


def process_world(rgba: np.ndarray, cut_dir: Path, game_dir: Path) -> list[np.ndarray]:
    rgba = remove_small_components(rgba)
    boxes = component_boxes(rgba)
    if len(boxes) != 11:
        raise RuntimeError(f"Expected 11 world-kit components, found {len(boxes)}")
    # Sheet layout: A trunk, B split, D tip, C branch, four E leaves, three F tendrils.
    trunk_source = keep_largest_component(crop_box(rgba, boxes[0]))
    split = crop_box(rgba, boxes[1])
    tip = crop_box(rgba, boxes[2])
    branch = crop_box(rgba, boxes[3])
    leaves = [crop_box(rgba, box) for box in boxes[4:8]]
    tendrils = [crop_box(rgba, box) for box in boxes[8:11]]

    # A is used as one continuous Stage 1-2 contour. Upscale once offline so the
    # browser never magnifies the old 192 px rectangular strip at runtime.
    trunk_image = Image.fromarray(trunk_source, "RGBA").resize((672, 2364), Image.Resampling.LANCZOS)
    trunk_image = trunk_image.filter(ImageFilter.UnsharpMask(radius=1.1, percent=90, threshold=2))
    trunk_contour = np.asarray(trunk_image)

    # Preserve the historical seamless asset for source traceability, but keep
    # its transparent side contour instead of slicing through opaque pixels.
    source_height = trunk_source.shape[0]
    segment_height = min(240, source_height // 3)
    y0 = (source_height - segment_height) // 2
    segment = trunk_source[y0:y0 + segment_height]
    trunk_seamless = np.concatenate((segment, segment[::-1]), axis=0)

    # C becomes a transparent-sided periodic tile. Mirroring makes both joins
    # exact, and the final row is explicitly equal to the first row.
    branch_height = branch.shape[0]
    # The lower clean C section has no leaf/curl crossing its side contour.
    # Mirroring this short interior section yields a periodic stalk without the
    # triangular cut ends that appeared when the full decorative C was tiled.
    branch_segment_height = min(120, branch_height // 4)
    branch_y0 = max(branch_height - 149, 0)
    branch_segment = branch[branch_y0:branch_y0 + branch_segment_height]
    branch_seamless = np.concatenate((branch_segment, branch_segment[::-1]), axis=0)
    branch_seamless = np.array(Image.fromarray(branch_seamless, "RGBA").resize((326, 480), Image.Resampling.LANCZOS), copy=True)
    branch_seamless[-1] = branch_seamless[0]

    named = {
        "trunk_source": trunk_source,
        "trunk_seamless": trunk_seamless,
        "trunk_contour": trunk_contour,
        "split": split,
        "branch": branch,
        "branch_seamless": branch_seamless,
        "tip": tip,
        **{f"leaf_{index + 1}": leaf for index, leaf in enumerate(leaves)},
        **{f"tendril_{index + 1}": tendril for index, tendril in enumerate(tendrils)},
    }
    for name, sprite in named.items():
        save_rgba(cut_dir / f"{name}.png", sprite)
        # 06/07/08 replace the original kit's A/B/C geometry in-game. Keep the
        # older cuts only in research output for traceability.
        if name not in {"trunk_source", "trunk_seamless", "trunk_contour", "split", "branch", "branch_seamless"}:
            save_rgba(game_dir / f"{name}.png", sprite)
    write_checker_preview(cut_dir / "qa-dark-light.png", list(named.values()))
    return list(named.values())


def process_grid(kind: str, raw_path: Path, cut_page: Path, cut_dir: Path, game_dir: Path) -> tuple[np.ndarray, np.ndarray]:
    rgba, background = matte(raw_path)
    if kind == "player":
        rgba = remove_small_components(rgba)
    save_rgba(cut_page, rgba)
    cells = grid_cells(rgba, 4, 2)
    names = PLAYER_NAMES if kind == "player" else SPIDER_NAMES if kind == "spider" else ITEM_NAMES
    crops = [crop_alpha(cell) for cell in cells]
    valid_crops = [crop for crop, name in zip(crops, names) if crop is not None and name is not None]
    if kind == "player":
        normalized = normalize_frames([crop for crop in crops if crop is not None], [0, 1, 3, 7], 88, (144, 144))
        output_sprites = [remove_small_components(frame) for frame in normalized]
    elif kind == "spider":
        normalized = normalize_frames([crop for crop in crops if crop is not None], [0, 1, 2, 3, 7], 108, (176, 152))
        output_sprites = normalized
    else:
        output_sprites = valid_crops
    output_index = 0
    for crop, name in zip(crops, names):
        if crop is None or name is None:
            continue
        sprite = output_sprites[output_index]
        output_index += 1
        save_rgba(cut_dir / f"{name}.png", sprite)
        save_rgba(game_dir / f"{name}.png", sprite)
    write_checker_preview(cut_dir / "qa-dark-light.png", output_sprites)
    return rgba, background


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-dir", type=Path, required=True)
    parser.add_argument("--cut-dir", type=Path, required=True)
    parser.add_argument("--game-dir", type=Path, required=True)
    parser.add_argument("--analyze-world", action="store_true")
    parser.add_argument("--new-vines-only", action="store_true")
    args = parser.parse_args()
    if args.new_vines_only:
        outputs = process_new_vines(
            args.raw_dir,
            args.cut_dir / "world",
            args.game_dir / "world",
        )
        for name, rgba in outputs.items():
            top = rgba[0].astype(np.float32)
            bottom = rgba[-1].astype(np.float32)
            delta = float(np.max(np.abs(top - bottom)))
            print(f"NEW_VINE {name} size={rgba.shape[1]}x{rgba.shape[0]} edge_delta={delta:.3f}/255")
        return

    for kind in ("player", "spider"):
        process_grid(
            kind,
            args.raw_dir / RAW_NAMES[kind],
            args.cut_dir / "pages" / f"{kind}-cut.png",
            args.cut_dir / kind,
            args.game_dir / kind,
        )
    items_rgba, _ = matte(args.raw_dir / RAW_NAMES["items"])
    save_rgba(args.cut_dir / "pages" / "items-cut.png", items_rgba)
    process_items(items_rgba, args.cut_dir / "items", args.game_dir / "items")
    world_rgba, world_background = matte(args.raw_dir / RAW_NAMES["world"])
    save_rgba(args.cut_dir / "pages" / "world-cut.png", world_rgba)
    boxes = component_boxes(world_rgba)
    print("WORLD_COMPONENTS")
    for index, box in enumerate(boxes):
        print(f"{index:02d} x={box[0]} y={box[1]} w={box[2]} h={box[3]} area={box[4]}")
    process_world(world_rgba, args.cut_dir / "world", args.game_dir / "world")
    for kind in ("player", "spider", "items", "world"):
        rgba, background = matte(args.raw_dir / RAW_NAMES[kind])
        edge = rgba[..., 3]
        sample = rgba[(edge >= 16) & (edge <= 239), :3].astype(np.float32)
        mean_distance = float(np.mean(np.linalg.norm(sample - background, axis=1))) if sample.size else 0.0
        print(f"HALO {kind} edge_rgb_distance_from_bg={mean_distance:.3f} bg={background.astype(int).tolist()}")


if __name__ == "__main__":
    main()
