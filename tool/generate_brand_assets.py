from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
LIGHT_SOURCE = REPO_ROOT / "assets/images/logo.png"
DARK_SOURCE = REPO_ROOT / "assets/images/logo_bg.png"
INVENTORY_PATH = REPO_ROOT / "assets/brand/asset_inventory.json"

APP_DARK_BG = (12, 10, 9, 255)
ADAPTIVE_BG_HEX = "#3A393B"


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def load_sources() -> tuple[Image.Image, Image.Image]:
    light = Image.open(LIGHT_SOURCE).convert("RGBA")
    dark = Image.open(DARK_SOURCE).convert("RGBA")
    return light, dark


def derive_transparent_mark(light: Image.Image, dark: Image.Image) -> Image.Image:
    mark = light.copy()
    mark.putalpha(dark.getchannel("A"))
    return mark


def derive_opaque_from_rgba(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    red, green, blue, _ = rgba.split()
    return Image.merge("RGB", (red, green, blue))


def resized(image: Image.Image, size: int | tuple[int, int]) -> Image.Image:
    if isinstance(size, int):
        size = (size, size)
    return image.resize(size, Image.Resampling.LANCZOS)


def save_png(
    image: Image.Image,
    path: Path,
    inventory: list[dict[str, object]],
    *,
    group: str,
    source_variant: str,
    usage: str,
) -> None:
    ensure_parent(path)
    image.save(path, format="PNG")
    inventory.append(
        {
            "group": group,
            "path": path.relative_to(REPO_ROOT).as_posix(),
            "format": "png",
            "width": image.width,
            "height": image.height,
            "source_variant": source_variant,
            "usage": usage,
        }
    )


def save_ico(
    image: Image.Image,
    path: Path,
    inventory: list[dict[str, object]],
    *,
    sizes: Iterable[int],
    group: str,
    source_variant: str,
    usage: str,
) -> None:
    ensure_parent(path)
    ico_sizes = [(size, size) for size in sizes]
    image.save(path, format="ICO", sizes=ico_sizes)
    inventory.append(
        {
            "group": group,
            "path": path.relative_to(REPO_ROOT).as_posix(),
            "format": "ico",
            "sizes": list(sizes),
            "source_variant": source_variant,
            "usage": usage,
        }
    )


def social_preview(mark: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (1200, 630), APP_DARK_BG)
    scaled = resized(mark, 420)
    x = (canvas.width - scaled.width) // 2
    y = (canvas.height - scaled.height) // 2
    canvas.alpha_composite(scaled, (x, y))
    return canvas.convert("RGB")


def build_assets() -> dict[str, object]:
    light_source, dark_source = load_sources()
    transparent_mark = derive_transparent_mark(light_source, dark_source)
    square_dark = derive_opaque_from_rgba(dark_source)
    square_light = derive_opaque_from_rgba(light_source)

    inventory: list[dict[str, object]] = []

    # Shared masters for Flutter/runtime use.
    shared_specs = [
        (
            REPO_ROOT / "assets/images/brand/logo-mark.png",
            transparent_mark,
            "flutter_shared",
            "light_source_rgb + dark_source_alpha",
            "primary transparent brand mark",
        ),
        (
            REPO_ROOT / "assets/images/brand/logo-mark-512.png",
            resized(transparent_mark, 512),
            "flutter_shared",
            "light_source_rgb + dark_source_alpha",
            "retina transparent brand mark",
        ),
        (
            REPO_ROOT / "assets/images/brand/logo-mark-256.png",
            resized(transparent_mark, 256),
            "flutter_shared",
            "light_source_rgb + dark_source_alpha",
            "compact transparent brand mark",
        ),
        (
            REPO_ROOT / "assets/images/brand/logo-mark-128.png",
            resized(transparent_mark, 128),
            "flutter_shared",
            "light_source_rgb + dark_source_alpha",
            "small transparent brand mark",
        ),
        (
            REPO_ROOT / "assets/images/brand/logo-square-dark.png",
            square_dark,
            "flutter_shared",
            "dark_source_rgb",
            "opaque square icon master",
        ),
        (
            REPO_ROOT / "assets/images/brand/logo-square-light.png",
            square_light,
            "flutter_shared",
            "light_source_rgb",
            "opaque light square reference",
        ),
        (
            REPO_ROOT / "assets/images/brand/splash-logo.png",
            resized(transparent_mark, 512),
            "flutter_shared",
            "light_source_rgb + dark_source_alpha",
            "native splash mark",
        ),
        (
            REPO_ROOT / "assets/images/logo_128.png",
            resized(transparent_mark, 128),
            "flutter_shared_legacy",
            "light_source_rgb + dark_source_alpha",
            "legacy transparent logo alias",
        ),
        (
            REPO_ROOT / "assets/images/logo_256.png",
            resized(transparent_mark, 256),
            "flutter_shared_legacy",
            "light_source_rgb + dark_source_alpha",
            "legacy transparent logo alias",
        ),
    ]
    for path, image, group, source_variant, usage in shared_specs:
        save_png(
            image,
            path,
            inventory,
            group=group,
            source_variant=source_variant,
            usage=usage,
        )

    # Android legacy launcher icons.
    launcher_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in launcher_sizes.items():
        save_png(
            resized(square_dark, size),
            REPO_ROOT
            / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png",
            inventory,
            group="android_launcher",
            source_variant="dark_source_rgb",
            usage=f"android legacy launcher icon ({density})",
        )

    # Android adaptive icon foregrounds keep the backed square mark for fidelity.
    adaptive_sizes = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }
    for density, size in adaptive_sizes.items():
        save_png(
            resized(square_dark, size),
            REPO_ROOT
            / f"android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png",
            inventory,
            group="android_adaptive",
            source_variant="dark_source_rgb",
            usage=f"android adaptive icon foreground ({density})",
        )

    # Native launch images use the transparent mark because the screen controls background.
    launch_sizes = {
        "mdpi": 128,
        "hdpi": 192,
        "xhdpi": 256,
        "xxhdpi": 384,
        "xxxhdpi": 512,
    }
    for density, size in launch_sizes.items():
        save_png(
            resized(transparent_mark, size),
            REPO_ROOT
            / f"android/app/src/main/res/mipmap-{density}/launch_image.png",
            inventory,
            group="android_splash",
            source_variant="light_source_rgb + dark_source_alpha",
            usage=f"android native splash mark ({density})",
        )

    # iOS app icon set.
    ios_specs = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for filename, size in ios_specs.items():
        save_png(
            resized(square_dark, size),
            REPO_ROOT
            / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
            / filename,
            inventory,
            group="ios_app_icon",
            source_variant="dark_source_rgb",
            usage=f"ios app icon slot {filename}",
        )

    for filename, size in {
        "LaunchImage.png": 192,
        "LaunchImage@2x.png": 384,
        "LaunchImage@3x.png": 576,
    }.items():
        save_png(
            resized(transparent_mark, size),
            REPO_ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset" / filename,
            inventory,
            group="ios_splash",
            source_variant="light_source_rgb + dark_source_alpha",
            usage=f"ios launch image {filename}",
        )

    # Website icons and logo assets.
    website_specs = [
        ("website/public/favicon.png", resized(square_dark, 64), "website_icon", "dark_source_rgb", "legacy favicon png"),
        ("website/public/favicon-16.png", resized(square_dark, 16), "website_icon_legacy", "dark_source_rgb", "legacy favicon 16"),
        ("website/public/favicon-16x16.png", resized(square_dark, 16), "website_icon", "dark_source_rgb", "favicon 16x16"),
        ("website/public/favicon-32x32.png", resized(square_dark, 32), "website_icon", "dark_source_rgb", "favicon 32x32"),
        ("website/public/apple-touch-icon.png", resized(square_dark, 180), "website_icon", "dark_source_rgb", "apple touch icon"),
        ("website/public/icon-192.png", resized(square_dark, 192), "website_icon", "dark_source_rgb", "web app icon 192"),
        ("website/public/icon-512.png", resized(square_dark, 512), "website_icon", "dark_source_rgb", "web app icon 512"),
        ("website/public/logo-128.png", resized(transparent_mark, 128), "website_brand_legacy", "light_source_rgb + dark_source_alpha", "legacy website logo alias"),
        ("website/public/logo-192.png", resized(square_dark, 192), "website_brand_legacy", "dark_source_rgb", "legacy website icon alias"),
        ("website/public/logo-512.png", resized(square_dark, 512), "website_brand_legacy", "dark_source_rgb", "legacy website icon alias"),
        ("website/public/logo.png", resized(transparent_mark, 512), "website_brand_legacy", "light_source_rgb + dark_source_alpha", "legacy website logo alias"),
        ("website/public/og-image.png", social_preview(transparent_mark), "website_social_legacy", "light_source_rgb + dark_source_alpha", "legacy social preview alias"),
        ("website/public/brand/logo-mark-128.png", resized(transparent_mark, 128), "website_brand", "light_source_rgb + dark_source_alpha", "small transparent website mark"),
        ("website/public/brand/logo-mark-256.png", resized(transparent_mark, 256), "website_brand", "light_source_rgb + dark_source_alpha", "retina transparent website mark"),
        ("website/public/brand/logo-mark-512.png", resized(transparent_mark, 512), "website_brand", "light_source_rgb + dark_source_alpha", "large transparent website mark"),
        ("website/public/social-preview.png", social_preview(transparent_mark), "website_social", "light_source_rgb + dark_source_alpha", "social preview image"),
    ]
    for raw_path, image, group, source_variant, usage in website_specs:
        save_png(
            image,
            REPO_ROOT / raw_path,
            inventory,
            group=group,
            source_variant=source_variant,
            usage=usage,
        )
    save_ico(
        square_dark,
        REPO_ROOT / "website/public/favicon.ico",
        inventory,
        sizes=[16, 32, 48],
        group="website_icon",
        source_variant="dark_source_rgb",
        usage="multi-size favicon",
    )

    # Admin icons and transparent logos.
    admin_specs = [
        ("admin/public/favicon.png", resized(square_dark, 64), "admin_icon", "dark_source_rgb", "legacy admin favicon png"),
        ("admin/public/favicon-16x16.png", resized(square_dark, 16), "admin_icon", "dark_source_rgb", "admin favicon 16x16"),
        ("admin/public/favicon-32x32.png", resized(square_dark, 32), "admin_icon", "dark_source_rgb", "admin favicon 32x32"),
        ("admin/public/apple-touch-icon.png", resized(square_dark, 180), "admin_icon", "dark_source_rgb", "admin apple touch icon"),
        ("admin/public/icon-192.png", resized(square_dark, 192), "admin_icon", "dark_source_rgb", "admin web icon 192"),
        ("admin/public/icon-512.png", resized(square_dark, 512), "admin_icon", "dark_source_rgb", "admin web icon 512"),
        ("admin/public/logo-192.png", resized(square_dark, 192), "admin_icon_legacy", "dark_source_rgb", "legacy admin icon alias"),
        ("admin/public/logo-512.png", resized(square_dark, 512), "admin_icon_legacy", "dark_source_rgb", "legacy admin icon alias"),
        ("admin/public/brand/logo-mark-64.png", resized(transparent_mark, 64), "admin_brand", "light_source_rgb + dark_source_alpha", "sidebar transparent brand mark"),
        ("admin/public/brand/logo-mark-128.png", resized(transparent_mark, 128), "admin_brand", "light_source_rgb + dark_source_alpha", "login transparent brand mark"),
        ("admin/public/brand/logo-mark-256.png", resized(transparent_mark, 256), "admin_brand", "light_source_rgb + dark_source_alpha", "retina admin brand mark"),
        ("admin/public/brand/logo-mark-512.png", resized(transparent_mark, 512), "admin_brand", "light_source_rgb + dark_source_alpha", "large admin brand mark"),
        ("admin/src/assets/logo.png", resized(transparent_mark, 512), "admin_brand_legacy", "light_source_rgb + dark_source_alpha", "legacy admin import logo alias"),
        ("admin/src/assets/logo-64.png", resized(transparent_mark, 64), "admin_brand_legacy", "light_source_rgb + dark_source_alpha", "legacy admin import logo alias"),
        ("admin/src/assets/logo-128.png", resized(transparent_mark, 128), "admin_brand_legacy", "light_source_rgb + dark_source_alpha", "legacy admin import logo alias"),
    ]
    for raw_path, image, group, source_variant, usage in admin_specs:
        save_png(
            image,
            REPO_ROOT / raw_path,
            inventory,
            group=group,
            source_variant=source_variant,
            usage=usage,
        )
    save_ico(
        square_dark,
        REPO_ROOT / "admin/public/favicon.ico",
        inventory,
        sizes=[16, 32, 48],
        group="admin_icon",
        source_variant="dark_source_rgb",
        usage="multi-size admin favicon",
    )

    inventory_payload = {
        "sources": {
            "light_source": LIGHT_SOURCE.relative_to(REPO_ROOT).as_posix(),
            "dark_source": DARK_SOURCE.relative_to(REPO_ROOT).as_posix(),
        },
        "derived_masters": {
            "transparent_mark": "assets/images/brand/logo-mark.png",
            "square_dark": "assets/images/brand/logo-square-dark.png",
            "square_light": "assets/images/brand/logo-square-light.png",
        },
        "android_adaptive_background_hex": ADAPTIVE_BG_HEX,
        "assets": inventory,
    }

    ensure_parent(INVENTORY_PATH)
    INVENTORY_PATH.write_text(
        json.dumps(inventory_payload, indent=2) + "\n",
        encoding="utf-8",
    )
    return inventory_payload


if __name__ == "__main__":
    payload = build_assets()
    print(
        json.dumps(
            {
                "generated": len(payload["assets"]),
                "inventory": INVENTORY_PATH.relative_to(REPO_ROOT).as_posix(),
            },
            indent=2,
        )
    )
