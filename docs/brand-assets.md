# FANZONE Brand Assets

Canonical generated inventory: [assets/brand/asset_inventory.json](/Volumes/PRO-G40/FANZONE/assets/brand/asset_inventory.json)

## Source of truth

- `assets/images/logo.png`
  Use as the light square master source.
- `assets/images/logo_bg.png`
  Use as the dark backed master source and alpha mask source.

## Derived masters

- `assets/images/brand/logo-mark.png`
  1024x1024 transparent primary mark.
  Derived from `logo.png` RGB plus `logo_bg.png` alpha so the mark stays faithful without repainting the logo.
- `assets/images/brand/logo-square-dark.png`
  1024x1024 opaque backed icon master.
  Derived from `logo_bg.png` RGB with alpha removed so icon surfaces match the provided dark backed artwork.
- `assets/images/brand/logo-square-light.png`
  1024x1024 opaque light square reference.

## Naming convention

- `logo-mark-*`
  Transparent brand mark for headers, auth screens, in-app brand placements, and admin chrome.
- `logo-square-*`
  Opaque square icon master for launcher icons, iOS icons, favicons, PWA icons, and other pinned icon surfaces.
- Platform-native filenames
  Keep Apple and Android naming exactly as the platform expects, for example `Icon-App-60x60@3x.png`, `ic_launcher.png`, and `favicon-32x32.png`.

## Generated groups

- Android launcher icons
  `48`, `72`, `96`, `144`, `192`
- Android adaptive icon foregrounds
  `108`, `162`, `216`, `324`, `432`
- Android native splash marks
  `128`, `192`, `256`, `384`, `512`
- iOS app icon set
  `20`, `29`, `40`, `58`, `60`, `76`, `80`, `87`, `120`, `152`, `167`, `180`, `1024`
- iOS launch images
  `192`, `384`, `576`
- Website favicon and PWA icons
  `16`, `32`, `48`, `64`, `180`, `192`, `512`
- Website transparent brand marks
  `128`, `256`, `512`
- Website social preview
  `1200x630`
- Admin transparent brand marks
  `64`, `128`, `256`, `512`
- Legacy compatibility aliases
  `assets/images/logo_128.png`, `assets/images/logo_256.png`, `website/public/logo-128.png`, `website/public/logo.png`, `admin/public/logo-192.png`, `admin/public/logo-512.png`, `admin/src/assets/logo.png`, `admin/src/assets/logo-64.png`, `admin/src/assets/logo-128.png`

## Usage mapping

- Transparent/logo-only placements
  `assets/images/brand/logo-mark.png`
  `website/public/brand/logo-mark-*.png`
  `admin/public/brand/logo-mark-*.png`
- Backed square icon surfaces
  Android `mipmap-*/ic_launcher*.png`
  iOS `AppIcon.appiconset/*.png`
  website `favicon*.png`, `favicon.ico`, `icon-192.png`, `icon-512.png`, `apple-touch-icon.png`
  admin `favicon*.png`, `favicon.ico`, `icon-192.png`, `icon-512.png`, `apple-touch-icon.png`

## Implementation notes

- Flutter now resolves `FzBrandLogo` to `assets/images/brand/logo-mark.png`.
- Website navbar, footer, and 404 screen now use the transparent mark from `/brand/logo-mark-256.png`.
- Website metadata now includes `favicon.ico`, PNG favicon sizes, Apple touch icon, `site.webmanifest`, and `social-preview.png`.
- Admin sidebar and login now use the transparent mark from `/brand/logo-mark-64.png` and `/brand/logo-mark-128.png`.
- Android adaptive icon background color is set to `#3A393B`, sampled from the dark backed artwork.

## Remaining gaps

- No vector source was provided, so there is no SVG or PDF vector export in this set.
- The website and admin currently use PNG icon pipelines only, which is consistent with the provided source artwork.
