#!/usr/bin/env python3

"""Split transparent pet sheets, normalize frames, and create thermal variants."""

from colorsys import rgb_to_hsv, hsv_to_rgb
from pathlib import Path
import argparse

from PIL import Image


CANVAS_SIZE = 512
TARGET_HEIGHT = 430
MAX_WIDTH = 486
BASELINE_Y = 490
SOURCE_EDGE_GUARD = 3


def validate_source_edges(frame: Image.Image, frame_index: int) -> None:
    """Reject source cells whose artwork touches an edge and may already be cropped."""
    alpha = frame.convert("RGBA").getchannel("A").point(
        lambda value: 255 if value > 8 else 0
    )
    width, height = frame.size
    guarded_edges = (
        (0, 0, SOURCE_EDGE_GUARD, height),
        (width - SOURCE_EDGE_GUARD, 0, width, height),
        (0, 0, width, SOURCE_EDGE_GUARD),
        (0, height - SOURCE_EDGE_GUARD, width, height),
    )
    if any(alpha.crop(edge).getbbox() is not None for edge in guarded_edges):
        raise ValueError(
            f"Frame {frame_index} contains visible pixels at a cell edge; "
            "the source artwork may be cropped"
        )


def remove_detached_artifacts(frame: Image.Image) -> Image.Image:
    """Keep the main connected alpha component and discard stray generated fragments."""
    frame = frame.convert("RGBA")
    alpha = frame.getchannel("A")
    width, height = frame.size
    alpha_pixels = alpha.load()
    frame_pixels = frame.load()
    for y in range(height):
        for x in range(width):
            if alpha_pixels[x, y] <= 8:
                frame_pixels[x, y] = (0, 0, 0, 0)
    visited: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []

    for y in range(height):
        for x in range(width):
            if (x, y) in visited or alpha_pixels[x, y] <= 8:
                continue
            component: list[tuple[int, int]] = []
            pending = [(x, y)]
            visited.add((x, y))
            while pending:
                current_x, current_y = pending.pop()
                component.append((current_x, current_y))
                for neighbor in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    neighbor_x, neighbor_y = neighbor
                    if (
                        0 <= neighbor_x < width
                        and 0 <= neighbor_y < height
                        and neighbor not in visited
                        and alpha_pixels[neighbor_x, neighbor_y] > 8
                    ):
                        visited.add(neighbor)
                        pending.append(neighbor)
            components.append(component)

    if len(components) <= 1:
        return frame

    main_component = max(components, key=len)
    output = frame.copy()
    output_pixels = output.load()
    for component in components:
        if component is main_component:
            continue
        for x, y in component:
            output_pixels[x, y] = (0, 0, 0, 0)
    return output


