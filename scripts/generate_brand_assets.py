#!/usr/bin/env python3
"""Generate Hotconut brand assets from assets/images/hotconut_logo.png."""

from __future__ import annotations

import io
import os
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "assets/images/hotconut_logo.png"

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/Library/Fonts/Arial Bold.ttf",
]

ANDROID_DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def resize_logo(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.Resampling.LANCZOS)


def get_colored_content_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    rgba = img.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    min_x, min_y = width, height
    max_x, max_y = 0, 0
    found = False

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 10 and (red > 30 or green > 30 or blue > 30):
                found = True
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    if not found:
        return (0, 0, width, height)

    return (min_x, min_y, max_x + 1, max_y + 1)


def fit_logo_to_canvas(logo: Image.Image, canvas_size: int, fill_ratio: float = 0.88) -> Image.Image:
    rgba = logo.convert("RGBA")
    bbox = get_colored_content_bbox(rgba)
    cropped = rgba.crop(bbox)

    crop_width = bbox[2] - bbox[0]
    crop_height = bbox[3] - bbox[1]
    target = int(canvas_size * fill_ratio)
    scale = target / max(crop_width, crop_height)
    new_width = max(1, int(crop_width * scale))
    new_height = max(1, int(crop_height * scale))
    scaled = cropped.resize((new_width, new_height), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    offset_x = (canvas_size - new_width) // 2
    offset_y = (canvas_size - new_height) // 2
    canvas.paste(scaled, (offset_x, offset_y), scaled)
    return canvas


def add_regtest_overlay(img: Image.Image) -> Image.Image:
    result = img.copy().convert("RGBA")
    draw = ImageDraw.Draw(result)
    size = result.width
    font_size = max(10, size // 7)
    font = load_font(font_size)
    text = "REGTEST"
    bbox = draw.textbbox((0, 0), text, font=font, stroke_width=0)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (size - text_w) // 2
    y = size - text_h - max(2, size // 20)
    stroke = max(1, size // 40)
    draw.text(
        (x, y),
        text,
        font=font,
        fill="white",
        stroke_width=stroke,
        stroke_fill="black",
    )
    return result


def make_foreground(logo: Image.Image, canvas_size: int) -> Image.Image:
    """Adaptive icon foreground with safe-zone padding."""
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    inner = int(canvas_size * 0.66)
    scaled = resize_logo(logo, inner)
    offset = (canvas_size - inner) // 2
    canvas.paste(scaled, (offset, offset), scaled if scaled.mode == "RGBA" else None)
    return canvas


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if img.mode == "RGBA":
        img.save(path, "PNG")
    else:
        img.convert("RGB").save(path, "PNG")


def save_webp(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "WEBP", quality=90)


def export_ios_appiconset(appiconset: Path, logo: Image.Image, regtest: bool) -> None:
    if not appiconset.exists():
        return
    for png in appiconset.glob("*.png"):
        size = int(png.stem)
        base = resize_logo(logo, size)
        if regtest:
            base = add_regtest_overlay(base)
        save_png(base, png)


def export_launch_images(imageset: Path, logo: Image.Image, regtest: bool) -> None:
    mapping = {"1x.png": 60, "2x.png": 120, "3x.png": 180}
    for filename, size in mapping.items():
        path = imageset / filename
        if not path.exists():
            continue
        base = resize_logo(logo, size)
        if regtest:
            base = add_regtest_overlay(base)
        save_png(base, path)


def export_splash_assets(logo: Image.Image) -> None:
    outputs = [
        (ROOT / "assets/images/splash_logo_mainnet.png", False, 60),
        (ROOT / "assets/images/splash_logo_regtest.png", True, 60),
        (ROOT / "assets/images/2.0x/splash_logo_mainnet.png", False, 120),
        (ROOT / "assets/images/2.0x/splash_logo_regtest.png", True, 120),
        (ROOT / "assets/images/3.0x/splash_logo_mainnet.png", False, 180),
        (ROOT / "assets/images/3.0x/splash_logo_regtest.png", True, 180),
    ]
    for path, is_regtest, size in outputs:
        base = fit_logo_to_canvas(logo, size)
        if is_regtest:
            base = add_regtest_overlay(base)
        save_png(base, path)

    legacy = ROOT / "assets/images/3.0x/splash_logo.png"
    if legacy.exists():
        save_png(fit_logo_to_canvas(logo, 180), legacy)


def export_android(logo: Image.Image) -> None:
    res = ROOT / "android/app/src/main/res"
    for folder, size in ANDROID_DENSITIES.items():
        mipmap = res / folder

        for name, regtest in [
            ("ic_launcher.webp", False),
            ("ic_launcher_round.webp", False),
            ("ic_launcher_foreground.webp", False),
            ("ic_launcher_regtest.webp", True),
            ("ic_launcher_regtest_round.webp", True),
            ("ic_launcher_regtest_foreground.webp", True),
        ]:
            path = mipmap / name
            if not path.exists():
                continue
            if "foreground" in name:
                base = logo
                if regtest:
                    base = add_regtest_overlay(resize_logo(logo, size))
                img = make_foreground(base, size)
            else:
                img = resize_logo(logo, size)
                if regtest:
                    img = add_regtest_overlay(img)
            save_webp(img, path)


def export_macos(logo: Image.Image) -> None:
    appiconset = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    mapping = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for filename, size in mapping.items():
        save_png(resize_logo(logo, size), appiconset / filename)


def export_web(logo: Image.Image) -> None:
    icons = ROOT / "web/icons"
    for size in (192, 512):
        save_png(resize_logo(logo, size), icons / f"Icon-{size}.png")
        save_png(resize_logo(logo, size), icons / f"Icon-maskable-{size}.png")


def export_readme(logo: Image.Image) -> None:
    readme_dir = ROOT / "assets/readme"
    save_png(resize_logo(logo, 96), readme_dir / "wallet.png")
    coconut_logo = readme_dir / "coconut-logo.png"
    if coconut_logo.exists():
        save_png(resize_logo(logo, 256), coconut_logo)


def _append_png_to_ico(ico_path: Path, png_image: Image.Image) -> None:
    """Append a PNG-compressed frame (Vista+ ICO) for sizes above 256px."""
    buf = io.BytesIO()
    png_image.save(buf, format="PNG")
    png_data = buf.getvalue()

    with ico_path.open("r+b") as f:
        f.seek(0)
        reserved, icon_type, count = struct.unpack("<HHH", f.read(6))
        if icon_type != 1:
            raise ValueError("Not a valid ICO file")

        entries = []
        for _ in range(count):
            entries.append(struct.unpack("<BBBBHHII", f.read(16)))

        data_offset = 6 + (count * 16)
        for entry in entries:
            data_offset = max(data_offset, entry[7] + entry[6])

        new_count = count + 1
        f.seek(0)
        f.write(struct.pack("<HHH", reserved, icon_type, new_count))

        for entry in entries:
            f.write(struct.pack("<BBBBHHII", *entry))

        # width/height 0 means 256 in legacy ICO; PNG payload carries true dimensions.
        f.write(struct.pack("<BBBBHHII", 0, 0, 0, 0, 1, 32, len(png_data), data_offset))
        f.seek(data_offset)
        f.write(png_data)


def export_windows_ico(logo: Image.Image) -> None:
    ico_path = ROOT / "windows/runner/resources/app_icon.ico"
    if not ico_path.parent.exists():
        return
    sizes = [
        (16, 16),
        (20, 20),
        (24, 24),
        (32, 32),
        (40, 40),
        (48, 48),
        (64, 64),
        (96, 96),
        (128, 128),
        (256, 256),
    ]
    # Single high-res source; Pillow embeds all listed sizes into the ICO.
    master = resize_logo(logo, 1024)
    master.save(ico_path, format="ICO", sizes=sizes)
    _append_png_to_ico(ico_path, resize_logo(logo, 512))


def main() -> None:
    if not MASTER.exists():
        raise SystemExit(f"Master logo not found: {MASTER}")

    master = Image.open(MASTER).convert("RGBA")
    # Upscale once for better downscale quality on large icons.
    if master.width < 1024:
        master = master.resize((1024, 1024), Image.Resampling.LANCZOS)

    print("Exporting splash assets...")
    export_splash_assets(master)

    print("Exporting Android mipmaps...")
    export_android(master)

    print("Exporting iOS app icons...")
    export_ios_appiconset(ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset", master, regtest=False)
    export_ios_appiconset(ROOT / "ios/Runner/Assets.xcassets/AppIconRegtest.appiconset", master, regtest=True)

    print("Exporting iOS launch images...")
    export_launch_images(ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset", master, regtest=False)
    export_launch_images(ROOT / "ios/Runner/Assets.xcassets/LaunchImageRegtest.imageset", master, regtest=True)

    print("Exporting macOS icons...")
    export_macos(master)

    print("Exporting web icons...")
    export_web(master)

    print("Exporting readme assets...")
    export_readme(master)

    print("Exporting Windows icon...")
    export_windows_ico(master)

    print("Done.")


if __name__ == "__main__":
    main()
