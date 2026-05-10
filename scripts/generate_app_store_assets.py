#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "screenshots"
OUT = ROOT / "app-store-assets"

AMBER = (255, 176, 45)
INK = (9, 10, 14)
PANEL = (18, 20, 27)
MIST = (226, 235, 233)
TEAL = (88, 210, 184)
WHITE = (250, 250, 246)
MUTED = (174, 179, 178)


@dataclass(frozen=True)
class Shot:
    title: str
    subtitle: str
    source: Path
    dark: bool = True


def font(size: int, weight: str = "Regular") -> ImageFont.FreeTypeFont:
    candidates = [
        f"/System/Library/Fonts/SFNS{weight}.ttf",
        f"/System/Library/Fonts/SFNS.ttf",
        f"/System/Library/Fonts/Supplemental/Arial {weight}.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


FONT_TITLE = font(74, "Bold")
FONT_TITLE_SMALL = font(58, "Bold")
FONT_BODY = font(34)
FONT_BODY_SMALL = font(28)
FONT_CAPTION = font(24)


def reset_output() -> None:
    for child in ["screenshots", "previews", "review"]:
        target = OUT / child
        if target.exists():
            shutil.rmtree(target)
    (OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    (OUT / "previews").mkdir(parents=True, exist_ok=True)
    (OUT / "review").mkdir(parents=True, exist_ok=True)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def cover_resize(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = max(size[0] / img.width, size[1] / img.height)
    resized = img.resize((math.ceil(img.width * scale), math.ceil(img.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def contain_resize(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = min(size[0] / img.width, size[1] / img.height)
    return img.resize((round(img.width * scale), round(img.height * scale)), Image.Resampling.LANCZOS)


def background(size: tuple[int, int], dark: bool = True) -> Image.Image:
    width, height = size
    base = Image.new("RGB", size, INK if dark else (238, 244, 241))
    px = base.load()
    for y in range(height):
        for x in range(width):
            t = y / max(1, height - 1)
            s = x / max(1, width - 1)
            if dark:
                r = int(8 + 18 * t + 10 * s)
                g = int(10 + 16 * t + 24 * s)
                b = int(14 + 22 * t + 16 * (1 - s))
            else:
                r = int(240 - 16 * t - 10 * s)
                g = int(246 - 20 * t)
                b = int(242 - 18 * t + 6 * s)
            px[x, y] = (r, g, b)
    draw = ImageDraw.Draw(base, "RGBA")
    for y in range(0, height, 8):
        draw.line((0, y, width, y), fill=(255, 255, 255, 10 if dark else 20), width=1)
    draw.rectangle((0, height - height // 5, width, height), fill=(255, 176, 45, 18 if dark else 30))
    return base


def draw_wrapped(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], max_width: int,
                 font_obj: ImageFont.FreeTypeFont, fill: tuple[int, int, int], spacing: int = 12) -> int:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textbbox((0, 0), candidate, font=font_obj)[2] <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    x, y = xy
    line_h = draw.textbbox((0, 0), "Ag", font=font_obj)[3] + spacing
    for line in lines:
        draw.text((x, y), line, font=font_obj, fill=fill)
        y += line_h
    return y


def paste_card(canvas: Image.Image, shot: Image.Image, box: tuple[int, int, int, int], radius: int) -> None:
    x, y, w, h = box
    fitted = cover_resize(shot, (w, h)).convert("RGBA")
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x + 8, y + 18, x + w + 8, y + h + 18), radius=radius, fill=(0, 0, 0, 120))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    card = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    card.alpha_composite(fitted)
    canvas.paste(card, (x, y), rounded_mask((w, h), radius))


def make_phone(shot: Shot, dest: Path, size: tuple[int, int] = (1242, 2688)) -> None:
    canvas = background(size, shot.dark).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    scale = size[0] / 1242
    margin = round(92 * scale)
    top = round(112 * scale)
    title_font = font(round(74 * scale), "Bold")
    body_font = font(round(34 * scale))
    draw.text((margin, top), "iGopherBrowser", font=body_font, fill=AMBER if shot.dark else (20, 36, 34))
    y = draw_wrapped(draw, shot.title, (margin, top + round(80 * scale)), size[0] - margin * 2,
                     title_font, WHITE if shot.dark else (18, 26, 28), round(10 * scale))
    draw_wrapped(draw, shot.subtitle, (margin, y + round(22 * scale)), size[0] - margin * 3,
                 body_font, MUTED if shot.dark else (61, 77, 76), round(8 * scale))
    src = Image.open(shot.source).convert("RGB")
    card_x = round(126 * scale)
    card_w = size[0] - card_x * 2
    card_y = round(size[1] * 0.242)
    card_h = size[1] - card_y - round(148 * scale)
    paste_card(canvas, src, (card_x, card_y, card_w, card_h), round(78 * scale))
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(dest, quality=96)


def make_ipad(shot: Shot, dest: Path) -> None:
    size = (2064, 2752)
    canvas = background(size, shot.dark).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    draw.text((136, 130), "iGopherBrowser", font=FONT_BODY, fill=AMBER if shot.dark else (20, 36, 34))
    y = draw_wrapped(draw, shot.title, (136, 225), 1500, FONT_TITLE, WHITE if shot.dark else (18, 26, 28), 12)
    draw_wrapped(draw, shot.subtitle, (136, y + 22), 1250, FONT_BODY, MUTED if shot.dark else (61, 77, 76), 8)
    src = Image.open(shot.source).convert("RGB")
    paste_card(canvas, src, (190, 720, 1684, 1910), 66)
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(dest, quality=96)


def make_landscape(shot: Shot, dest: Path, size: tuple[int, int], screenshot_box: tuple[int, int, int, int]) -> None:
    canvas = background(size, shot.dark).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    title_font = FONT_TITLE if size[0] > 3000 else FONT_TITLE_SMALL
    body_font = FONT_BODY if size[0] > 3000 else FONT_BODY_SMALL
    left = 112 if size[0] < 3000 else 180
    draw.text((left, 140), "iGopherBrowser", font=body_font, fill=AMBER)
    y = draw_wrapped(draw, shot.title, (left, 230), screenshot_box[0] - left - 60, title_font, WHITE, 12)
    draw_wrapped(draw, shot.subtitle, (left, y + 28), screenshot_box[0] - left - 80, body_font, MUTED, 8)
    src = Image.open(shot.source).convert("RGB")
    paste_card(canvas, src, screenshot_box, 48)
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(dest, quality=96)


def write_readme() -> None:
    text = """# App Store Assets

Generated from local simulator screenshots.

Validate screenshots:

```sh
asc screenshots validate --path app-store-assets/screenshots/en-US/iphone-65 --device-type IPHONE_65
asc screenshots validate --path app-store-assets/screenshots/en-US/ipad-pro-129 --device-type IPAD_PRO_3GEN_129
asc screenshots validate --path app-store-assets/screenshots/en-US/macos --device-type DESKTOP
asc screenshots validate --path app-store-assets/screenshots/en-US/visionos --device-type APPLE_VISION_PRO
```

Upload screenshots:

```sh
asc screenshots upload --app "$ASC_APP_ID" --version "$ASC_VERSION" --path app-store-assets/screenshots --device-type IPHONE_65 --platform IOS --dry-run
asc screenshots upload --app "$ASC_APP_ID" --version "$ASC_VERSION" --path app-store-assets/screenshots --device-type IPAD_PRO_3GEN_129 --platform IOS --dry-run
asc screenshots upload --app "$ASC_APP_ID" --version "$ASC_VERSION" --path app-store-assets/screenshots --device-type DESKTOP --platform MAC_OS --dry-run
asc screenshots upload --app "$ASC_APP_ID" --version "$ASC_VERSION" --path app-store-assets/screenshots --device-type APPLE_VISION_PRO --platform VISION_OS --dry-run
```

Upload previews by localization:

```sh
asc video-previews upload --version-localization "$ASC_VERSION_LOCALIZATION_ID" --path app-store-assets/previews/en-US/iphone-65 --device-type IPHONE_65 --dry-run
asc video-previews upload --version-localization "$ASC_VERSION_LOCALIZATION_ID" --path app-store-assets/previews/en-US/ipad-pro-129 --device-type IPAD_PRO_3GEN_129 --dry-run
asc video-previews upload --version-localization "$ASC_VERSION_LOCALIZATION_ID" --path app-store-assets/previews/en-US/macos --device-type DESKTOP --dry-run
asc video-previews upload --version-localization "$ASC_VERSION_LOCALIZATION_ID" --path app-store-assets/previews/en-US/visionos --device-type APPLE_VISION_PRO --dry-run
```

Current iGopherBrowser 1.2.0 targets discovered with `asc`:

- App ID: `6474638845`
- iOS version ID: `71b08161-5aaa-4ebf-9721-a732557cbf67`
- iOS en-US localization ID: `1b4ae050-a412-4a9a-bbf5-e58441a1ba91`
- macOS version ID: `e01c93cb-37ea-419f-b755-9073fe58e464`
- macOS en-US localization ID: `b6711156-7077-4092-8b53-d1ccd0ac340d`
- visionOS version ID: `0a7a27a4-d474-4495-84fa-9b58f95c2e91`
- visionOS en-US localization ID: `872137d8-3ad1-4b9c-8355-b3e048e3c0f2`

Dry-run the exact current upload plan:

```sh
asc screenshots upload --app 6474638845 --version 1.2.0 --path app-store-assets/screenshots --device-type IPHONE_65 --platform IOS --dry-run
asc screenshots upload --app 6474638845 --version 1.2.0 --path app-store-assets/screenshots --device-type IPAD_PRO_3GEN_129 --platform IOS --dry-run
asc screenshots upload --app 6474638845 --version 1.2.0 --path app-store-assets/screenshots --device-type DESKTOP --platform MAC_OS --dry-run
asc screenshots upload --app 6474638845 --version 1.2.0 --path app-store-assets/screenshots --device-type APPLE_VISION_PRO --platform VISION_OS --dry-run

asc video-previews upload --version-localization 1b4ae050-a412-4a9a-bbf5-e58441a1ba91 --path app-store-assets/previews/en-US/iphone-65 --device-type IPHONE_65 --dry-run
asc video-previews upload --version-localization 1b4ae050-a412-4a9a-bbf5-e58441a1ba91 --path app-store-assets/previews/en-US/ipad-pro-129 --device-type IPAD_PRO_3GEN_129 --dry-run
asc video-previews upload --version-localization b6711156-7077-4092-8b53-d1ccd0ac340d --path app-store-assets/previews/en-US/macos --device-type DESKTOP --dry-run
asc video-previews upload --version-localization 872137d8-3ad1-4b9c-8355-b3e048e3c0f2 --path app-store-assets/previews/en-US/visionos --device-type APPLE_VISION_PRO --dry-run
```

Remove `--dry-run` when ready to upload. Add `--replace` if the target slot should be cleared first.
"""
    (OUT / "README.md").write_text(text)


def make_preview(images: list[Path], dest: Path, size: tuple[int, int]) -> None:
    with tempfile.TemporaryDirectory(prefix=f"igopher-{dest.parent.name}-frames-") as temp:
        frames_dir = Path(temp)
        fps = 30
        minimum_frames = fps * 15
        frame_count = math.ceil(minimum_frames / len(images))
        frame_index = 0
        for image_path in images:
            img = Image.open(image_path).convert("RGB")
            for i in range(frame_count):
                zoom = 1.0 + 0.035 * (i / max(1, frame_count - 1))
                large = img.resize((round(size[0] * zoom), round(size[1] * zoom)), Image.Resampling.LANCZOS)
                x = (large.width - size[0]) // 2
                y = (large.height - size[1]) // 2
                frame = large.crop((x, y, x + size[0], y + size[1]))
                frame.save(frames_dir / f"frame_{frame_index:05d}.jpg", quality=92)
                frame_index += 1
        dest.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            "ffmpeg", "-y", "-framerate", str(fps), "-i", str(frames_dir / "frame_%05d.jpg"),
            "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
            "-vf", "format=yuv420p", "-c:v", "libx264", "-preset", "medium", "-crf", "30",
            "-pix_fmt", "yuv420p", "-profile:v", "high",
            "-color_range", "tv", "-c:a", "aac", "-b:a", "128k", "-shortest",
            "-movflags", "+faststart", str(dest)
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> None:
    reset_output()

    phone = [
        Shot("Browse living internet history", "Explore Gopher spaces with a modern Apple-native browser.", SRC / "ios/30-staged-crt-fun-directory.png"),
        Shot("CRT mode that feels right", "Amber phosphor, scanlines, and dark mode for archive browsing.", SRC / "ios/31-staged-crt-latest-feeds.png"),
        Shot("Liquid Glass when you want it", "A crisp modern interface for directories, text, and search.", SRC / "ios/32-staged-liquid-gopher-guide.png", False),
        Shot("Bookmarks and history stay close", "Save favorite hosts and jump back into recent sessions.", SRC / "ios/06b-bookmarks-history.png", False),
        Shot("Simple controls, real Gopher", "Set privacy, color, CRT mode, and sharing from one native app.", SRC / "ios/08-settings.png", False),
    ]
    ipad = [
        Shot("A full-size Gopher terminal", "Large-screen browsing for directories, feeds, and text archives.", SRC / "ipad/10-staged-crt-fun-directory.png"),
        Shot("Latest feeds, native lists", "Follow updated Gopher sources with readable Apple-platform controls.", SRC / "ipad/11-staged-crt-latest-feeds.png"),
        Shot("Liquid Glass on iPad", "Comfortable navigation for deep menus and long documents.", SRC / "ipad/12-staged-liquid-gopher-guide.png", False),
        Shot("Classic pages, modern layout", "A clean reader for Gopher guides, manifestos, and documents.", SRC / "ipad/01-artwork-gopher-guide-light.png", False),
        Shot("Dark mode brings it alive", "CRT styling makes ASCII art and old web culture feel tactile.", SRC / "ipad/03-artwork-fun-directory-dark.png"),
    ]
    mac = [
        Shot("Desktop Gopher, rebuilt", "Use a focused native window for directories, hosts, and long sessions.", SRC / "macos/10-staged-crt-fun-directory-window.png"),
        Shot("Feeds with room to scan", "Follow old-school news sources in a modern macOS split view.", SRC / "macos/11-staged-crt-latest-feeds-window.png"),
        Shot("A quiet archive workspace", "Dark CRT mode keeps text-heavy browsing calm and readable.", SRC / "macos/10-staged-crt-fun-directory-window.png"),
    ]
    vision = [
        Shot("Gopher in your space", "Browse internet history in a spatial window with dark CRT styling.", SRC / "visionos/17-staged-crt-fun-directory.png"),
        Shot("Feeds floating in the room", "Vision Pro gives Gopher directories room to breathe.", SRC / "visionos/18-staged-crt-latest-feeds.png"),
    ]

    for index, shot in enumerate(phone, 1):
        make_phone(shot, OUT / "screenshots/en-US/iphone-65" / f"{index:02d}.png")
        make_phone(shot, OUT / "screenshots/en-US/iphone-67" / f"{index:02d}.png", (1320, 2868))
        make_phone(shot, OUT / "screenshots/en-US/iphone-55" / f"{index:02d}.png", (1242, 2208))
    for index, shot in enumerate(ipad, 1):
        make_ipad(shot, OUT / "screenshots/en-US/ipad-pro-129" / f"{index:02d}.png")
        make_ipad(shot, OUT / "screenshots/en-US/ipad-pro-129-legacy" / f"{index:02d}.png")
    for index, shot in enumerate(mac, 1):
        make_landscape(shot, OUT / "screenshots/en-US/macos" / f"{index:02d}.png", (2880, 1800), (1040, 170, 1700, 1290))
    for index, shot in enumerate(vision, 1):
        make_landscape(shot, OUT / "screenshots/en-US/visionos" / f"{index:02d}.png", (3840, 2160), (1360, 205, 2220, 1250))

    make_preview(
        [OUT / "screenshots/en-US/iphone-65" / f"{i:02d}.png" for i in range(1, 6)],
        OUT / "previews/en-US/iphone-65/01-preview.mov",
        (1242, 2688),
    )
    make_preview(
        [OUT / "screenshots/en-US/ipad-pro-129" / f"{i:02d}.png" for i in range(1, 6)],
        OUT / "previews/en-US/ipad-pro-129/01-preview.mov",
        (2064, 2752),
    )
    make_preview(
        [OUT / "screenshots/en-US/macos" / f"{i:02d}.png" for i in range(1, 4)],
        OUT / "previews/en-US/macos/01-preview.mov",
        (2880, 1800),
    )
    make_preview(
        [OUT / "screenshots/en-US/visionos" / f"{i:02d}.png" for i in range(1, 3)],
        OUT / "previews/en-US/visionos/01-preview.mov",
        (3840, 2160),
    )
    write_readme()


if __name__ == "__main__":
    main()
