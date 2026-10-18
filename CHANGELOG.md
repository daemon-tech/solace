# Changelog – Solace Shaders

Iris shaderpack for Minecraft 26.3 (tested with Iris 1.11.7, Sodium 0.9.2). All Rights Reserved.
All builds tested in the real client with screenshots.

## 0.17-dev – 2026-10-18 (prerelease)
Water rework.
- Water colour: pale, clear turquoise instead of dark teal; near-white shallows at the shore.
- Foam: large soft streaky foam sheets plus whitecaps; new **Foam Sheets** slider.
- Bright horizon mirror: water brightens towards the horizon.
- Night water lifted (less black, keeps waves readable).
- Fixed: vanilla star quads visible at sunrise are now hidden (only sky-space stars remain).
- Fixed: foam artifact from 0.16-dev.
- Softer sun horizon glow (fixes the washed-out swamp sky), lighter swamp fog.
- Known: foam not yet as bright/flowing as targeted, horizon not yet near-white (planned for 0.18).
- Captures: `compare/v017` (sea, river, lake, night, sunrise, noon, sunset).

## 0.16-dev – 2026-10-18
Atmosphere and time of day.
- Time-of-day sky: rose/peach sunrise distinct from golden sunset, stronger sun-side glow, belt of Venus, night horizon glow.
- Biome fog matched to the sky colour; morning ground mist and swamp mist.
- Hazier swamp, dark forest and snowy biomes.
- Clearer water with distant sky reflection, surf wash at the shore.
- New sliders for the above in the shader settings.
- Captures: `compare/v016` (0.15 vs 0.16-dev pairs).

## 0.15 – 2026-10-18
Bug-fix and polish release (Modrinth draft basis).
- Stars fixed in sky space (no longer move with the camera).
- Softer, less orange torches: TORCH_STRENGTH 0.9, block light colour (1.0, 0.76, 0.50).
- Water: crest ribbons, foam, glints; deep patches softened (smaller, smooth edges, 0.24 darkening).
- Soft drifting clouds (vanilla clouds off).
- Waving foliage (toggle) and very subtle white light outlines (toggle).
- Biome-aware mood for colour, fog and water.
- Sunlit grass toned down: hue ~114–120, V ~0.72.
- Emissive blocks, Distant Horizons programs (only remove the "incompatible" message; DH still shows blue patches → Bobby recommended).
- `pack.png` included in the zip; new Monocraft-lettering icon (SIL OFL 1.1).
- Gallery `gallery/final` 1920×1080; QA scenes and cleanup functions (glass, torch, night).
- QA (`compare/v015/QA.md`): no NaN/black pixels, no z-fighting, no flicker, transparency sorting OK; reload done via K toggle (Iris R key did not reload).

## 0.14 – 2026-10-18
- Brighter, less saturated grass with texture detail restored.
- Water deep patches and more glints.
- All Rights Reserved licence and terms; title "Solace Shaders", slug `solace-shaders`.
- Icon from an in-game vanilla shot; build includes `pack.png`.

## 0.13 – 2026-10-18
- Name: Solace.
- Teal water depths, turquoise water, less fog/haze over water, localized highlights.
- Grass hue ~114 with more structure; grass/leaf low-pass smoothing; fuller foliage and canopy glow; leaf litter hidden; saturation 1.2.
