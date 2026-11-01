// Solace - user options (parsed by Iris for the settings menu)
#define CEL_BANDS 3 // [2 3 4 5]
#define CEL_EDGE 0.06 // [0.01 0.03 0.06 0.1 0.15 0.2]
#define SHADOWS
#define SHADOW_SOFTNESS 2 // [0 1 2 3]
#define SHADOW_TINT_R 0.36 // [0.30 0.36 0.40 0.46 0.50]
#define SHADOW_TINT_G 0.43 // [0.34 0.40 0.43 0.48 0.52]
#define SHADOW_TINT_B 0.62 // [0.44 0.50 0.54 0.62 0.70]
//#define OUTLINES // ink outlines around shapes (off by default for a clean painted look)
#define WATER_PAINTERLY // brighter turquoise water with soft brush-stroke highlights
#define WATER_PAINTERLY_K 1.0 // [0.5 0.75 1.0]
#define WATER_SAT 0.85 // [0.6 0.75 0.85 0.95 1.1]
#define WATER_BRIGHT 1.0 // [0.85 1.0 1.15 1.3]
#define GROUND_GRADE // grass ground graded toward the target-look hue, flat soft light
#define GROUND_GRADE_STRENGTH 0.75 // [0.3 0.45 0.6 0.75 0.9]
#define SOFT_GRASS // very gentle soft grass: calmer tops, soft gradients and contact shade
#define SOFT_GRASS_STRENGTH 1.0 // [0.5 1.0 1.5]
#define GRASS_SMOOTH 0.45 // [0.0 0.3 0.45 0.5 0.7 0.9] low-pass grass top texture detail
#define TEXTURE_CALM 0.25 // [0.0 0.15 0.25 0.35 0.5] smooth cartoon textures: less harsh texel noise on blocks
#define GRASS_GRADIENT 7 // [0 4 7 10] grass blades: dark roots rising to bright sunlit tips (x10 percent)
#define CHAR_RIM 7 // [0 4 7 10] soft light fringe on mobs and players all day (x10 percent)
#define ENTITY_SOFT 9 // [0 4 7 9 10] soft two-tone cartoon shading on mobs and players (x10 percent)
#define FAR_SOFTEN 6 // [0 3 6 8 10] painterly distance: far blocks flatten to soft tones (x10 percent)
#define FOLIAGE_SMOOTH 0.5 // [0.0 0.35 0.5 0.65 0.85] smooth leaf masses instead of checker noise
#define HIDE_LEAF_LITTER // leaf litter specks off (smooth even ground)
#define GRASS_SWAY 0.07 // [0.0 0.05 0.07 0.10 0.15]
#define GRASS_SWAY_SPEED 1.2 // [0.6 1.2 2.0]
#define TORCH_STRENGTH 0.9 // [0.5 0.6 0.75 0.9 1.0]
#define SOFT_CLOUDS // cloud style: on = painted soft clouds on a sky plane (default), off = cubic block clouds
#define CLOUD_LAYERS // three cubic cloud layers at different heights and speeds (parallax)
#define CLOUD_PUFFY // low cloud layer: big rounded soft puffs instead of block cells
#define CLOUD_LOW // low layer: bigger, faster, softer-lit (casts soft ground shadows)
#define CLOUD_HIGH // high layer: thin, slow, wispy-blocky
#define CLOUD_LAYER_SPEED 1.0 // [0.5 1.0 1.5 2.0]
#define CLOUD_SMOOTH // far cubic clouds: smooth shading, faded edge-on faces and distance fade
#define CLOUD_COVER 0.5 // [0.2 0.35 0.5 0.65 0.8]
#define WAVING_FOLIAGE // gentle wind sway for leaves and plants
#define WAVING_STRENGTH 1.0 // [0.5 0.75 1.0 1.5 2.0]
//#define LIGHT_OUTLINES // very subtle thin light outlines
#define LIGHT_OUTLINE_OPACITY 0.25 // [0.1 0.15 0.25 0.35 0.5]
#define BIOME_MOOD 0.8 // [0.0 0.4 0.6 0.8 1.0] biome-aware grading, fog and water
#define EMISSIVE_BLOCKS // light-emitting blocks render self-lit in their colour
#define EMISSIVE_STRENGTH 1.15 // [0.8 1.0 1.15 1.4]
#define WATER_OPACITY 1.0 // [0.6 0.8 1.0 1.2]
#define WATER_DEPTH_TINT 0.70 // [0.40 0.55 0.70 0.85]
#define EDGE_STYLE 0 // [0 1 2] 0 off, 1 soft coloured edges, 2 black ink
#define SOFT_EDGE_STRENGTH 0.45 // [0.2 0.3 0.45 0.6 0.8]
#define STYLE 1 // [0 1] 0 Normal (vanilla-like packs), 1 Cartoony
#if STYLE == 1
#define STYLE_K 1.0
#else
#define STYLE_K 0.55
#endif
//#define OUTLINE_NORMALS // inner block edges (normal Sobel)
#define EDGE_KERNEL 1 // [0 1] depth edge detector: 0 gradient (legacy), 1 second difference (no false lines on flat ground)
//#define GRASS_LEDGE_LINES // outline small grass ledges too (off: no light lines across flat-looking grass)
//#define OUTLINE_DEBUG // debug: paint outline pixels red
#define INNER_STRENGTH 0.40 // [0.2 0.3 0.4 0.55 0.7]
#define INNER_FADE 48.0 // [24.0 32.0 48.0 64.0 96.0]
#define OUTLINE_THICKNESS 1.0 // [0.5 1.0 1.5 2.0 3.0]
#define OUTLINE_STRENGTH 1.0 // [0.25 0.5 0.7 0.85 0.9 1.0]
#define OUTLINE_R 0.10 // [0.0 0.06 0.10 0.15 0.3 0.5]
#define OUTLINE_G 0.10 // [0.0 0.05 0.10 0.15 0.3 0.5]
#define OUTLINE_B 0.165 // [0.0 0.10 0.165 0.2 0.3 0.5]
#define OUTLINE_FADE 128.0 // [32.0 64.0 96.0 128.0 160.0 256.0]
#define AMBIENT_BOOST 1.50 // [1.0 1.15 1.35 1.50 1.7 1.9]
#define FOLIAGE_LIME 0.2 // [0.0 0.2 0.45 0.60 0.8]
#define SATURATION 1.12 // [1.0 1.1 1.12 1.2 1.25 1.35 1.4 1.6]
#define WARM_SAT_LIMIT 0.55 // [0.0 0.25 0.55 0.8 1.0]
#define LUMA_CAP 0.86 // [0.76 0.82 0.86 0.92 1.00]
#define VIBRANCE 0.25 // [0.0 0.15 0.25 0.30 0.50 0.75]
#define LIME_GREENS 0.0 // [0.0 0.06 0.08 0.12 0.20 0.25 0.30 0.38 0.45]
#define WARMTH 0.0 // [0.0 0.08 0.15 0.30 0.45]
#define WATER_WAVES
#define WATER_FOAM
#define WATER_SPARKLE
#define SCENE_TINT 0.6 // [0.0 0.25 0.5 0.6 0.75 1.0]
#define DUSK_TINT 1.0 // [0.0 0.25 0.5 0.85 1.0]
#define BLOOM
#define GODRAYS
#define SHORE_FOAM 0.85 // [0.0 0.5 0.85 1.0] soft white foam line washing along the shore
#define BOUNCE_LIGHT 3 // [0 2 3 5] warm light bounced from sunlit ground onto undersides (x10 percent)
#define AERIAL_PERSPECTIVE 4 // [0 2 4 6] distant land fades paler and bluer into the sky (x10 percent)
#define GRASS_PART 1.0 // [0.0 0.5 1.0 1.5] grass and flowers bend softly away around your feet
#define SUN_SPOTS 0.6 // [0.0 0.35 0.6 0.85] soft round sun spots on the ground under leaf canopies
#define CANOPY_RAYS 1.0 // [0.0 0.5 1.0 1.5] long soft sun beams through gaps in tree canopies
#define GODRAYS_STRENGTH 0.7 // [0.0 0.2 0.35 0.5 0.7 0.9]
#define CANOPY_GLOW 0.20 // [0.0 0.06 0.12 0.20 0.30]
#define BLOOM_STRENGTH 0.9 // [0.0 0.3 0.6 0.9 1.2]
#define HAZE 0.0 // [0.0 0.1 0.18 0.22 0.3 0.45]
#define SAND_BOOST 0.8 // [0.0 0.4 0.8 1.0]
//#define DISTANCE_FOG
#define FOG_STRENGTH 0.55 // [0.0 0.25 0.55 0.75 1.0]
#define UNDERWATER_FOG 0.6 // [0.2 0.4 0.6 0.8 1.0]
#define SKY_BANDS 6 // [3 4 6 8 12]

