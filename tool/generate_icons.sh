#!/bin/bash
# FANZONE — Master icon/asset generation from official logos
# Uses macOS sips for lossless PNG resizing (no extra deps)
set -euo pipefail

LOGO_TRANSPARENT="$HOME/Downloads/Logo.FANZONE.png"
LOGO_BACK="$HOME/Downloads/Logo.FANZONE>BACK.png"

PROJECT="/Volumes/PRO-G40/FANZONE"

# Helper: resize a source file to WxH and write to dest
resize() {
  local src="$1" w="$2" h="$3" dest="$4"
  cp "$src" "$dest"
  sips -z "$h" "$w" "$dest" --out "$dest" >/dev/null 2>&1
  echo "  ✓ ${dest##*/} (${w}x${h})"
}

echo "═══════════════════════════════════════════════"
echo " FANZONE Logo Asset Generator"
echo "═══════════════════════════════════════════════"

# ─── 1. Android Launcher Icons (with background) ──────────────
echo ""
echo "▸ Android Launcher Icons (ic_launcher.png)"
ANDROID_RES="$PROJECT/android/app/src/main/res"
resize "$LOGO_BACK"  48  48 "$ANDROID_RES/mipmap-mdpi/ic_launcher.png"
resize "$LOGO_BACK"  72  72 "$ANDROID_RES/mipmap-hdpi/ic_launcher.png"
resize "$LOGO_BACK"  96  96 "$ANDROID_RES/mipmap-xhdpi/ic_launcher.png"
resize "$LOGO_BACK" 144 144 "$ANDROID_RES/mipmap-xxhdpi/ic_launcher.png"
resize "$LOGO_BACK" 192 192 "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher.png"

# ─── 2. Android Adaptive Icon Foreground ──────────────────────
echo ""
echo "▸ Android Adaptive Icon Foreground"
mkdir -p "$ANDROID_RES/mipmap-mdpi" "$ANDROID_RES/mipmap-hdpi" "$ANDROID_RES/mipmap-xhdpi" "$ANDROID_RES/mipmap-xxhdpi" "$ANDROID_RES/mipmap-xxxhdpi"
resize "$LOGO_TRANSPARENT" 108 108 "$ANDROID_RES/mipmap-mdpi/ic_launcher_foreground.png"
resize "$LOGO_TRANSPARENT" 162 162 "$ANDROID_RES/mipmap-hdpi/ic_launcher_foreground.png"
resize "$LOGO_TRANSPARENT" 216 216 "$ANDROID_RES/mipmap-xhdpi/ic_launcher_foreground.png"
resize "$LOGO_TRANSPARENT" 324 324 "$ANDROID_RES/mipmap-xxhdpi/ic_launcher_foreground.png"
resize "$LOGO_TRANSPARENT" 432 432 "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher_foreground.png"

# ─── 3. Google Play Store Icon ────────────────────────────────
echo ""
echo "▸ Google Play Store Icon (512x512)"
mkdir -p "$PROJECT/android/app/src/main/play_store"
resize "$LOGO_BACK" 512 512 "$PROJECT/android/app/src/main/play_store/play_store_512.png"

# ─── 4. Android Splash / Launch Image ─────────────────────────
echo ""
echo "▸ Android Launch Images"
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  mkdir -p "$ANDROID_RES/mipmap-${density}"
done
resize "$LOGO_TRANSPARENT" 128 128 "$ANDROID_RES/mipmap-mdpi/launch_image.png"
resize "$LOGO_TRANSPARENT" 192 192 "$ANDROID_RES/mipmap-hdpi/launch_image.png"
resize "$LOGO_TRANSPARENT" 256 256 "$ANDROID_RES/mipmap-xhdpi/launch_image.png"
resize "$LOGO_TRANSPARENT" 384 384 "$ANDROID_RES/mipmap-xxhdpi/launch_image.png"
resize "$LOGO_TRANSPARENT" 512 512 "$ANDROID_RES/mipmap-xxxhdpi/launch_image.png"

