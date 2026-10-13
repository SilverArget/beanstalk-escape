"""Generate per-frame cosmetic anchors, garment masks and hair masks.

The character sheets share pose alignment, but hands frequently extend above the
head.  Anchors therefore use a pose-specific anatomical band instead of the
alpha bounding-box top.  Garment masks select the dominant saturated colour in
the torso region and deliberately omit dark outlines and skin-like colours.
"""

from __future__ import annotations

import colorsys
import json
from collections import Counter
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from PIL import ImageDraw


ROOT = Path(__file__).resolve().parents[1] / "assets" / "art" / "character_frames"
SKINS = ("m1", "m2", "m3", "f1", "f2", "f3")
FRAMES = ("climb_left", "climb_right", "climb_reach", "jump", "hurt", "fall", "cheer", "hang", "front")
HEAD_Y = {
    "climb_left": 91,
    "climb_right": 91,
    "climb_reach": 98,
    "jump": 103,
    "hurt": 103,
    "fall": 112,
    "cheer": 103,
    "hang": 100,
    "front": 100,
}
FRONT_FRAMES = {"cheer", "hurt", "front"}


def hue_distance(a: float, b: float) -> float:
    distance = abs(a - b)
    return min(distance, 1.0 - distance)


def skin_like(red: int, green: int, blue: int) -> bool:
    # Broad YCbCr skin exclusion; it intentionally also protects brown hair,
    # leather boots and bags from outfit dye.
    cb = 128.0 - 0.168736 * red - 0.331264 * green + 0.5 * blue
    cr = 128.0 + 0.5 * red - 0.418688 * green - 0.081312 * blue
    return 72.0 <= cb <= 132.0 and 132.0 <= cr <= 184.0 and red > green * 0.92


def head_anchor(rgba: np.ndarray, frame: str) -> tuple[int, int, int]:
    alpha = rgba[:, :, 3] > 48
    seed_y = HEAD_Y[frame]
    band = alpha[max(0, seed_y - 13) : min(alpha.shape[0], seed_y + 14), 125:236]
    ys, xs = np.where(band)
    center_x = int(round(float(np.median(xs + 125)))) if xs.size else 180

    # Measure the central opaque run around the anatomical head band. Raised
    # arms are outside the ±42 px window and cannot steal the anchor.
    local = alpha[max(0, seed_y - 18) : min(alpha.shape[0], seed_y + 19), :]
    occupied = local.sum(axis=0)
    candidates = np.where((occupied >= 5) & (np.arange(alpha.shape[1]) >= center_x - 42) & (np.arange(alpha.shape[1]) <= center_x + 42))[0]
    measured = int(candidates.max() - candidates.min() + 1) if candidates.size else 62
    head_width = max(54, min(72, measured))
    return center_x, seed_y, head_width


def opaque_bounds(mask: np.ndarray, threshold: int = 127) -> tuple[int, int, int, int]:
    ys, xs = np.where(mask > threshold)
    if xs.size == 0:
        raise RuntimeError("Cannot measure empty mask")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def front_head_anchor(rgba: np.ndarray, outfit: np.ndarray) -> tuple[int, int, int]:
    """Measure the 512 px portrait instead of reusing 360 px gameplay coordinates."""
    outfit_x0, outfit_y0, outfit_x1, _ = opaque_bounds(outfit[:, :, 3])
    center_x = int(round((outfit_x0 + outfit_x1 - 1) * 0.5))
    alpha = rgba[:, :, 3] > 127
    widths: list[int] = []
    for y in range(max(0, outfit_y0 - 105), max(0, outfit_y0 - 28)):
        xs = np.where(alpha[y] & (np.arange(alpha.shape[1]) >= center_x - 82) & (np.arange(alpha.shape[1]) <= center_x + 82))[0]
        if xs.size:
            widths.append(int(xs.max() - xs.min() + 1))
    head_width = int(round(float(np.percentile(widths, 62)))) if widths else 112
    return center_x, outfit_y0 - int(round(head_width * 0.55)), max(96, min(132, head_width))


