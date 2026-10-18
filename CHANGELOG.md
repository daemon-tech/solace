# Changelog – Solace Shaders

Iris shaderpack for Minecraft 26.3 (tested with Iris 1.11.7, Sodium 0.9.2). All Rights Reserved.
All builds tested in the real client with screenshots.

## 0.19-dev – 2026-10-18 (prerelease)
Water closer to the target look.
- Cloud reflections: the water mirror now reflects the soft clouds (same sky-plane mapping as the sky pass), not only the sky gradient.
- Foam: brighter flowing streak foam on the wave crests, thinner but still present on the far sea (no longer fades out at distance); shore foam sheets slightly brighter.
- Colour gradient: deeper, richer end of the shallow-to-deep gradient (near-white shallows -> turquoise -> deep blue-teal).
- Night: stronger two-step moonlit ripples on night water.
- Flowing water: falls and slopes get white streaks running downhill; no depth darkening or deep patches on falling water.
- Rain: expanding ripple rings on the water surface while it rains (near range, fade with distance).
- Settings unchanged: outlines and cel bands untouched; all existing sliders and toggles kept.
- QA: no NaN/black/magenta pixels in ocean, river, lake, night, rain and waterfall captures; sunrise, noon, sunset, night, forest, swamp and snowy re-checked.
- Known: rain rings are subtle at a distance; swamp sky above the horizon still slightly pale.

## 0.18-dev – 2026-10-18 (prerelease)
Water closer to the target look, horizon haze, night water.
- Flowing streak foam: bright foam lines ride the wave crests (same phase as the surface waves) and move with them; broken up by rotated noise so no grid-aligned cuts.
- Foam sheets now only along shores: open lakes seen from above no longer get pale patches.
- Near-white haze where the sea meets the sky (far water + sky just above the horizon); new **Horizon Haze** slider (0 / 0.5 / 1 / 1.5), weaker at night and in rain.
- Night water: banded moon glint path, moonlit ripple highlights, wave crests stay visible at night.
- Shoreline: crisp white edge line plus soft rim kept.
- QA: no NaN/black/magenta pixels in ocean, river, lake and night captures; no reflection or stream artifacts seen; composite pass additionally compiled on a real Mesa driver before in-client test.
- Known: night ripples still subtle; foam brightness at distance fades out by design.

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

## 0.16-dev – 2026-10-18
Atmosphere and time of day.
- Time-of-day sky: rose/peach sunrise distinct from golden sunset, stronger sun-side glow, belt of Venus, night horizon glow.
- Biome fog matched to the sky colour; morning ground mist and swamp mist.
- Hazier swamp, dark forest and snowy biomes.
- Clearer water with distant sky reflection, surf wash at the shore.
- New sliders for the above in the shader settings.

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
- QA: no NaN/black pixels, no z-fighting, no flicker, transparency sorting OK; reload done via K toggle (Iris R key did not reload).

## 0.14 – 2026-10-18
- Brighter, less saturated grass with texture detail restored.
- Water deep patches and more glints.
- All Rights Reserved licence and terms; title "Solace Shaders", slug `solace-shaders`.
- Icon from an in-game vanilla shot; build includes `pack.png`.

## 0.13 – 2026-10-18
- Name: Solace.
- Teal water depths, turquoise water, less fog/haze over water, localized highlights.
- Grass hue ~114 with more structure; grass/leaf low-pass smoothing; fuller foliage and canopy glow; leaf litter hidden; saturation 1.2.