# ─── 5. iOS App Icons (must be opaque → use BACK version) ─────
echo ""
echo "▸ iOS App Icons"
IOS_ICONS="$PROJECT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
resize "$LOGO_BACK"   20   20 "$IOS_ICONS/Icon-App-20x20@1x.png"
resize "$LOGO_BACK"   40   40 "$IOS_ICONS/Icon-App-20x20@2x.png"
resize "$LOGO_BACK"   60   60 "$IOS_ICONS/Icon-App-20x20@3x.png"
resize "$LOGO_BACK"   29   29 "$IOS_ICONS/Icon-App-29x29@1x.png"
resize "$LOGO_BACK"   58   58 "$IOS_ICONS/Icon-App-29x29@2x.png"
resize "$LOGO_BACK"   87   87 "$IOS_ICONS/Icon-App-29x29@3x.png"
resize "$LOGO_BACK"   40   40 "$IOS_ICONS/Icon-App-40x40@1x.png"
resize "$LOGO_BACK"   80   80 "$IOS_ICONS/Icon-App-40x40@2x.png"
resize "$LOGO_BACK"  120  120 "$IOS_ICONS/Icon-App-40x40@3x.png"
resize "$LOGO_BACK"  120  120 "$IOS_ICONS/Icon-App-60x60@2x.png"
resize "$LOGO_BACK"  180  180 "$IOS_ICONS/Icon-App-60x60@3x.png"
resize "$LOGO_BACK"   76   76 "$IOS_ICONS/Icon-App-76x76@1x.png"
resize "$LOGO_BACK"  152  152 "$IOS_ICONS/Icon-App-76x76@2x.png"
resize "$LOGO_BACK"  167  167 "$IOS_ICONS/Icon-App-83.5x83.5@2x.png"
resize "$LOGO_BACK" 1024 1024 "$IOS_ICONS/Icon-App-1024x1024@1x.png"

# ─── 6. iOS Launch Images (transparent on white) ──────────────
echo ""
echo "▸ iOS Launch Images"
IOS_LAUNCH="$PROJECT/ios/Runner/Assets.xcassets/LaunchImage.imageset"
resize "$LOGO_TRANSPARENT" 192 192 "$IOS_LAUNCH/LaunchImage.png"
resize "$LOGO_TRANSPARENT" 384 384 "$IOS_LAUNCH/LaunchImage@2x.png"
resize "$LOGO_TRANSPARENT" 576 576 "$IOS_LAUNCH/LaunchImage@3x.png"

# ─── 7. Flutter In-App Assets ─────────────────────────────────
echo ""
echo "▸ Flutter In-App Assets"
mkdir -p "$PROJECT/assets/images"
cp "$LOGO_TRANSPARENT" "$PROJECT/assets/images/logo.png"
echo "  ✓ logo.png (1024x1024 original)"
cp "$LOGO_BACK" "$PROJECT/assets/images/logo_bg.png"
echo "  ✓ logo_bg.png (1024x1024 original)"
resize "$LOGO_TRANSPARENT" 256 256 "$PROJECT/assets/images/logo_256.png"
resize "$LOGO_TRANSPARENT" 128 128 "$PROJECT/assets/images/logo_128.png"

# ─── 8. Admin Panel Assets ────────────────────────────────────
echo ""
echo "▸ Admin Panel Assets (Vite/React)"
ADMIN_PUBLIC="$PROJECT/admin/public"
ADMIN_SRC_ASSETS="$PROJECT/admin/src/assets"
mkdir -p "$ADMIN_PUBLIC" "$ADMIN_SRC_ASSETS"

# Favicon (32x32 PNG)
resize "$LOGO_BACK" 32 32 "$ADMIN_PUBLIC/favicon.png"

# Apple touch icon (180x180)
resize "$LOGO_BACK" 180 180 "$ADMIN_PUBLIC/apple-touch-icon.png"

# PWA manifest icons
resize "$LOGO_BACK" 192 192 "$ADMIN_PUBLIC/logo-192.png"
resize "$LOGO_BACK" 512 512 "$ADMIN_PUBLIC/logo-512.png"

# In-app logo for sidebar/login (transparent)
cp "$LOGO_TRANSPARENT" "$ADMIN_SRC_ASSETS/logo.png"
echo "  ✓ logo.png (src asset, 1024x1024)"
resize "$LOGO_TRANSPARENT" 64 64 "$ADMIN_SRC_ASSETS/logo-64.png"
resize "$LOGO_TRANSPARENT" 128 128 "$ADMIN_SRC_ASSETS/logo-128.png"

echo ""
echo "═══════════════════════════════════════════════"
echo " ✅ All FANZONE logo assets generated!"
echo "═══════════════════════════════════════════════"