def emblem_anchor(outfit: np.ndarray) -> tuple[int, int, int]:
    """Choose an upper-torso interior point, biased away from straps and edges."""
    alpha = (outfit[:, :, 3] > 127).astype(np.uint8)
    x0, y0, x1, y1 = opaque_bounds(outfit[:, :, 3])
    target_x = (x0 + x1 - 1) * 0.5
    target_y = y0 + (y1 - y0) * 0.25
    distance = cv2.distanceTransform(alpha, cv2.DIST_L2, 5)
    yy, xx = np.indices(alpha.shape)
    search = (
        (alpha > 0)
        & (np.abs(xx - target_x) < 28)
        & (np.abs(yy - target_y) < 24)
    )
    score = distance - np.abs(xx - target_x) * 0.45 - np.abs(yy - target_y) * 0.45
    score[~search] = -1.0
    y, x = np.unravel_index(int(np.argmax(score)), score.shape)
    emblem_width = max(42, min(62, int(round(distance[y, x] * 2.4))))
    return int(x), int(y), emblem_width


def garment_mask(rgba: np.ndarray, anchor: tuple[int, int, int]) -> Image.Image:
    center_x, head_y, head_width = anchor
    height, width = rgba.shape[:2]
    y0 = int(head_y + head_width * 0.58)
    y1 = min(height, int(head_y + head_width * 1.75))
    x0 = max(0, int(center_x - head_width * 0.58))
    x1 = min(width, int(center_x + head_width * 0.58))

    hue_bins: Counter[int] = Counter()
    hsv_cache: dict[tuple[int, int], tuple[float, float, float]] = {}
    for y in range(y0, y1):
        for x in range(x0, x1):
            red, green, blue, alpha = (int(value) for value in rgba[y, x])
            if alpha < 72 or skin_like(red, green, blue):
                continue
            hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
            hsv_cache[(x, y)] = (hue, saturation, value)
            if saturation >= 0.24 and value >= 0.20:
                hue_bins[int(hue * 18.0) % 18] += 1
    dominant_hue = ((hue_bins.most_common(1)[0][0] + 0.5) / 18.0) if hue_bins else 0.5

    result = np.zeros((height, width, 4), dtype=np.uint8)
    torso_center_y = (y0 + y1) * 0.5
    radius_x = max((x1 - x0) * 0.5, 1.0)
    radius_y = max((y1 - y0) * 0.58, 1.0)
    for (x, y), (hue, saturation, value) in hsv_cache.items():
        ellipse = ((x - center_x) / radius_x) ** 2 + ((y - torso_center_y) / radius_y) ** 2
        if ellipse > 1.0 or saturation < 0.16 or value < 0.16 or hue_distance(hue, dominant_hue) > 0.16:
            continue
        # Feather only the mask edge; source luminance supplies fabric shading.
        mask_alpha = int(max(0.0, min(1.0, (1.0 - ellipse) * 5.0)) * int(rgba[y, x, 3]))
        result[y, x] = (255, 255, 255, mask_alpha)
    return Image.fromarray(result, "RGBA")


def hair_palette(rgba: np.ndarray, anchor: tuple[int, int, int], outfit: np.ndarray) -> list[tuple[float, float, float]]:
    """Learn hair colours from the crown, where skin and tunic cannot seed the palette."""
    center_x, head_y, head_width = anchor
    height, width = rgba.shape[:2]
    x0 = max(0, int(center_x - head_width * 0.46))
    x1 = min(width, int(center_x + head_width * 0.46))
    y0 = max(0, int(head_y - head_width * 0.78))
    y1 = min(height, int(head_y - head_width * 0.12))
    bins: Counter[tuple[int, int, int]] = Counter()
    for y in range(y0, y1):
        for x in range(x0, x1):
            red, green, blue, alpha = (int(value) for value in rgba[y, x])
            if alpha < 96 or outfit[y, x, 3] > 16:
                continue
            hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
            if value < 0.08 or saturation < 0.10:
                continue
            bins[(int(hue * 24.0) % 24, int(saturation * 4.0), int(value * 5.0))] += 1
    if not bins:
        return []
    # Several bins preserve the painted highlight/shadow family without
    # admitting unrelated brown gloves, boots or bags outside the head region.
    selected = [entry[0] for entry in bins.most_common(5)]
    return [((hue_bin + 0.5) / 24.0, (sat_bin + 0.5) / 4.0, (val_bin + 0.5) / 5.0) for hue_bin, sat_bin, val_bin in selected]


