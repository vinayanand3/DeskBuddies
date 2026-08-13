#!/usr/bin/env python3

"""Normalize transparent DeskBuddies sprites to a shared canvas and ground line."""

from pathlib import Path
import sys

from PIL import Image


CANVAS_SIZE = 512
TARGET_HEIGHT = 430
MAX_WIDTH = 486
BASELINE_Y = 490


def normalize(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
    if bbox is None:
        raise ValueError(f"No visible pixels in {source}")

    sprite = image.crop(bbox)
    scale = min(TARGET_HEIGHT / sprite.height, MAX_WIDTH / sprite.width)
    size = (
        max(1, round(sprite.width * scale)),
        max(1, round(sprite.height * scale)),
    )
    sprite = sprite.resize(size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    origin = ((CANVAS_SIZE - sprite.width) // 2, BASELINE_Y - sprite.height)
    canvas.alpha_composite(sprite, origin)
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, optimize=True)


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: normalize_sprites.py OUTPUT_DIR INPUT...")

    output_directory = Path(sys.argv[1])
    for raw_path in sys.argv[2:]:
        source = Path(raw_path)
        destination = output_directory / source.name
        normalize(source, destination)
        print(destination)


if __name__ == "__main__":
    main()
