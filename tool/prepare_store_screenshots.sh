#!/bin/bash
# FANZONE — Google Play Store screenshot preparation
# Converts raw screenshots into Google Play required dimensions.
#
# Google Play requirements:
#   - Phone: min 320px, max 3840px, aspect ratio 16:9 or 9:16
#     Recommended: 1080×1920 (portrait) or 2160×3840 for hi-res
#   - 7-inch tablet: 1080×1920 recommended
#   - 10-inch tablet: 1200×1920 or 1920×1200 recommended
#   - Min 2, max 8 screenshots per device type
#   - PNG or JPEG, max 8MB each
#
# Strategy:
#   - Phone screens (~730×1320-1368): scale up to 1080×1920 canvas
#   - Wider screens (~1224-1264×1400-1408): scale to 1200×1920 for 10" tablet
#
set -euo pipefail

SRC="$HOME/Desktop/SCREENS.FANZONE"
PROJECT="/Volumes/PRO-G40/FANZONE"
OUT_PHONE="$PROJECT/android/app/src/main/play_store/phone"
OUT_TABLET7="$PROJECT/android/app/src/main/play_store/tablet_7"
OUT_TABLET10="$PROJECT/android/app/src/main/play_store/tablet_10"

mkdir -p "$OUT_PHONE" "$OUT_TABLET7" "$OUT_TABLET10"

echo "═══════════════════════════════════════════════"
echo " FANZONE Google Play Screenshot Preparation"
echo "═══════════════════════════════════════════════"
echo ""

# Classify screenshots by width
phone_idx=1
tablet_idx=1

for f in "$SRC"/*.png; do
  fname="$(basename "$f")"
  w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')

  if [ "$w" -lt 1000 ]; then
    # ── Phone screenshot ──
    # Fit into 1080×1920 canvas (9:16 ratio) with dark background
    # The image is centered on a dark (#0C0A09) background
    target="$OUT_PHONE/phone_$(printf '%02d' $phone_idx).png"

    # Step 1: Create a 1080x1920 dark background canvas
    sips -s format png --resampleWidth 1 --resampleHeight 1 "$f" --out /tmp/fz_canvas_base.png >/dev/null 2>&1 || true

    # Use Python for precise canvas compositing (sips can't do canvas extension)
    python3 -c "
from PIL import Image
img = Image.open('$f')
# Scale to fit width=1080, keep aspect
scale = 1080 / img.width
new_w = 1080
new_h = int(img.height * scale)
if new_h > 1920:
    scale = 1920 / img.height
    new_w = int(img.width * scale)
    new_h = 1920
resized = img.resize((new_w, new_h), Image.LANCZOS)
# Create dark canvas
canvas = Image.new('RGB', (1080, 1920), (12, 10, 9))
x = (1080 - new_w) // 2
y = (1920 - new_h) // 2
canvas.paste(resized, (x, y))
canvas.save('$target')
" 2>/dev/null

    if [ $? -eq 0 ]; then
      echo "  ✓ phone_$(printf '%02d' $phone_idx).png (1080×1920) ← $fname"
      phone_idx=$((phone_idx + 1))
    else
      echo "  ✗ FAILED: $fname (trying sips fallback)"
      # Fallback: simple resize to 1080 wide, pad manually isn't possible with sips
      cp "$f" "$target"
      sips -Z 1920 "$target" --out "$target" >/dev/null 2>&1
      echo "  ⚠ phone_$(printf '%02d' $phone_idx).png (resized, may not be exact 1080×1920) ← $fname"
      phone_idx=$((phone_idx + 1))
    fi
  else
    # ── Tablet screenshot ──
    # Fit into 1200×1920 canvas for 10" tablets
    target_10="$OUT_TABLET10/tablet10_$(printf '%02d' $tablet_idx).png"
    # Also create 7" tablet at 1080×1920
    target_7="$OUT_TABLET7/tablet7_$(printf '%02d' $tablet_idx).png"

    python3 -c "
from PIL import Image
img = Image.open('$f')

# 10-inch tablet: 1200×1920
scale = min(1200 / img.width, 1920 / img.height)
new_w = int(img.width * scale)
new_h = int(img.height * scale)
resized = img.resize((new_w, new_h), Image.LANCZOS)
canvas = Image.new('RGB', (1200, 1920), (12, 10, 9))
canvas.paste(resized, ((1200 - new_w) // 2, (1920 - new_h) // 2))
canvas.save('$target_10')

# 7-inch tablet: 1080×1920
scale = min(1080 / img.width, 1920 / img.height)
new_w = int(img.width * scale)
new_h = int(img.height * scale)
resized = img.resize((new_w, new_h), Image.LANCZOS)
canvas = Image.new('RGB', (1080, 1920), (12, 10, 9))
canvas.paste(resized, ((1080 - new_w) // 2, (1920 - new_h) // 2))
canvas.save('$target_7')
" 2>/dev/null

    if [ $? -eq 0 ]; then
      echo "  ✓ tablet10_$(printf '%02d' $tablet_idx).png (1200×1920) ← $fname"
      echo "  ✓ tablet7_$(printf '%02d' $tablet_idx).png (1080×1920) ← $fname"
      tablet_idx=$((tablet_idx + 1))
    else
      echo "  ✗ FAILED: $fname"
    fi
  fi
done

# ── Select best 8 for phone (Google Play max) ──
phone_count=$((phone_idx - 1))
tablet_count=$((tablet_idx - 1))

echo ""
echo "═══════════════════════════════════════════════"
echo " Results:"
echo "   Phone screenshots: $phone_count  → $OUT_PHONE"
echo "   7\" tablet:         $tablet_count  → $OUT_TABLET7"
echo "   10\" tablet:        $tablet_count  → $OUT_TABLET10"
echo ""
echo " Google Play limits: min 2, max 8 per device type"
if [ "$phone_count" -gt 8 ]; then
  echo " ⚠ You have $phone_count phone screenshots — select your best 8 for upload"
fi
echo "═══════════════════════════════════════════════"
