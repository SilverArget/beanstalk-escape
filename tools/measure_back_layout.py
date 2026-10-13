#!/usr/bin/env python3
"""Measure per-skin/per-pose torso geometry and render review boards."""

from __future__ import annotations

import argparse
import colorsys
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


REPO_ROOT = Path(__file__).resolve().parents[1]
FRAME_ROOT = REPO_ROOT / "assets" / "art" / "character_frames"
OUTPUT_JSON = FRAME_ROOT / "emblem_layout.json"
DEFAULT_BOARD_DIR = (
    REPO_ROOT.parent / "03-test" / "amblem-turn-fps-20261013" / "olcum"
)
SKINS = ("m1", "m2", "m3", "f1", "f2", "f3")
POSES = (
    "climb_left",
    "climb_right",
    "climb_reach",
    "hang",
    "jump",
    "fall",
    "cheer",
    "hurt",
)
BACK_POSES = frozenset(POSES[:6])

REFERENCE_BACK_EDGES = {
    ("m1", "hang", 110): (152, 210),
    ("m1", "climb_left", 112): (164, 203),
    ("m1", "climb_reach", 118): (164, 204),
    ("f1", "hang", 111): (152, 207),
    ("m1", "jump", 111): (162, 219),
    ("m1", "fall", 129): (146, 214),
}


def _is_shirt(pixel: tuple[int, int, int, int], skin: str) -> bool:
    r, g, b, a = pixel
    if a < 128:
        return False
    if skin in ("m1", "f1"):
        return g > 65 and g > r * 1.12 and b > r * 0.92
    if skin in ("m2", "f2"):
        return b > 55 and b > r * 1.30 and b > g * 1.12
    return g > 55 and g > b * 1.22 and g > r * 0.82 and r < 150


def _is_hair(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a < 128 or max(r, g, b) < 35:
        return False
    hue, saturation, value = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return 0.015 <= hue <= 0.13 and saturation >= 0.30 and value >= 0.20


def _hsv(pixel: tuple[int, int, int, int]) -> tuple[float, float, float]:
    r, g, b, _ = pixel
    return colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)


def _is_brown(pixel: tuple[int, int, int, int]) -> bool:
    if pixel[3] < 128:
        return False
    hue, saturation, value = _hsv(pixel)
    return 0.015 <= hue <= 0.13 and saturation >= 0.30 and value >= 0.12


def _is_torso_stop(pixel: tuple[int, int, int, int]) -> bool:
    if pixel[3] < 128:
        return True
    hue, saturation, value = _hsv(pixel)
    if value < 0.12:
        return True
    cream_cuff = 0.08 <= hue <= 0.18 and saturation <= 0.48 and value >= 0.48
    skin = 0.015 <= hue <= 0.11 and 0.18 <= saturation <= 0.68 and value >= 0.62
    glove = saturation <= 0.18 and value >= 0.25
    return cream_cuff or skin or glove


def _first_sustained_shirt_row(
    image: Image.Image, skin: str, center_x: int, head_y: int
) -> int:
    pixels = image.load()
    width, height = image.size
    counts: dict[int, int] = {}
    for y in range(max(0, head_y - 15), min(height, head_y + 55)):
        counts[y] = sum(
            _is_shirt(pixels[x, y], skin)
            for x in range(max(0, center_x - 60), min(width, center_x + 61))
        )
    for y in counts:
        following = [counts.get(candidate, 0) for candidate in range(y, y + 12)]
        if counts[y] >= 2 and sum(count >= 2 for count in following) >= 10:
            return y
    raise ValueError(f"shoulder segmentation failed for {skin}")


def _belt_edge(image: Image.Image, center_x: int, torso_y: int) -> int:
    pixels = image.load()
    width, height = image.size
    left = max(0, center_x - 35)
    right = min(width, center_x + 36)
    first = max(0, torso_y)
    last = min(height - 2, torso_y + 25)
    brown_counts = {
        y: sum(_is_brown(pixels[x, y]) for x in range(left, right))
        for y in range(first, last + 2)
    }
    return max(
        range(first, last + 1),
        key=lambda y: (brown_counts[y + 1] - brown_counts[y] - 0.4 * (y - torso_y), -y),
    )


