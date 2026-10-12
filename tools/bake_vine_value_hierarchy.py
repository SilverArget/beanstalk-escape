"""Bake the locked Gate 3A value hierarchy from vine tile v2 into v3."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art/world/vine_surface_tile_v2.png"
TARGET = ROOT / "assets/art/world/vine_surface_tile_v3.png"
LO = (40.0, 112.0, 70.0)
LUMA = (0.299, 0.587, 0.114)
KNEE = 0.50
BLACK_BLEND_END = 0.18
SHADOW_TINT = (0.80, 1.00, 1.55)


def luminance(rgb: tuple[float, float, float]) -> float:
    return sum(channel * weight for channel, weight in zip(rgb, LUMA)) / 255.0


def rescale_to_luminance(rgb: list[float], target: float) -> list[float]:
    current = luminance(tuple(rgb))
    if current <= 1e-9:
        return [channel * target / luminance(LO) for channel in LO]
    return [channel * target / current for channel in rgb]


def transform(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    source = [float(channel) for channel in rgb]
    y = luminance(tuple(source))
    yf = luminance(LO)
    yn = yf + y * (KNEE - yf) / KNEE if y < KNEE else y
    color = rescale_to_luminance(source, yn)

    if y < BLACK_BLEND_END:
        weight = 1.0 - y / BLACK_BLEND_END
        floor_color = [channel * yn / yf for channel in LO]
        color = [
            channel * (1.0 - weight) + floor_channel * weight
            for channel, floor_channel in zip(color, floor_color)
        ]

    if y < KNEE:
        shift = 0.6 * ((KNEE - y) / KNEE) ** 1.2
        tinted = [channel * factor for channel, factor in zip(color, SHADOW_TINT)]
        color = [
            channel * (1.0 - shift) + tinted_channel * shift
            for channel, tinted_channel in zip(color, tinted)
        ]
        color = rescale_to_luminance(color, yn)

    return tuple(max(0, min(255, round(channel))) for channel in color)


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    target = Image.new("RGB", source.size)
    target.putdata([transform(pixel) for pixel in source.getdata()])
    target.save(TARGET, format="PNG", optimize=False)


if __name__ == "__main__":
    main()