def hair_mask(
    rgba: np.ndarray,
    anchor: tuple[int, int, int],
    outfit: np.ndarray,
    palette: list[tuple[float, float, float]],
    frame: str,
) -> Image.Image:
    center_x, head_y, head_width = anchor
    height, width = rgba.shape[:2]
    result = np.zeros((height, width, 4), dtype=np.uint8)
    x0 = max(0, int(center_x - head_width * 0.60))
    x1 = min(width, int(center_x + head_width * 0.60))
    y0 = max(0, int(head_y - head_width * 0.82))
    y1 = min(height, int(head_y + head_width * 0.55))
    for y in range(y0, y1):
        for x in range(x0, x1):
            red, green, blue, alpha = (int(value) for value in rgba[y, x])
            if alpha < 64 or outfit[y, x, 3] > 16:
                continue
            dx = (x - center_x) / max(head_width * 0.58, 1.0)
            dy = (y - (head_y - head_width * 0.10)) / max(head_width * 0.70, 1.0)
            if dx * dx + dy * dy > 1.0:
                continue
            # A front-facing face occupies the central lower head oval. Hair
            # may frame it at the sides, but must never dye eyes/cheeks.
            if frame in FRONT_FRAMES and y >= head_y - head_width * 0.12 and abs(x - center_x) < head_width * 0.25:
                continue
            hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
            if value < 0.09 or saturation < 0.10:
                continue
            matches = any(
                hue_distance(hue, sample_hue) <= 0.075
                and abs(saturation - sample_saturation) <= 0.34
                and abs(value - sample_value) <= 0.34
                for sample_hue, sample_saturation, sample_value in palette
            )
            if matches:
                result[y, x] = (255, 255, 255, alpha)
    return Image.fromarray(result, "RGBA")


