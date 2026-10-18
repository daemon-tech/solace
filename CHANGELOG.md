# Changelog – Solace Shaders

Iris shaderpack for Minecraft 26.3 (tested with Iris 1.11.7, Sodium 0.9.2). All Rights Reserved.
All builds tested in the real client with screenshots.

## 0.22-dev – 2026-10-18 (prerelease)
Sign-off release for light, atmosphere, weather and foliage. Outlines and cel bands unchanged.

**Light and atmosphere**
- Sky bands now have soft edges; at night they blend almost fully, so no hard rings around the zenith.
- Milky Way is wider and breaks up into dust lanes and star clumps instead of a straight beam.
- Splash mist, smoke and other pale particles stay neutral white instead of turning beige over sand.
- Checked: forest god rays and sun halo, blue distance haze, ambient occlusion, bloom, cloud shadows, lantern and torch glow, time-of-day grading (sunrise, noon, golden hour, blue hour, night), biome skies and fog, sunset sky and sun disk, night sky, cubic clouds.

**Weather**
- Rain and snow have their own pass: soft, slightly cool streaks that no longer disturb the water below (before, every raindrop over water left a foam ring and the sea looked shredded).
- Wet ground now also works on grass: lawns turn darker and glossier in the rain, with soft puddle sheen on open flat ground, and dry out again afterwards.
- Checked: rain streaks, rain fog, darker blue mood for night rain, sandstorm in deserts, white snow haze.

**Foliage**
- Checked: lush grass with yellow-green sunlit tips and cool shade, grass, flowers and leaves swaying with the wind gusts, bright sunlit leaf edges, backlit leaf translucency, faint flower glow at night.

**Testing**
- Tested in the client with connected grass: rain over land, water and at night, wet vs. dry ground, desert sandstorm, snowfall, meadow at noon, golden hour and night, sway over time, sunrise through a grove, plus all light and atmosphere scenes. No NaN, black or magenta pixels from the shader.

## 0.21-dev – 2026-10-18 (prerelease)
Big feature update: reflections, splashes, ambient occlusion, weather, caustics, glass, own Nether and End looks, new profiles. Outlines and cel bands unchanged. Every new feature has its own toggle or slider.

**Shadows**
- Contact-hardening soft shadows: a blocker search measures how far the caster is, and the filter widens with that distance (24-tap rotated disk, world-anchored so it does not crawl). Wide, creamy edges away from the caster, tight contact at the base; soft cel transition kept. New **Shadow Penumbra** slider.
- Shadows also soften with view distance (**Distance Softness**); wider taps get a slightly larger bias against acne.
- Grain-free shadow interiors: wide taps on sloped surfaces get receiver-plane bias; small plant shadows are kept.
- Temporal shadow smoothing: shadow edges are blended over several frames through a history buffer (reprojected with the camera motion, rejected on disocclusion and clamped to the current neighbourhood, so swaying plants and moving mobs leave no trails). The shadow sampling pattern rotates every frame, so the history adds up to a much finer filter. **Temporal Shadow Smoothing**.
- Shadow edge smoothing: a depth- and normal-aware screen-space filter removes the stair-steps along long straight shadow edges and the fine noise at the penumbra in close-ups, without touching outlines or block edges. **Shadow Edge Smoothing** + **Edge Smoothing Size**.
- The shadow term is now shaded fully lit and fully shadowed and blended, so the smoothing stays colour-correct on graded grass and foliage.

**Water**
- Screen-space reflections: terrain, trees and buildings mirror in the water (calm-normal, fresnel weighted, edge-faded; falls back to the sky/cloud mirror off screen). **Water Reflections** + strength.
- Sun glint: banded glint path broken into small glinting cells. **Sun Glint** toggle.
- Foam rings around blocks, plants, mobs and players standing in the water.
- Splashes: expanding rings and white foam bursts around you while wading or swimming (stronger when moving); churning foam pools where falling water lands. **Water Splashes** + amount. Splash particles themselves still come from the game.
- Underwater caustics on surfaces under water, and faintly on the bottom seen from above. **Caustics** + strength.
- Underwater light rays from the surface while diving. **Underwater Rays**.
- Wakes: a V-shaped white wake behind you while swimming or in a boat. **Wakes**.
- Waterfalls: big stylized white and blue foam blobs tumbling down, white mist over the pool at the base. **Waterfall Foam**.
- Glowing cyan shallows with white wavy bands on the bottom, also at night. **Glowing Shallows** + amount.
- Calmer, mirror-clear reflections on still water; long bright sun streak on the water at sunrise and sunset. **Sun Streak**.
- Bubble particles directly in front of the camera are hidden (no dark rings underwater).
- Splash rings and wakes follow the player, also in third person and while riding a boat; idle rings are fainter and tighter.
- Kelp and seagrass reaching the surface no longer read as glowing shallows.

