import json
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "outfit_moss": ("LEAF RANGER", "FALLING LEAVES", 150, 1),
    "outfit_fern": ("BLOSSOM VEST", "PETAL DRIFT", 250, 2),
    "outfit_sky": ("SKY CAPE", "CLOUD PUFFS", 0, 3),
    "outfit_ocean": ("TIDE SAILOR", "BUBBLE STREAM", 400, 3),
    "outfit_plum": ("STORM HOOD", "SPARK ARCS", 550, 4),
    "outfit_ember": ("EMBER ROBE", "EMBER SPARKS", 700, 5),
    "outfit_clay": ("FROST GUARD", "SNOW GLITTER", 900, 6),
    "outfit_sun": ("SUNBURST", "SUN RAYS", 1100, 7),
    "outfit_night": ("NIGHT DIAMOND", "STAR DUST", 1400, 8),
}


def test_outfit_catalog_and_art() -> None:
    economy = json.loads((ROOT / "config/economy.json").read_text(encoding="utf-8"))
    outfits = {item["id"]: item for item in economy["cosmetics"] if item["slot"] == "OUTFIT"}
    assert set(outfits) == set(EXPECTED)
    assert len({item["image"] for item in outfits.values()}) == 9

    for outfit_id, expected in EXPECTED.items():
        item = outfits[outfit_id]
        assert (item["name"], item["effect_name"], item["price"], item["level"]) == expected
        assert "tint" not in item
        assert item["image"] == f"{outfit_id}.png"
        for folder in ("icons", "back"):
            with Image.open(ROOT / f"assets/art/outfits/{folder}/{outfit_id}.png") as image:
                assert image.size == (256, 256)
        for character in ("m1", "m2", "m3", "f1", "f2", "f3"):
            with Image.open(ROOT / f"assets/art/outfits/front/{character}/{outfit_id}.png") as image:
                assert image.size == (512, 512)
                base = Image.open(ROOT / f"assets/art/character_frames/{character}/front.png").convert("RGBA")
                mask = Image.open(ROOT / f"assets/art/character_frames/{character}/front_hair_mask.png").convert("RGBA").getchannel("A")
                difference = ImageChops.difference(image.convert("RGBA"), base)
                masked_difference = ImageChops.multiply(difference, Image.merge("RGBA", (mask, mask, mask, mask)))
                assert masked_difference.getbbox() is None

    assert outfits["outfit_sky"]["source"] == "DAY 7 BONUS"


if __name__ == "__main__":
    test_outfit_catalog_and_art()
    print("PASS: 9 outfit catalog entries and 72 outfit assets")
