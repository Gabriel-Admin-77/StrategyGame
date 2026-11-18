# StrategyGame — Art Bible

## Direction

Full-colour **painterly / storybook** strategy art. Think gouache and watercolour
washes on textured paper: visible brush direction, layered translucent shapes,
soft edges, warm light. Not pixel art, not flat vector, no heavy black outlines.

- Mood: inviting, readable, slightly rustic frontier fantasy.
- Readability first: a player must identify terrain at a glance at 0.6× zoom.
- Every terrain must be distinguishable **without relying on hue alone**
  (shape, texture and pattern carry the identity too).

## Lighting

- Key light from the **upper left**, cool shadows to the **lower right**.
- Highlight edges facing upper-left; deepen lower-right edges.
- Soft ambient bounce, low contrast between neighbouring tiles so the grid
  reads as one continuous landscape rather than a quilt.

## Terrain treatments

| Terrain | Palette | Brush treatment | Non-colour cue |
|---|---|---|---|
| Plains | `#8fbf5a` → `#5f9440`, ochre `#c9a94e` | Short grass strokes, warm patches | grass blades, small flowers |
| Forest | `#2f6b3a` → `#173f28`, moss `#6f9e4a` | Layered canopy blobs, deep shadow pockets | clustered tree crowns, trunks |
| Water | `#3f86b8` → `#1d4f78`, foam `#cfe8ef` | Horizontal washes, curved highlights | wave strokes, foam edges |
| Mountain | `#8a7358` → `#4d3f31`, stone `#b9a98c` | Angular facets, dry-brush speckle | rock facets, ridge lines |

## Dimensions

| Asset | Source size | Displayed |
|---|---|---|
| Terrain tile | 128 × 128 | 64 × 64 logical tile |
| Building | 192 × 192 (transparent) | centred in one 64 px tile, overhanging upward |
| UI icon | 64 × 64 | 24–32 px |
| Decoration | 32–64 px | 8–24 px |

## Import rules

- World textures: linear filtering **with mipmaps** (painterly art must not
  shimmer when zoomed out). Never nearest-neighbour.
- UI icons: linear filtering, mipmaps optional.
- Atlases: minimum 4 px padding to prevent edge bleed at lower mip levels.
- Keep `art_source/` (Aseprite/Krita/SVG sources) out of exported builds.

## Naming

```
assets/sprites/terrain/terrain_<type>_v<variant>.png|svg
assets/sprites/buildings/building_<id>_lv<level>.png|svg
assets/sprites/ui/icon_<name>.png|svg
assets/sprites/fx/fx_<effect>.png|svg
```

## UI style

- Panels: warm parchment (`#e6d3ae`) with dark walnut borders (`#4a3524`).
- Secondary surfaces: deep forest / muted navy (`#2c3a34`, `#2b3444`).
- Accent: antique gold (`#d8b25a`) for selection, focus and primary actions.
- Body text near-black brown (`#2a2119`) on parchment; cream (`#f3e8d2`) on dark.
- Buttons: raised parchment with 1–2 px walnut border, gold glow on hover,
  pressed state inset by 1 px with darker fill, disabled desaturated.
- Icons replace emoji everywhere; emoji glyph rendering is inconsistent
  across platforms and cannot be tinted reliably.

## Implementation notes

- Painterly textures are drawn by `TerrainRenderer` / `BuildingView`; layout and
  gameplay coordinates stay on the 64 px logical grid.
- A procedural `--low-gfx` renderer remains available for headless tests and
  low-end hardware; it must never depend on art files.
- New assets are logged in `assets/ATTRIBUTION.md` with source and licence.
