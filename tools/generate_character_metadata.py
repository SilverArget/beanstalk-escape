"""Generate per-frame cosmetic anchors and garment masks.

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
BELT_ROW_HINTS = {
    "climb_left": 141,
    "climb_right": 137,
    "climb_reach": 147,
    "hang": 137,
    "jump": 134,
    "hurt": 144,
    "fall": 158,
    "cheer": 139,
}


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
            anchors[frame] = {
                "head_center": [anchor[0], anchor[1]],
                "head_width": anchor[2],
                "face_view": "front" if frame in FRONT_FRAMES else "back",
            }
            if frame == "front":
                _, _, body_x1, body_y1 = opaque_bounds(rgba[:, :, 3])
                anchors[frame]["pet_anchor"] = [body_x1 + 7, body_y1]
        (ROOT / skin / "anchors.json").write_text(
            json.dumps({"frames": anchors}, indent=2) + "\n", encoding="utf-8"
        )

if __name__ == "__main__":
    main()
