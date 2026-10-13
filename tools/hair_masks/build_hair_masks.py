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


def ellipse_mask(
    size: tuple[int, int],
    box: list[float],
    bounds: tuple[int, int, int, int],
) -> np.ndarray:
    width, height = size
    left, top, right, bottom = bounds
    xy = (
        round(left + box[0] * (right - left)),
        round(top + box[1] * (bottom - top)),
        round(left + box[2] * (right - left)),
        round(top + box[3] * (bottom - top)),
    )
    image = Image.new("L", size, 0)
    ImageDraw.Draw(image).ellipse(xy, fill=255)
    return np.asarray(image) > 0


def rgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2LAB).astype(np.float32)


def color_distance(lab: np.ndarray, colors: list[list[int]]) -> np.ndarray:
    palette = np.array(colors, dtype=np.uint8).reshape((-1, 1, 3))
    palette_lab = rgb_to_lab(palette).reshape((-1, 3))
    return np.sqrt(np.min(np.sum((lab[..., None, :] - palette_lab[None, None, :, :]) ** 2, axis=3), axis=2))


def build_face_region(
    rgba: np.ndarray,
    connected_hair: np.ndarray,
    common: dict,
    frame: str,
    bounds: tuple[int, int, int, int],
) -> np.ndarray:
    height, width = rgba.shape[:2]
    search_polygons = common.get("face_search_polygons", {}).get(frame, [])
    if not search_polygons:
        return np.zeros((height, width), dtype=bool)

    search = polygon_mask((width, height), search_polygons, bounds)
    rgb = rgba[..., :3]
    ycrcb = cv2.cvtColor(rgb, cv2.COLOR_RGB2YCrCb)
    luminance, cr, cb = [ycrcb[..., index] for index in range(3)]
    # This is deliberately only the seed material for the face. The final
    # region is the filled convex envelope, so brows, eyes and mouth become
    # holes inside the detected skin component instead of hair candidates.
    skin_seed = (
        search
        & (rgba[..., 3] >= int(common["alpha_min"]))
        & (luminance >= 120)
        & (cr >= 132)
        & (cr <= 184)
        & (cb >= 68)
        & (cb <= 136)
        & (rgb[..., 0] >= 205)
        & (rgb[..., 1] >= 125)
        & (rgb[..., 2] >= 75)
    )
    seed_u8 = cv2.morphologyEx(skin_seed.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    ys, xs = np.where(seed_u8 > 0)
    if xs.size < int(common["face_component_min"]):
        return np.zeros((height, width), dtype=bool)
    hull = cv2.convexHull(np.column_stack((xs, ys)).astype(np.int32))
    face = np.zeros((height, width), dtype=np.uint8)
    cv2.fillConvexPoly(face, hull, 1)
    face = cv2.dilate(face, np.ones((7, 7), np.uint8), iterations=1)

    # The seeded hair component is authoritative at the fringe. Removing it
    # from the convex skin envelope retains curved bangs while the envelope
    # still fills isolated eye, brow and mouth holes.
    face[connected_hair] = 0
    return face.astype(bool)


def build_mask(source: Image.Image, common: dict, skin: dict, frame: str) -> tuple[np.ndarray, np.ndarray]:
    rgba = np.asarray(source.convert("RGBA"))
    height, width = rgba.shape[:2]
    bounds = source.getchannel("A").getbbox() or (0, 0, width, height)
    lab = rgb_to_lab(rgba[..., :3])
    palette = skin["palette"]
    distance = color_distance(lab, palette)
    luma = np.dot(rgba[..., :3].astype(np.float32) / 255.0, [0.299, 0.587, 0.114])
    raw_hair = (
        (rgba[..., 3] >= int(common["alpha_min"]))
        & (luma >= float(common["contour_luma_min"]))
        & (distance <= float(skin["lab_distance"]))
    )
    rgb_i16 = rgba[..., :3].astype(np.int16)
    raw_hair &= ~((rgb_i16[..., 0] > 220) & (rgb_i16[..., 1] > 135) & (rgb_i16[..., 2] > 75))
    if "red_green_min" in skin:
        red_green_min = skin.get("red_green_min_by_frame", {}).get(frame, skin["red_green_min"])
        raw_hair &= (rgb_i16[..., 0] - rgb_i16[..., 1]) >= int(red_green_min)
    # Close only one-pixel painted strand gaps. The connected component gives
    # the silhouette; unlike the old head polygons it never becomes a visible
    # horizontal or vertical cut in the output mask.
    closed = raw_hair.astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(closed, 8)
    left, top, right, bottom = bounds
    seed_zone = polygon_mask(
        (width, height), [common["hair_seed_zone"]], bounds
    )
    labels_in_zone = np.unique(labels[seed_zone & raw_hair & (labels > 0)])
    seeded_labels: list[int] = []
    spatial_seeds = skin["hair_seed_points"] if frame == "front" else common["pose_hair_seed_points"][frame]
    for nx, ny in spatial_seeds:
        x = int(np.clip(round(left + nx * (right - left)), 3, width - 4))
        y = int(np.clip(round(top + ny * (bottom - top)), 3, height - 4))
        nearby = labels[y - 3 : y + 4, x - 3 : x + 4]
        seeded_labels.extend(int(label) for label in np.unique(nearby[(nearby > 0)]))
    eligible = np.array(sorted(set(seeded_labels)), dtype=np.int32)
    if eligible.size == 0:
        eligible = labels_in_zone
    if eligible.size == 0:
        raise RuntimeError(f"no seeded hair component: {frame}")
    if seeded_labels:
        keep_labels = [
            int(label)
            for label in eligible
            if seeded_labels.count(int(label)) > 0 and int(stats[int(label), cv2.CC_STAT_AREA]) >= 20
        ]
    else:
        keep_labels = []
    if not keep_labels:
        keep_labels = [int(max(eligible, key=lambda label: int(np.count_nonzero(raw_hair & (labels == label)))))]
    connected_hair = (closed > 0) & np.isin(labels, keep_labels)
    connected_hair = cv2.morphologyEx(connected_hair.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)).astype(bool)
    face_region = build_face_region(rgba, connected_hair, common, frame, bounds)
    mask = connected_hair & ~face_region

    feature_boxes = skin.get("feature_boxes", {}).get(frame, {})
    common_excludes = common.get("pose_exclude_ellipses", {}).get(frame, [])
    for box in list(feature_boxes.values()) + common_excludes:
        feature = ellipse_mask((width, height), box, bounds)
        face_region |= feature
        mask &= ~feature

    max_hair_y = skin.get("max_hair_y", {}).get(frame)
    if max_hair_y is not None:
        cutoff = round(top + float(max_hair_y) * (bottom - top))
        mask[cutoff:, :] = False

    # Preserve dark internal strand lines, but never dye the very dark outer
    # silhouette within three pixels of transparent sprite space.
    opaque = (rgba[..., 3] >= int(common["alpha_min"])).astype(np.uint8)
    edge_distance = cv2.distanceTransform(opaque, cv2.DIST_L2, 3)
    outer_contour = (edge_distance <= 3.0) & (luma < float(common["outer_contour_luma_max"]))
    mask &= ~outer_contour

    excludes = skin.get("manual_exclude_polygons", {}).get(frame, [])
    if excludes:
        mask &= ~polygon_mask((width, height), excludes, bounds)
    return mask, face_region


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