def _back_edges(image: Image.Image, skin: str, center_x: int, y: int) -> tuple[int, int]:
    pixels = image.load()
    width, _ = image.size
    seed = min(
        (x for x in range(max(0, center_x - 16), min(width, center_x + 17)) if not _is_torso_stop(pixels[x, y])),
        key=lambda x: abs(x - center_x),
        default=None,
    )
    if seed is None:
        raise ValueError(f"torso seed not found at ({center_x}, {y})")
    shirt_xs = [
        x
        for sample_y in range(max(0, y - 8), min(image.height, y + 9))
        for x in range(max(0, center_x - 60), min(width, center_x + 61))
        if _is_shirt(pixels[x, sample_y], skin)
    ]
    # The hue families differ, so infer the active family from the seed row.
    if not shirt_xs:
        shirt_xs = list(range(max(0, center_x - 60), min(width, center_x + 61)))

    def next_body_pixel(start: int, direction: int) -> int | None:
        for distance in range(1, 5):
            candidate = start + direction * distance
            if not (0 <= candidate < width):
                return None
            if not _is_torso_stop(pixels[candidate, y]):
                return candidate
        return None

    left = seed
    while left > 0:
        candidate = left - 1
        if not _is_torso_stop(pixels[candidate, y]):
            left = candidate
            continue
        bridged = next_body_pixel(left, -1)
        if bridged is not None:
            left = bridged
            continue
        break
    right = seed
    while right + 1 < width:
        candidate = right + 1
        if not _is_torso_stop(pixels[candidate, y]):
            right = candidate
            continue
        bridged = next_body_pixel(right, 1)
        if bridged is not None:
            right = bridged
            continue
        break
    shirt_left = min(shirt_xs) + 2
    shirt_right = max(shirt_xs)
    if shirt_left > right or shirt_right < left:
        return min(left, shirt_left), max(right, shirt_right)
    return max(left, shirt_left), min(right, shirt_right)


def _auto_measure(image: Image.Image, skin: str, pose: str) -> dict[str, int]:
    anchors = json.loads((FRAME_ROOT / skin / "anchors.json").read_text(encoding="utf-8"))
    frame_anchor = anchors["frames"][pose]
    center_x = int(frame_anchor["outfit_back"][0])
    head_y = int(frame_anchor["head_center"][1])
    shoulder_y = _first_sustained_shirt_row(image, skin, center_x, head_y)
    belt_y = _belt_edge(image, center_x, int(frame_anchor["outfit_back"][1]))
    mid_y = round((shoulder_y + belt_y) / 2)
    back_left, back_right = _back_edges(image, skin, center_x, mid_y)
    return {
        "shoulder_y": shoulder_y,
        "belt_y": belt_y,
        "back_left": back_left,
        "back_right": back_right,
    }


