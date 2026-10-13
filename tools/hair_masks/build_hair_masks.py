#!/usr/bin/env python3
"""Build deterministic per-frame hair masks, luminance ranges, and review boards."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont


SKIN_ORDER = ("m1", "m2", "m3", "f1", "f2", "f3")
PURPLE = np.array([255, 0, 220], dtype=np.float32)


def polygon_mask(
    size: tuple[int, int],
    polygons: list[list[list[float]]],
    bounds: tuple[int, int, int, int],
) -> np.ndarray:
    width, height = size
    left, top, right, bottom = bounds
    bound_width = right - left
    bound_height = bottom - top
    image = Image.new("L", size, 0)
    draw = ImageDraw.Draw(image)
    for polygon in polygons:
        points = [(round(left + x * bound_width), round(top + y * bound_height)) for x, y in polygon]
        draw.polygon(points, fill=255)
    return np.asarray(image) > 0


def rgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2LAB).astype(np.float32)


def build_mask(source: Image.Image, common: dict, skin: dict, frame: str) -> np.ndarray:
    rgba = np.asarray(source.convert("RGBA"))
    height, width = rgba.shape[:2]
    bounds = source.getchannel("A").getbbox() or (0, 0, width, height)
    override = skin.get("frame_overrides", {}).get(frame, {})
    regions = [skin["head_polygon"]] + skin.get("include_polygons", []) + override.get("include_polygons", [])
    allowed = polygon_mask((width, height), regions, bounds)

    lab = rgb_to_lab(rgba[..., :3])
    palette = np.array(skin["palette"], dtype=np.uint8).reshape((-1, 1, 3))
    palette_lab = rgb_to_lab(palette).reshape((-1, 3))
    distance = np.sqrt(np.min(np.sum((lab[..., None, :] - palette_lab[None, None, :, :]) ** 2, axis=3), axis=2))
    luma = np.dot(rgba[..., :3].astype(np.float32) / 255.0, [0.299, 0.587, 0.114])
    mask = (
        allowed
        & (rgba[..., 3] >= int(common["alpha_min"]))
        & (luma >= float(common["contour_luma_min"]))
        & (distance <= float(skin["lab_distance"]))
    )

    # Hair shades are separated by painted one-pixel lines. Join nearby shade
    # islands only for component labelling, then retain the original pixels
    # belonging to components that originate in the upper central head seed.
    joined = cv2.dilate(mask.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=1)
    _, labels = cv2.connectedComponents(joined)
    left, top, right, bottom = bounds
    seed = polygon_mask(
        (width, height),
        [[[0.28, 0.00], [0.72, 0.00], [0.72, 0.27], [0.28, 0.27]]],
        bounds,
    )
    keep_labels = np.unique(labels[seed & (labels > 0)])
    mask &= np.isin(labels, keep_labels)

    excludes = (
        common.get("pose_exclude_polygons", {}).get(frame, [])
        + skin.get("exclude_polygons", [])
        + override.get("exclude_polygons", [])
    )
    if excludes:
        mask &= ~polygon_mask((width, height), excludes, bounds)
    return mask


def save_mask(path: Path, mask: np.ndarray) -> None:
    alpha = np.where(mask, 255, 0).astype(np.uint8)
    rgba = np.zeros((*alpha.shape, 4), dtype=np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = alpha
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)


def overlay(source: Image.Image, mask: np.ndarray) -> Image.Image:
    rgba = np.asarray(source.convert("RGBA")).copy()
    selected = mask & (rgba[..., 3] > 0)
    rgba[selected, :3] = np.rint(rgba[selected, :3] * 0.30 + PURPLE * 0.70).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def used_bbox(source: Image.Image, crop_height: float) -> tuple[int, int, int, int]:
    alpha = source.convert("RGBA").getchannel("A")
    bbox = alpha.getbbox() or (0, 0, source.width, source.height)
    left, top, right, bottom = bbox
    pad = 5
    height = max(1, round((bottom - top) * crop_height))
    return max(0, left - pad), max(0, top - pad), min(source.width, right + pad), min(source.height, top + height + pad)


def cell(source: Image.Image, mask: np.ndarray, label: str, crop_height: float) -> Image.Image:
    crop = used_bbox(source, crop_height)
    original = source.convert("RGBA").crop(crop)
    dyed = overlay(source, mask).crop(crop)
    pair = Image.new("RGBA", (original.width * 2, original.height + 18), (28, 35, 42, 255))
    pair.paste(original, (0, 18), original)
    pair.paste(dyed, (original.width, 18), dyed)
    ImageDraw.Draw(pair).text((4, 2), label, fill=(255, 255, 255, 255), font=ImageFont.load_default())
    return pair.resize((pair.width * 2, pair.height * 2), Image.Resampling.NEAREST)


def save_board(path: Path, rows: list[list[Image.Image]]) -> None:
    column_widths = [max(row[index].width for row in rows if index < len(row)) for index in range(max(map(len, rows)))]
    row_heights = [max(item.height for item in row) for row in rows]
    board = Image.new("RGBA", (sum(column_widths), sum(row_heights)), (24, 31, 37, 255))
    y = 0
    for row, row_height in zip(rows, row_heights):
        x = 0
        for index, item in enumerate(row):
            board.paste(item, (x, y), item)
            x += column_widths[index]
        y += row_height
    path.parent.mkdir(parents=True, exist_ok=True)
    board.convert("RGB").save(path, quality=94)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--review-dir", type=Path, default=Path(__file__).resolve().parents[3] / "03-test" / "sac-20261013")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config_path = args.repo / "tools" / "hair_masks" / "hair_regions.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    frame_root = args.repo / "assets" / "art" / "character_frames"
    luma = {"version": 1, "skins": {}}
    masks: dict[tuple[str, str], np.ndarray] = {}
    sources: dict[tuple[str, str], Image.Image] = {}

    for skin_id in SKIN_ORDER:
        skin_config = config["skins"][skin_id]
        luma["skins"][skin_id] = {}
        for frame in config["frames"]:
            source_path = frame_root / skin_id / f"{frame}.png"
            source = Image.open(source_path).convert("RGBA")
            mask = build_mask(source, config, skin_config, frame)
            if not np.any(mask):
                raise RuntimeError(f"empty hair mask: {skin_id}/{frame}")
            save_mask(frame_root / skin_id / f"{frame}_hair_mask.png", mask)
            source_array = np.asarray(source)
            rgb = source_array[..., :3].astype(np.float32) / 255.0
            luminance = np.dot(rgb, [0.299, 0.587, 0.114])[mask]
            p5, p95 = np.percentile(luminance, [5.0, 95.0])
            luma["skins"][skin_id][frame] = {"p5": round(float(p5), 6), "p95": round(float(p95), 6), "pixels": int(mask.sum())}
            masks[(skin_id, frame)] = mask
            sources[(skin_id, frame)] = source

    luma_path = args.repo / "tools" / "hair_masks" / "hair_luma.json"
    luma_path.write_text(json.dumps(luma, indent=2) + "\n", encoding="utf-8")

    crop_height = float(config["panel_crop_height"])
    front_rows = [[cell(sources[(skin, "front")], masks[(skin, "front")], skin.upper(), crop_height)] for skin in SKIN_ORDER]
    back_frames = [frame for frame in config["frames"] if frame != "front"]
    back_rows = [[cell(sources[(skin, frame)], masks[(skin, frame)], f"{skin.upper()} {frame}", crop_height) for frame in back_frames] for skin in SKIN_ORDER]
    save_board(args.review_dir / "maske-pano-front.png", front_rows)
    save_board(args.review_dir / "maske-pano-back.png", back_rows)

    print("skin/frame\tpixels\tp5\tp95")
    for skin in SKIN_ORDER:
        for frame in config["frames"]:
            row = luma["skins"][skin][frame]
            print(f"{skin}/{frame}\t{row['pixels']}\t{row['p5']:.6f}\t{row['p95']:.6f}")


if __name__ == "__main__":
    main()