def close_cell(source: Image.Image, mask: np.ndarray, label: str) -> Image.Image:
    alpha_bbox = source.getchannel("A").getbbox() or (0, 0, source.width, source.height)
    left, top, right, bottom = alpha_bbox
    head_bottom = min(bottom, top + round((bottom - top) * 0.45))
    pad = 8
    crop = (max(0, left - pad), max(0, top - pad), min(source.width, right + pad), min(source.height, head_bottom + pad))
    original = source.convert("RGBA").crop(crop)
    dyed = overlay(source, mask).crop(crop)
    pair = Image.new("RGBA", (original.width * 2, original.height + 18), (28, 35, 42, 255))
    pair.paste(original, (0, 18), original)
    pair.paste(dyed, (original.width, 18), dyed)
    ImageDraw.Draw(pair).text((4, 2), label, fill=(255, 255, 255, 255), font=ImageFont.load_default())
    return pair.resize((pair.width * 3, pair.height * 3), Image.Resampling.NEAREST)


def feature_count(mask: np.ndarray, box: list[float], bounds: tuple[int, int, int, int]) -> int:
    return int(np.count_nonzero(mask & ellipse_mask((mask.shape[1], mask.shape[0]), box, bounds)))


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
    face_regions: dict[tuple[str, str], np.ndarray] = {}
    sources: dict[tuple[str, str], Image.Image] = {}

    for skin_id in SKIN_ORDER:
        skin_config = config["skins"][skin_id]
        luma["skins"][skin_id] = {}
        for frame in config["frames"]:
            source_path = frame_root / skin_id / f"{frame}.png"
            source = Image.open(source_path).convert("RGBA")
            mask, face_region = build_mask(source, config, skin_config, frame)
            outfit_path = frame_root / skin_id / f"{frame}_outfit_mask.png"
            if outfit_path.exists():
                outfit_alpha = np.asarray(Image.open(outfit_path).convert("RGBA"))[..., 3]
                mask &= outfit_alpha < 128
            if not np.any(mask):
                raise RuntimeError(f"empty hair mask: {skin_id}/{frame}")
            face_overlap = int(np.count_nonzero(mask & face_region))
            if face_overlap:
                raise RuntimeError(f"hair intersects face: {skin_id}/{frame} ({face_overlap} px)")
            save_mask(frame_root / skin_id / f"{frame}_hair_mask.png", mask)
            source_array = np.asarray(source)
            rgb = source_array[..., :3].astype(np.float32) / 255.0
            luminance = np.dot(rgb, [0.299, 0.587, 0.114])[mask]
            p5, p95 = np.percentile(luminance, [5.0, 95.0])
            luma["skins"][skin_id][frame] = {
                "p5": round(float(p5), 6),
                "p95": round(float(p95), 6),
                "pixels": int(mask.sum()),
                "face_overlap": face_overlap,
            }
            masks[(skin_id, frame)] = mask
            face_regions[(skin_id, frame)] = face_region
            sources[(skin_id, frame)] = source

    luma_path = args.repo / "tools" / "hair_masks" / "hair_luma.json"
    luma_path.write_text(json.dumps(luma, indent=2) + "\n", encoding="utf-8")

    crop_height = float(config["panel_crop_height"])
    front_rows = [[cell(sources[(skin, "front")], masks[(skin, "front")], skin.upper(), crop_height)] for skin in SKIN_ORDER]
    back_frames = [frame for frame in config["frames"] if frame != "front"]
    back_rows = [[cell(sources[(skin, frame)], masks[(skin, frame)], f"{skin.upper()} {frame}", crop_height) for frame in back_frames] for skin in SKIN_ORDER]
    save_board(args.review_dir / "maske-pano-front.png", front_rows)
    save_board(args.review_dir / "maske-pano-back.png", back_rows)
    close_rows = [[close_cell(sources[(skin, "front")], masks[(skin, "front")], skin.upper())] for skin in SKIN_ORDER]
    save_board(args.review_dir / "maske-yakin-front.png", close_rows)

    print("skin/frame\tpixels\tface_overlap\tp5\tp95")
    for skin in SKIN_ORDER:
        for frame in config["frames"]:
            row = luma["skins"][skin][frame]
            print(f"{skin}/{frame}\t{row['pixels']}\t{row['face_overlap']}\t{row['p5']:.6f}\t{row['p95']:.6f}")
        bounds = sources[(skin, "front")].getchannel("A").getbbox()
        boxes = config["skins"][skin]["feature_boxes"]["front"]
        counts = {name: feature_count(masks[(skin, "front")], box, bounds) for name, box in boxes.items()}
        print(f"{skin}/front_features\teye_left={counts['eye_left']}\teye_right={counts['eye_right']}\tmouth={counts['mouth']}")


if __name__ == "__main__":
    main()