def _hair_bottom(image: Image.Image, head_center: tuple[float, float], head_width: float, belt_y: float) -> int:
    pixels = image.load()
    width, height = image.size
    mask = [[False] * width for _ in range(height)]
    for y in range(max(0, int(head_center[1] - head_width)), min(height, int(belt_y) + 1)):
        for x in range(max(0, int(head_center[0] - head_width)), min(width, int(head_center[0] + head_width) + 1)):
            mask[y][x] = _is_hair(pixels[x, y])
    seed_top = max(0, int(head_center[1] - head_width * 0.65))
    seed_bottom = min(height, int(head_center[1] + head_width * 0.25) + 1)
    seed_left = max(0, int(head_center[0] - head_width * 0.55))
    seed_right = min(width, int(head_center[0] + head_width * 0.55) + 1)
    visited: set[tuple[int, int]] = set()
    components: list[tuple[int, int, int]] = []
    for seed_y in range(seed_top, seed_bottom):
        for seed_x in range(seed_left, seed_right):
            if not mask[seed_y][seed_x] or (seed_x, seed_y) in visited:
                continue
            queue = deque([(seed_x, seed_y)])
            visited.add((seed_x, seed_y))
            size = 0
            seed_hits = 0
            bottom = seed_y
            while queue:
                x, y = queue.popleft()
                size += 1
                bottom = max(bottom, y)
                if seed_left <= x < seed_right and seed_top <= y < seed_bottom:
                    seed_hits += 1
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < width and 0 <= ny < height and mask[ny][nx] and (nx, ny) not in visited:
                        visited.add((nx, ny))
                        queue.append((nx, ny))
            components.append((seed_hits, size, bottom))
    return max(components, default=(0, 0, int(head_center[1])))[2]


def measure_frame(skin: str, pose: str) -> dict[str, object]:
    image = Image.open(FRAME_ROOT / skin / f"{pose}.png").convert("RGBA")
    auto = _auto_measure(image, skin, pose)
    # Eye-measured corrections (strap/hair/sash confuse the colour scan on these frames).
    eye_path = FRAME_ROOT / "emblem_layout_eye.json"
    if eye_path.exists():
        auto.update(json.loads(eye_path.read_text(encoding="utf-8")).get(skin, {}).get(pose, {}))
    shoulder_y = auto["shoulder_y"]
    belt_y = auto["belt_y"]
    back_left = auto["back_left"]
    back_right = auto["back_right"]
    anchors = json.loads((FRAME_ROOT / skin / "anchors.json").read_text(encoding="utf-8"))
    frame_anchor = anchors["frames"][pose]
    mid_y = (shoulder_y + belt_y) / 2
    center_x = (back_left + back_right) / 2
    back_width = back_right - back_left + 1
    return {
        "shoulder_y": shoulder_y,
        "belt_y": belt_y,
        "mid_y": mid_y,
        "back_left": back_left,
        "back_right": back_right,
        "back_width": back_width,
        "center_x": center_x,
        "hair_bottom_y": _hair_bottom(
            image,
            tuple(frame_anchor["head_center"]),
            float(frame_anchor["head_width"]),
            belt_y,
        ),
        "emblem_center": [center_x, mid_y],
        "emblem_width": round(0.43 * back_width),
        "emblem_visible": pose in BACK_POSES,
    }