def normalized(frame: Image.Image) -> Image.Image:
    frame = remove_detached_artifacts(frame)
    alpha = frame.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
    if bbox is None:
        raise ValueError("Frame contains no visible pixels")

    sprite = frame.crop(bbox)
    scale = min(TARGET_HEIGHT / sprite.height, MAX_WIDTH / sprite.width)
    sprite = sprite.resize(
        (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(sprite, ((CANVAS_SIZE - sprite.width) // 2, BASELINE_Y - sprite.height))
    return canvas


def frames(sheet_path: Path, columns: int = 3, rows: int = 2) -> list[Image.Image]:
    sheet = Image.open(sheet_path).convert("RGBA")
    cell_width = sheet.width // columns
    cell_height = sheet.height // rows
    result = []
    for row in range(rows):
        for column in range(columns):
            frame = sheet.crop((column * cell_width, row * cell_height,
                                (column + 1) * cell_width, (row + 1) * cell_height))
            validate_source_edges(frame, row * columns + column)
            result.append(normalized(frame))
    return result


def content_aligned_frames(
    sheet_path: Path, columns: int = 3, rows: int = 2
) -> list[Image.Image]:
    """Extract generated sprites from transparent gaps instead of assumed cell edges."""
    sheet = Image.open(sheet_path).convert("RGBA")
    row_height = sheet.height // rows
    result = []
    for row in range(rows):
        row_image = sheet.crop((0, row * row_height, sheet.width, (row + 1) * row_height))
        alpha = row_image.getchannel("A").point(lambda value: 255 if value > 8 else 0)
        occupied_columns = [alpha.crop((x, 0, x + 1, row_height)).getbbox() is not None
                            for x in range(sheet.width)]
        ranges = []
        start = None
        for x, occupied in enumerate(occupied_columns + [False]):
            if occupied and start is None:
                start = x
            elif not occupied and start is not None:
                ranges.append((start, x))
                start = None
        if len(ranges) != columns:
            raise ValueError(
                f"Row {row} contains {len(ranges)} separated sprites; expected {columns}"
            )
        for left, right in ranges:
            result.append(normalized(row_image.crop((left, 0, right, row_height))))
    return result


def thermal_variant(image: Image.Image, target_rgb: tuple[int, int, int]) -> Image.Image:
    result = image.copy()
    pixels = result.load()
    target_hue, _, _ = rgb_to_hsv(*(component / 255 for component in target_rgb))

    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            hue, saturation, value = rgb_to_hsv(red / 255, green / 255, blue / 255)
            is_mint_surface = green > red * 1.04 and green > blue * 1.02 and saturation > 0.12
            if not is_mint_surface:
                continue
            new_saturation = max(saturation, 0.62)
            new_red, new_green, new_blue = hsv_to_rgb(target_hue, new_saturation, value)
            pixels[x, y] = (round(new_red * 255), round(new_green * 255), round(new_blue * 255), alpha)

    return result


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def save_existing_thermal_animation_variants(output: Path, prefix: str) -> None:
    colors = {
        "Fair": (255, 205, 35),
        "Serious": (255, 112, 24),
    }
    for activity in ("Walk", "Groom"):
        for source in sorted(output.glob(f"{prefix}{activity}[0-9]*.png")):
            frame_number = source.stem.removeprefix(f"{prefix}{activity}")
            if not frame_number.isdigit():
                continue
            image = Image.open(source).convert("RGBA")
            for suffix, color in colors.items():
                save(
                    thermal_variant(image, color),
                    output / f"{prefix}{activity}{suffix}{frame_number}.png",
                )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", required=True)
    parser.add_argument("--states", type=Path)
    parser.add_argument("--walk", type=Path)
    parser.add_argument("--walk-columns", type=int, default=3)
    parser.add_argument("--walk-by-content", action="store_true")
    parser.add_argument("--groom", type=Path)
    parser.add_argument("--thermalize-existing", action="store_true")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    prefix = "Tempurr" if args.profile == "Cat" else f"Tempurr{args.profile}"
    if args.states:
        state_frames = frames(args.states)
        expression_names = ["Nominal", "Delighted", "Wink", "Annoyed", "Relaxed"]
        for name, frame in zip(expression_names, state_frames):
            save(frame, args.output / f"{prefix}{name}.png")

        nominal = state_frames[0]
        for name, color in {
            "Fair": (255, 205, 35),
            "Serious": (255, 112, 24),
            "Critical": (245, 32, 50),
        }.items():
            save(thermal_variant(nominal, color), args.output / f"{prefix}{name}.png")

    if args.walk:
        walk_frames = (
            content_aligned_frames(args.walk, columns=args.walk_columns)
            if args.walk_by_content
            else frames(args.walk, columns=args.walk_columns)
        )
        for index, frame in enumerate(walk_frames):
            save(frame, args.output / f"{prefix}Walk{index}.png")
    if args.groom:
        for index, frame in enumerate(frames(args.groom)):
            save(frame, args.output / f"{prefix}Groom{index}.png")
    if args.thermalize_existing:
        save_existing_thermal_animation_variants(args.output, prefix)


if __name__ == "__main__":
    main()