const int shadowMapResolution = 2048; // [512 1024 2048 4096]
const float shadowDistance = 64.0; // [48.0 64.0 96.0 128.0]
const float sunPathRotation = -25.0;
// 0.16 atmosphere
#define SKY_SUN_GLOW 0.5 // [0.0 0.25 0.5 1.0 1.5]
#define DUSK_SKY 1.0 // [0.5 0.75 1.0]
#define FOG_SKY_MATCH 0.8 // [0.0 0.4 0.6 0.8 1.0] fog takes the sky horizon colour
#define VALLEY_FOG 0.6 // [0.0 0.2 0.35 0.45 0.6 0.8] calm low-lying fog layer in valleys and over rivers
#define VALLEY_FOG_HEIGHT 74.0 // [64.0 67.0 70.0 74.0 80.0] top of the valley fog layer (world height)
#define MORNING_MIST 0.0 // [0.0 0.3 0.6 0.9] low ground mist at sunrise and in swamps
#define BIOME_FOG 0.0 // [0.0 0.5 1.0 1.5] denser fog in swamps, dark forests, cold biomes
#define WATER_CLARITY 1.0 // [0.0 0.5 1.0 1.5] clearer, paler shallows
#define WATER_REFLECT 1.0 // [0.0 0.5 1.0 1.5] distant sky reflection
#define WATER_FOAM_AMT 1.0 // [0.0 0.5 1.0 1.3] foam sheets
#define HORIZON_HAZE 0.0 // [0.0 0.5 1.0 1.5] white haze where sea meets sky
// 0.20 lighting
#define COLORED_LIGHT // light sources tint nearby block light in their own colour
#define COLORED_LIGHT_STRENGTH 0.8 // [0.4 0.6 0.8 1.0]
//#define CAVE_FOG // darker, denser fog underground
#ifdef CAVE_FOG
#define CAVE_FOG_ON 1.0
#else
#define CAVE_FOG_ON 0.0
#endif
#define CAVE_FOG_DENSITY 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define LIGHT_SHAFTS // sun shafts through windows, doors and canopies
#define LIGHT_SHAFTS_STRENGTH 1.0 // [0.5 0.75 1.0 1.5]
// 0.20 shadows + wind
#define SHADOW_EDGE 0.18 // [0.06 0.12 0.18 0.25 0.35] softness of the shadow band edge
#define WIND_GUSTS // breeze waves rolling across grass fields and trees
#define WIND_GUST_STRENGTH 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define WIND_STREAKS 1.0 // [0.0 0.5 1.0 1.5] thin soft wind lines drifting with the breeze
#define WIND_SPEED 1.0 // [0.5 0.75 1.0 1.5]
#define FIELD_WAVES 1.0 // [0.0 0.4 0.7 1.0 1.4] soft bright waves rolling across grass fields
#define FLAME_FLICKER 1.0 // [0.0 0.5 1.0] torch and lantern light breathes softly, a little livelier on gusts
#define LANTERN_SWAY 1.0 // [0.0 0.5 1.0 1.5] hanging lanterns swing gently on their chain, more in a gust
#define REED_SWAY 1.0 // [0.0 0.5 1.0 1.5] sugar cane and bamboo bend and ripple in the breeze
#define AMETHYST_TWINKLE 1.0 // [0.0 0.5 1.0 1.5] a few amethyst crystal facets twinkle now and then
#define WEB_LITTER_WIND 1.0 // [0.0 0.5 1.0 1.5] cobwebs billow and leaf litter stirs in gusts
#define CANDLE_GLOW 1.0 // [0.0 0.5 1.0 1.5] soft warm glow around lit candles
#define MORNING_DEW 1.0 // [0.0 0.5 1.0] dew drops on grass twinkle in the morning sun
#define LILY_BOB 1.0 // [0.0 0.5 1.0 1.5] lily pads bob and drift a little on the water
#define LEAF_GLINTS 1.0 // [0.0 0.5 1.0] when a gust passes, a few sunlit leaves catch the sun for a moment
#define DRIFT_LEAVES 1.0 // [0.0 0.5 1.0] loose leaves tumble down and sail downwind when a gust passes
#define CHERRY_GLOW 0.6 // [0.0 0.3 0.6 1.0] cherry blossoms settle into one calm pastel pink with a soft glow in the sun
#define SAVANNA_GOLD 0.7 // [0.0 0.4 0.7 1.0] savanna grass keeps a warm golden-olive tone instead of meadow green
#define FROST_TIPS 0.6 // [0.0 0.3 0.6 1.0] in snowy lands the tops of tree crowns wear a soft pale frost
#define SMOOTH_SHADING 1.0 // [0.0 0.5 1.0] 0 = stepped cel light bands, 1 = soft smooth light with colour contrast
#define SUN_GLARE 0.6 // [0.0 0.3 0.6 1.0] bright glow and soft radial streaks around the sun
#define NAVY_MOOD 0.8 // [0.0 0.3 0.6 0.8 1.0] rain and night sink into a deep navy-blue mood
#define NAVY_RAIN 1.6 // [1.0 1.3 1.6 2.0] how much stronger rain turns navy than night
#define TORCH_ORANGE 0.7 // [0.0 0.4 0.7 1.0] torches, lanterns and fire cast a saturated orange glow
#define SNOW_NIGHT_LIFT 1.0 // [0.0 0.3 0.6 1.0] snowy nights and snowfall: dark tones lift gently so snowy land stays readable
#define HORIZON_SOFT 1.0 // [0.0 0.5 1.0] clear days: the sky near the horizon rolls off softly into calm sky-blue instead of clipping to bright mint
#define TEAL_GREENS 0.6 // [0.0 0.3 0.6 0.8 1.0] grass and leaves lean from lime into a deeper painted blue-green
#define LEAF_DEEP 1.0 // [0.0 0.3 0.6 0.8 1.0] tree crowns settle into a deeper, darker teal-green than open grass
#define RAIN_DAY_SOFT 0.7 // [0.0 0.35 0.7 1.0] rain by day: land stays a soft slate grey-green instead of deep blue
#define RAIN_NIGHT_LIFT 0.8 // [0.0 0.4 0.8 1.0] rainy nights: dark tones lift gently so wet land stays readable
#define FAR_SHADE 1.0 // [0.0 0.5 1.0 1.5] far hills keep deep blue-teal shade sides with smooth shading
#define COOL_AIR 0.6 // [0.0 0.3 0.6 0.8 1.0] the whole world sits in a clear, cool blue-cyan air; shade leans deep blue-teal
#define CANOPY_DEPTH 0.6 // [0.0 0.3 0.6 1.0] leaves deep inside and under a canopy turn a cooler deep green, outer leaves stay bright
#define LEAF_SHEEN 0.6 // [0.0 0.3 0.6 1.0] calm soft sheen on sunlit canopy tops, like painted highlights
#define MORNING_BLUE 0.6 // [0.0 0.3 0.6 1.0] fresh, slightly cool blue air over the land in the early morning
#define PALE_GARDEN_MOOD 1.0 // [0.0 0.5 1.0] pale gardens turn quiet, muted and grey-green
#define WIND_SHEEN 0.15 // [0.0 0.05 0.10 0.15 0.2] light sheen where gusts bend the grass
#define GRASS_TONE 0 // [0 1] 0 = cool green, 1 = warm meadow green
#define WARM_COOL 2 // [0 1 2 3 4] warm sunlight and cool sky-blue shade
#define GOLDEN_HOUR_TINT 0.6 // [0.0 0.3 0.6 0.9] warm low-sun light on grass and leaves
#define WATER_SSR // screen-space reflections of terrain on water
#define WATER_SSR_STRENGTH 0.8 // [0.4 0.6 0.8 1.0]
#define NIGHT_LIGHT_REFLECT // vivid coloured reflections of light sources on night water
#define NIGHT_LIGHT_REFLECT_STRENGTH 1.0 // [0.5 1.0 1.5 2.0]
#define NIGHT_WAKE_BRIGHT // wakes and splashes stay bright white at night
#define WATER_STARS // cross-shaped twinkling sparkles on sunlit water
#define WATER_STARS_STRENGTH 0.45 // [0.25 0.45 0.6 0.9]
//#define WATER_ROLL // rolling ocean swell with blocky foam caps (oceans only)
#define WATER_ROLL_HEIGHT 1.0 // [0.5 1.0 1.5]
#define FIREFLIES // drifting, blinking fireflies near the player on warm nights
#define FIREFLY_AMOUNT 1.0 // [0.5 1.0 1.5 2.0]
#define BIOME_SKY 1.0 // [0.0 0.5 1.0 1.5] the day sky takes on the colours of the biome
#define WATER_SUN_GLINT // banded sun glint path on water
#define SSAO // soft contact shading in corners (banded)
#define SSAO_STRENGTH 0.35 // [0.15 0.25 0.35 0.5 0.65]
#define CLOUD_SHADOWS // soft cloud shadows drifting with the wind
#define CLOUD_SHADOW_STRENGTH 0.35 // [0.15 0.25 0.35 0.5]
#define VOLUMETRIC_OUTDOOR 0.6 // [0.0 0.3 0.6 1.0] light shafts in forests, mist and rain
#define WATER_SPLASH // rings and foam bursts around the player in water, foam where falling water lands
#define WATER_SPLASH_AMT 1.0 // [0.0 0.5 1.0 1.5]
#define MOUNTAIN_LAYERS 0 // [0 1 2 3 4] far ridges fade in soft steps like stacked silhouettes
#define DISTANCE_BLUE 0.5 // [0.0 0.2 0.35 0.5 0.6 0.75] far mountains fade to soft blue
#define TIME_GRADING // per time-of-day colour grading (sunrise, noon, golden hour, blue hour, night)
#define TIME_GRADING_STRENGTH 1.0 // [0.0 0.5 1.0 1.5]
#define WEATHER_FX // rain fog, sandstorms in hot dry biomes, snow haze
#define RAIN_FOG 1.0 // [0.0 0.5 1.0 1.5]
#define RAIN_SHAFTS 2 // [0 1 2 3] soft pale light beams through the rain clouds by day
#define SANDSTORM 1.0 // [0.0 0.5 1.0]
#define WET_GROUND // darker glossy ground and puddle sheen in rain
#define WET_GROUND_STRENGTH 1.0 // [0.0 0.5 1.0 1.5]
#define MILKY_WAY 1.0 // [0.0 0.5 1.0 1.5] faint Milky Way band at night
#define SHADOW_DIST_SOFT 0.6 // [0.0 0.3 0.6 1.0] shadows get softer with distance
#define GLASS_TINT_LIGHT // sunlight through stained glass takes its colour
//#define GLASS_DEBUG // debug: paint the tinted-glass light path magenta
#define CAUSTICS // banded light net under water
#define CAUSTICS_STRENGTH 1.0 // [0.0 0.5 1.0 1.5]
#define UNDERWATER_RAYS 1.0 // [0.0 0.5 1.0 1.5] light shafts from the surface when diving
#define GLASS_REFLECT // fresnel sky sheen and highlight streak on glass
#define GLASS_REFLECT_STRENGTH 1.0 // [0.0 0.5 1.0 1.5]
#define NETHER_FOG 0.0 // [0.0 0.5 1.0 1.5] banded Nether fog in the biome colour, rising embers
#define NETHER_EMBERS 1.0 // [0.0 0.5 1.0 1.5] rising embers and heat glow around lava in the Nether, also with Nether fog off
#define NETHER_AMBIENT 1.0 // [0.0 0.5 1.0] calm warm ambient tint in the Nether
#define END_FOG 0.0 // [0.0 0.5 1.0 1.5] violet End fog and painted End sky
#define LEAF_TRANSLUCENCY 0.35 // [0.0 0.2 0.35 0.5] backlit leaves glow toward the sun
#define NIGHT_GLOW 1.0 // [0.0 0.5 1.0] faint glow on flowers at night
#define FXAA // light anti-aliasing that keeps outlines crisp
#define SKY_BRIGHT 0.8 // [0.0 0.5 0.8 1.0] bright open day sky with a luminous horizon
#define PAINTERLY_FAR 9 // [0 5 7 9 10] painterly distance: far land melts into soft brush-like patches (x10 percent)
//#define DISTANCE_BLUR // optional soft blur of far terrain
#define DISTANCE_BLUR_STRENGTH 1.0 // [0.5 1.0 1.5 2.0]
#define WATER_WAKE // V-shaped wake behind you and your boat
#define WATERFALL_BLOBS // big stylized foam blobs on falling water
#define GLOW_SHALLOWS // glowing cyan shallows with white wave bands (also at night)
#define GLOW_SHALLOWS_AMT 1.0 // [0.0 0.5 1.0 1.5]
#define DUSK_WATER_GLOW 2 // [0 1 2 3 4] broad soft warm light on water toward the low sun
#define SUNSET_STREAK // long sun streak on water at sunrise/sunset
#define LIGHT_HALO 0.6 // [0.0 0.3 0.6 1.0] soft glow around lanterns, torches and lava
#define SOFT_STARS 1 // [0 1 2] soft round stars with a faint halo (0 = classic dots)
#define RAINBOW 1 // [0 1 2] soft pastel rainbow while the world is still wet after rain
#define MOON_HALO 1.0 // [0.0 0.5 1.0 1.5] soft silver glow and faint ring around the moon
#define SUN_HALO 0.0 // [0.0 0.3 0.6 1.0] glowing sun disk halo
#define RAIN_STREAKS 1.0 // [0.0 0.5 1.0] rain streaks and darker blue night rain mood
#define FOREST_RAYS 0.8 // [0.0 0.4 0.8 1.2] stronger god rays in forests
#define FOREST_HAZE 0.0 // [0.0 0.2 0.35 0.5] blue depth haze between trees
#define FOLIAGE_CONTRAST 0.6 // [0.0 0.3 0.6 1.0] sunlit yellow-green vs cool shade on grass and leaves
#define SHADOW_PENUMBRA 1.0 // [0.5 1.0 1.5 2.0] how fast shadows soften away from the caster
#define SHADOW_TEMPORAL // temporal shadow smoothing (history buffer, reprojection + clamp)
#define SHADOW_FILTER // screen-space edge smoothing of shadows (depth/normal aware)
#define SHADOW_FILTER_SIZE 1.0 // [0.5 1.0 1.5 2.0] size of the shadow edge smoothing
//#define RIM_DEBUG
#define RIM_LIGHT // soft bright fringe on silhouettes, mainly against the sun or moon
#define RIM_STRENGTH 0.6 // [0.3 0.6 1.0 1.5]
#define RIM_WIDTH 1.0 // [0.6 1.0 1.4]

#ifdef CLOUD_LAYERS
#endif
#define HELD_LIGHT // a torch or lantern in hand lights up the area around you
#define HELD_LIGHT_STRENGTH 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define STYLISED_LAVA // calm cartoon lava: deep orange with slow bright veins
#define LAVA_BRIGHT 1.0 // [0.8 0.9 1.0 1.1 1.2]
#define GOLDEN_RIM // warm golden fringe on characters at sunrise and sunset
#define GOLDEN_RIM_STRENGTH 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define CAVE_HAZE 0.0 // [0.0 0.3 0.6 0.9 1.2] glowing haze around lava and lights underground
#define MOON_RIM 1.0 // [0.0 0.5 1.0 1.5] faint silver moon fringe on characters at night
#define MIST_SHEETS 0.6 // [0.0 0.3 0.45 0.6 0.75] far valley mist sheets seen from high ground
#define MIST_SHEET_TOP 74.0 // [70.0 74.0 78.0] top of the far valley mist band (world height)