def front_hair_mask(rgba: np.ndarray, outfit: np.ndarray, allow_long_hair: bool) -> Image.Image:
    """Segment portrait hair from its own crown palette and remove the filled face."""
    outfit_x0, outfit_y0, outfit_x1, _ = opaque_bounds(outfit[:, :, 3])
    center_x = int(round((outfit_x0 + outfit_x1 - 1) * 0.5))
    alpha = rgba[:, :, 3] > 127
    yy, xx = np.indices(alpha.shape)
    head_alpha = alpha & (yy < outfit_y0)
    crown_top = int(np.where(head_alpha)[0].min())
    crown_seed = (
        alpha
        & (np.abs(xx - center_x) <= 66)
        & (yy >= crown_top)
        & (yy <= min(crown_top + 70, outfit_y0 - 48))
    )
    cheek_seed = (
        alpha
        & (np.abs(xx - center_x) <= 18)
        & (yy >= outfit_y0 - 50)
        & (yy <= outfit_y0 - 25)
    )
    lab = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_RGB2LAB).astype(np.float32)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 50, 0.2)
    cv2.setRNGSeed(20261013)
    _, _, hair_centers = cv2.kmeans(lab[crown_seed], 12, None, criteria, 5, cv2.KMEANS_PP_CENTERS)
    _, _, skin_centers = cv2.kmeans(lab[cheek_seed], 5, None, criteria, 5, cv2.KMEANS_PP_CENTERS)
    hair_distance = np.min(np.linalg.norm(lab[:, :, None, :] - hair_centers[None, None, :, :], axis=3), axis=2)
    skin_distance = np.min(np.linalg.norm(lab[:, :, None, :] - skin_centers[None, None, :, :], axis=3), axis=2)

    face_ellipse = ((xx - center_x) / 48.0) ** 2 + ((yy - (outfit_y0 - 54)) / 59.0) ** 2 < 1.0
    skin_candidates = ((skin_distance < 19.0) & face_ellipse & alpha).astype(np.uint8)
    skin_count, skin_labels, skin_stats, _ = cv2.connectedComponentsWithStats(skin_candidates, connectivity=8)
    skin = np.zeros_like(skin_candidates)
    if skin_count > 1:
        central_face = (np.abs(xx - center_x) <= 22) & (yy >= outfit_y0 - 55) & (yy <= outfit_y0 - 25)
        face_label = max(
            range(1, skin_count),
            key=lambda index: int(np.count_nonzero((skin_labels == index) & central_face)),
        )
        if int(skin_stats[face_label, cv2.CC_STAT_AREA]) > 150:
            skin[skin_labels == face_label] = 1
    skin = cv2.morphologyEx(skin, cv2.MORPH_CLOSE, np.ones((3, 3), dtype=np.uint8))
    contours, _ = cv2.findContours(skin, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    filled_face = np.zeros_like(skin)
    face_contours = [contour for contour in contours if cv2.contourArea(contour) > 150.0]
    if face_contours:
        cv2.drawContours(filled_face, [max(face_contours, key=cv2.contourArea)], -1, 1, -1)

    long_hair = outfit_y0 + 42 if allow_long_hair else outfit_y0
    region = (
        alpha
        & (outfit[:, :, 3] <= 16)
        & (np.abs(xx - center_x) <= 102)
        & (yy < long_hair)
    )
    # Below the collar line only side locks/ponytails are eligible.
    region &= (yy < outfit_y0 - 10) | (np.abs(xx - center_x) > 45)
    candidates = region & (hair_distance < 31.0) & (filled_face == 0)
    bang_candidates = (
        region
        & (yy < outfit_y0 - 24)
        & (hair_distance < 25.0)
        & (hair_distance + 9.0 < skin_distance)
    )
    bang_candidates = cv2.morphologyEx(
        bang_candidates.astype(np.uint8),
        cv2.MORPH_OPEN,
        np.ones((2, 2), dtype=np.uint8),
    ).astype(bool)
    bang_count, bang_labels, bang_stats, _ = cv2.connectedComponentsWithStats(bang_candidates.astype(np.uint8), connectivity=8)
    for index in range(1, bang_count):
        component = bang_labels == index
        if int(bang_stats[index, cv2.CC_STAT_AREA]) >= 5 and np.any(component & crown_seed):
            candidates |= component
    count, labels, stats, _ = cv2.connectedComponentsWithStats(candidates.astype(np.uint8), connectivity=8)
    selected = np.zeros_like(candidates)
    for index in range(1, count):
        area = int(stats[index, cv2.CC_STAT_AREA])
        if area < 5:
            continue
        component = labels == index
        face_fraction = float(np.count_nonzero(component & (filled_face > 0))) / float(area)
        if face_fraction > 0.60 and not np.any(component & crown_seed):
            continue
        selected |= component

    result = np.zeros_like(rgba)
    result[selected] = (255, 255, 255, 255)
    return Image.fromarray(result, "RGBA")


def paint_hair_icon(path: Path, base: tuple[int, int, int]) -> None:
    """Draw a compact painted swatch; no character-specific silhouette needed."""
    image = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    dark = tuple(max(0, int(channel * 0.48)) for channel in base) + (255,)
    mid = base + (255,)
    light = tuple(min(255, int(channel * 1.28 + 12)) for channel in base) + (235,)
    outline = (24, 22, 27, 255)
    silhouette = [(35, 129), (44, 76), (72, 42), (92, 68), (112, 34), (151, 61), (161, 126), (139, 150), (55, 150)]
    draw.polygon(silhouette, fill=outline)
    draw.polygon([(42, 126), (50, 80), (73, 52), (92, 78), (112, 44), (144, 67), (153, 124), (135, 141), (58, 141)], fill=dark)
    draw.polygon([(55, 116), (61, 80), (76, 61), (92, 88), (111, 55), (132, 72), (141, 111), (126, 123), (69, 126)], fill=mid)
    draw.line([(66, 91), (77, 72), (91, 99)], fill=light, width=8)
    draw.line([(110, 68), (126, 82), (132, 104)], fill=light, width=7)
    image.save(path, optimize=True)


def main() -> None:
    for skin in SKINS:
        anchors: dict[str, dict[str, object]] = {}
        for frame in FRAMES:
            source = ROOT / skin / f"{frame}.png"
            rgba = np.asarray(Image.open(source).convert("RGBA"))
            outfit_path = ROOT / skin / f"{frame}_outfit_mask.png"
            outfit_image = Image.open(outfit_path).convert("RGBA")
            outfit = np.asarray(outfit_image)
            anchor = front_head_anchor(rgba, outfit) if frame == "front" else head_anchor(rgba, frame)
            emblem_x, emblem_y, emblem_width = emblem_anchor(outfit)
            anchors[frame] = {
                "head_center": [anchor[0], anchor[1]],
                "head_width": anchor[2],
                "face_view": "front" if frame in FRONT_FRAMES else "back",
                "emblem_center": [emblem_x, emblem_y],
                "emblem_width": emblem_width,
            }
            if frame == "front":
                _, _, body_x1, body_y1 = opaque_bounds(rgba[:, :, 3])
                anchors[frame]["pet_anchor"] = [body_x1 + 6, body_y1]
                front_hair_mask(rgba, outfit, skin == "f1").save(ROOT / skin / "front_hair_mask.png", optimize=True)
        (ROOT / skin / "anchors.json").write_text(
            json.dumps({"frames": anchors}, indent=2) + "\n", encoding="utf-8"
        )

    icon_root = ROOT.parent / "cosmetics"
    paint_hair_icon(icon_root / "hair_dark.png", (48, 35, 29))
    paint_hair_icon(icon_root / "hair_blonde.png", (205, 158, 55))
    paint_hair_icon(icon_root / "hair_silver.png", (176, 190, 200))


if __name__ == "__main__":
    main()