def _font(size: int) -> ImageFont.ImageFont:
    for path in (Path("C:/Windows/Fonts/consola.ttf"), Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def render_board(skin: str, measurements: dict[str, dict[str, object]], board_dir: Path) -> Path:
    scale = 4
    header = 54
    crop_boxes: dict[str, tuple[int, int, int, int]] = {}
    for pose, data in measurements.items():
        center_x = int(round(float(data["center_x"])))
        crop_boxes[pose] = (
            max(0, center_x - 62),
            max(0, int(float(data["shoulder_y"])) - 18),
            min(360, center_x + 63),
            min(300, int(float(data["belt_y"])) + 24),
        )
    cell_w = max(box[2] - box[0] for box in crop_boxes.values()) * scale
    cell_h = max(box[3] - box[1] for box in crop_boxes.values()) * scale + header
    board = Image.new("RGB", (cell_w * 4, cell_h * 2), (14, 14, 18))
    font = _font(14)
    for index, pose in enumerate(POSES):
        col, row = index % 4, index // 4
        origin = (col * cell_w, row * cell_h)
        crop_box = crop_boxes[pose]
        frame = Image.open(FRAME_ROOT / skin / f"{pose}.png").convert("RGBA").crop(crop_box)
        frame = frame.resize((frame.width * scale, frame.height * scale), Image.Resampling.NEAREST)
        board.paste(frame, (origin[0], origin[1] + header), frame)
        data = measurements[pose]
        draw = ImageDraw.Draw(board)
        oy = origin[1] + header
        shoulder_y = oy + int((float(data["shoulder_y"]) - crop_box[1]) * scale)
        belt_y = oy + int((float(data["belt_y"]) - crop_box[1]) * scale)
        mid_y = oy + int((float(data["mid_y"]) - crop_box[1]) * scale)
        left = origin[0] + int((float(data["back_left"]) - crop_box[0]) * scale)
        right = origin[0] + int((float(data["back_right"]) - crop_box[0]) * scale)
        center_x = origin[0] + int((float(data["center_x"]) - crop_box[0]) * scale)
        radius = int(float(data["emblem_width"]) * scale / 2)
        image_right = origin[0] + frame.width - 1
        draw.line((origin[0], shoulder_y, image_right, shoulder_y), fill=(255, 220, 30), width=1)
        draw.line((origin[0], belt_y, image_right, belt_y), fill=(255, 50, 50), width=1)
        draw.line((left, mid_y, right, mid_y), fill=(210, 70, 255), width=1)
        draw.ellipse((center_x - radius, mid_y - radius, center_x + radius, mid_y + radius), outline=(20, 245, 255), width=1)
        label = f"{pose} S{data['shoulder_y']} B{data['belt_y']} L{data['back_left']} R{data['back_right']} E{data['emblem_width']}"
        draw.text((origin[0] + 4, origin[1] + 14), label, fill=(245, 245, 245), font=font)
    board_dir.mkdir(parents=True, exist_ok=True)
    output = board_dir / f"tablo-ov-{skin}.png"
    board.save(output)
    return output


def validate_reference_edges() -> None:
    failures: list[str] = []
    for (skin, pose, y), (expected_left, expected_right) in REFERENCE_BACK_EDGES.items():
        image = Image.open(FRAME_ROOT / skin / f"{pose}.png").convert("RGBA")
        anchors = json.loads((FRAME_ROOT / skin / "anchors.json").read_text(encoding="utf-8"))
        center_x = int(anchors["frames"][pose]["outfit_back"][0])
        measured_left, measured_right = _back_edges(image, skin, center_x, y)
        print(f"REFERENCE {skin}/{pose} y={y}: {measured_left}-{measured_right}")
        if abs(measured_left - expected_left) > 3 or abs(measured_right - expected_right) > 3:
            failures.append(
                f"{skin}/{pose} y={y}: got {measured_left}-{measured_right}, "
                f"expected {expected_left}-{expected_right} (+/-3)"
            )
    if failures:
        raise ValueError("reference edge validation failed:\n" + "\n".join(failures))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--board-dir", type=Path, default=DEFAULT_BOARD_DIR)
    args = parser.parse_args()
    previous_layout = json.loads(OUTPUT_JSON.read_text(encoding="utf-8")) if OUTPUT_JSON.exists() else {}
    validate_reference_edges()
    layout: dict[str, dict[str, dict[str, object]]] = {}
    for skin in SKINS:
        layout[skin] = {pose: measure_frame(skin, pose) for pose in POSES}
        print(render_board(skin, layout[skin], args.board_dir))
    for skin in SKINS:
        for pose in POSES:
            previous = previous_layout.get(skin, {}).get(pose, {})
            current = layout[skin][pose]
            shoulder_delta = abs(int(current["shoulder_y"]) - int(previous.get("shoulder_y", current["shoulder_y"])))
            belt_delta = abs(int(current["belt_y"]) - int(previous.get("belt_y", current["belt_y"])))
            if shoulder_delta > 4 or belt_delta > 4:
                print(
                    f"LANDMARK_DELTA {skin}/{pose}: shoulder {previous.get('shoulder_y')}->{current['shoulder_y']}, "
                    f"belt {previous.get('belt_y')}->{current['belt_y']}"
                )
    OUTPUT_JSON.write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(OUTPUT_JSON)


if __name__ == "__main__":
    main()