**Light**
- Ambient occlusion: soft, banded contact shading in corners and under overhangs. **Ambient Occlusion** + strength.
- Cloud shadows drifting across the land with the same wind as the grass gusts. **Cloud Shadows** + strength.
- Light shafts outdoors: through forest canopies, morning mist and rain, only where the canopy breaks the light. **Outdoor Light Shafts**.
- Shadows get softer with distance. **Distance Softness**.
- Sunlight through stained glass takes the glass colour. **Tinted Glass Light**.
- Leaf translucency: backlit leaves and grass glow warm-green toward the sun. **Leaf Translucency**.
- Faint glow on flowers at night. **Night Flower Glow**.
- Soft radial glow around lanterns, torches, lava and other lights. **Light Glow**.
- Glowing halo around the sun disk. **Sun Halo**.
- Stronger god rays in forests and under canopies. **Forest Rays**.
- Blue depth haze between trees. **Forest Haze**.
- Foliage light: yellow-green sunlit tops and cool shade on grass, bright sunlit leaf edges against darker inner shade. **Foliage Light**.
- Cherry leaves keep their pink (no longer pulled toward lime).

**Sky, colour and weather**
- Time-of-day grading: separate moods for sunrise, noon, golden hour, blue hour and night. **Time-of-Day Grading** + strength.
- Aerial perspective: far terrain and mountains fade to soft blue. **Distance Blue**.
- Rain fog (banded), white haze in snowfall, sandstorms in hot dry biomes during bad weather. **Weather Effects**, **Rain Fog**, **Sandstorm**.
- Wet ground: darker, glossier ground and puddle sheen while it rains. **Wet Ground** + strength.
- Rain streaks and a darker blue mood for night rain. **Rain Mood**.
- Faint painted Milky Way with denser stars in the band, soft cloudy edges. **Milky Way**.
- Clouds: cubic block clouds by default, shaded with sun-side bands, dusk tint and distance fade; painted sky-plane clouds selectable. **Painted Clouds**.

**Glass**
- Fresnel sky sheen and a stylized highlight streak on glass. **Glass Reflections** + strength.

**Nether and End**
- Own Nether look: warm ember ambient, banded fog in the biome's fog colour, rising embers. **Nether Look**.
- Lava and fire burn hotter orange with a slow shimmer; fog turns red near lava; Nether biome fog colours (warped forest cyan, crimson red, soul valley blue) come through.
- Light outlines glow pink-purple in the Nether.
- Own End look: violet ambient and fog, painted End sky with nebula bands and stars. **End Look**.
- No sun, sky or weather effects run in those dimensions.

**Image quality and profiles**
- Light FXAA that smooths geometry stair-steps and leaves outlines crisp. **Anti-Aliasing (FXAA)**.
- Optional distance blur, off by default. **Distance Blur** + strength.
- Profiles: Low, Medium, High and new Ultra (Ultra: 4096 shadows, strongest AO and light shafts).

**Testing**
- Tested in the client: soft shadows (close-ups, long edges, low sun, fast camera turns), water (ocean, shore, lake glint, coast sunset, river reflections, night shallows, waterfall, wading, swimming wake, boat wake, underwater caustics and rays), forest, rain, desert storm, snowfall, night sky, Nether and End. No NaN, black or magenta pixels from the shader in the captures.
- Known limits: reflections are screen-space (what is off screen cannot reflect); splash rings and wakes react to the player only, other entities get foam rings where they touch the water; splash particles come from the game.

## 0.20-dev – 2026-10-18 (prerelease)
Smooth shadows, wind across the fields, golden-hour grass, darker water, coloured light.

**Shadows**
- Soft PCF filtering: 12 rotated Poisson taps per pixel, rotation fixed in world space so edges stay stable while moving (no crawling or flicker).
- Slope-scaled bias against acne; no peter-panning on block bases.
- Soft cel-banded shadow transition (new **Shadow Edge** slider); cel bands themselves unchanged.
- Shadow map 2048 by default, 4096 option; **Shadow Softness** 0-3 (default 2). Profiles: Medium 2048 / softness 2, High 4096 / softness 3.
- Swaying plants and leaves now move in the shadow pass too, so their shadows follow the plants.

**Wind and grass**
- One shared wind field: gusts roll visibly across fields (slower, narrower fronts), tall grass, flowers and leaves follow it with a gentle base sway.
- Subtle sheen where a gust bends the grass (no glow); new toggles/sliders **Wind Gusts**, **Gust Strength**, **Wind Speed**, **Wind Sheen**.
- New **Grass Tone** (cool / warm meadow, default warm): warmer, yellow-leaning ground green with smoother texel contrast.
- New **Golden Hour Light**: low sun warms lit grass and leaves at sunrise/sunset and deepens the shade side.

**Water**
- Slightly darker body (deeper mid and deep colours) for stronger contrast with the foam.

**Light and atmosphere**
- Coloured block light: surfaces near soul, redstone, amethyst, portal and other coloured sources take their colour; brightness preserved (no dark halos). **Coloured Light** toggle + strength.
- Cave fog: darker, slightly cool fog underground with soft band steps. **Cave Fog** toggle + density.
- Interior light shafts through windows and openings (subtle). **Light Shafts** toggle + strength.

**Fixes**
- Outlines menu entry resolves correctly again.
- QA: no NaN/black/magenta pixels in plains noon/sunset, forest edge, close shadow edges, torch room, cave, interior and water captures. Outlines and cel bands unchanged.
- Known: interior light shafts are subtle; coloured light is a screen-space effect (sources off screen do not tint).

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
