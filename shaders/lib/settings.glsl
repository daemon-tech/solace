// Solace - user options (parsed by Iris for the settings menu)
#define CEL_BANDS 3 // [2 3 4 5]
#define CEL_EDGE 0.06 // [0.01 0.03 0.06 0.1 0.15 0.2]
#define SHADOWS
#define SHADOW_SOFTNESS 2 // [0 1 2 3]
#define SHADOW_TINT_R 0.40 // [0.30 0.36 0.40 0.46 0.50]
#define SHADOW_TINT_G 0.43 // [0.34 0.40 0.43 0.48 0.52]
#define SHADOW_TINT_B 0.54 // [0.44 0.50 0.54 0.62 0.70]
#define OUTLINES
#define WATER_SAT 0.95 // [0.6 0.75 0.85 0.95 1.1]
#define WATER_BRIGHT 1.0 // [0.85 1.0 1.15 1.3]
#define GROUND_GRADE // grass ground graded toward the target-look hue, flat soft light
#define GROUND_GRADE_STRENGTH 0.75 // [0.3 0.45 0.6 0.75 0.9]
#define SOFT_GRASS // very gentle soft grass: calmer tops, soft gradients and contact shade
#define SOFT_GRASS_STRENGTH 1.0 // [0.5 1.0 1.5]
#define GRASS_SMOOTH 0.3 // [0.0 0.3 0.5 0.7 0.9] low-pass grass top texture detail
#define FOLIAGE_SMOOTH 0.5 // [0.0 0.35 0.5 0.65 0.85] smooth leaf masses instead of checker noise
#define HIDE_LEAF_LITTER // leaf litter specks off (smooth even ground)
#define GRASS_SWAY 0.10 // [0.0 0.05 0.10 0.15]
#define GRASS_SWAY_SPEED 1.2 // [0.6 1.2 2.0]
#define TORCH_STRENGTH 0.9 // [0.5 0.6 0.75 0.9 1.0]
//#define SOFT_CLOUDS // cloud style: on = painted soft clouds on a sky plane, off = cubic block clouds (default)
#define CLOUD_LAYERS // three cubic cloud layers at different heights and speeds (parallax)
#define CLOUD_LOW // low layer: bigger, faster, softer-lit (casts soft ground shadows)
#define CLOUD_HIGH // high layer: thin, slow, wispy-blocky
#define CLOUD_LAYER_SPEED 1.0 // [0.5 1.0 1.5 2.0]
#define CLOUD_SMOOTH // far cubic clouds: smooth shading, faded edge-on faces and distance fade
#define CLOUD_COVER 0.5 // [0.2 0.35 0.5 0.65 0.8]
#define WAVING_FOLIAGE // gentle wind sway for leaves and plants
#define WAVING_STRENGTH 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define LIGHT_OUTLINES // very subtle thin light outlines
#define LIGHT_OUTLINE_OPACITY 0.25 // [0.1 0.15 0.25 0.35 0.5]
#define BIOME_MOOD 0.8 // [0.0 0.4 0.6 0.8 1.0] biome-aware grading, fog and water
#define EMISSIVE_BLOCKS // light-emitting blocks render self-lit in their colour
#define EMISSIVE_STRENGTH 1.15 // [0.8 1.0 1.15 1.4]
#define WATER_OPACITY 1.0 // [0.6 0.8 1.0 1.2]
#define WATER_DEPTH_TINT 0.70 // [0.40 0.55 0.70 0.85]
#define EDGE_STYLE 1 // [0 1 2] 0 off, 1 soft coloured edges, 2 black ink
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
#define FOLIAGE_LIME 0.60 // [0.0 0.2 0.45 0.60 0.8]
#define SATURATION 1.2 // [1.0 1.1 1.2 1.25 1.35 1.4 1.6]
#define WARM_SAT_LIMIT 0.55 // [0.0 0.25 0.55 0.8 1.0]
#define LUMA_CAP 0.86 // [0.76 0.82 0.86 0.92 1.00]
#define VIBRANCE 0.30 // [0.0 0.15 0.30 0.50 0.75]
#define LIME_GREENS 0.12 // [0.0 0.06 0.08 0.12 0.20 0.25 0.30 0.38 0.45]
#define WARMTH 0.15 // [0.0 0.08 0.15 0.30 0.45]
#define WATER_WAVES
#define WATER_FOAM
#define WATER_SPARKLE
#define SCENE_TINT 0.6 // [0.0 0.25 0.5 0.6 0.75 1.0]
#define DUSK_TINT 1.0 // [0.0 0.25 0.5 0.85 1.0]
#define BLOOM
#define GODRAYS
#define GODRAYS_STRENGTH 0.5 // [0.0 0.2 0.35 0.5 0.7]
#define CANOPY_GLOW 0.20 // [0.0 0.06 0.12 0.20 0.30]
#define BLOOM_STRENGTH 0.6 // [0.0 0.3 0.6 0.9 1.2]
#define HAZE 0.3 // [0.0 0.1 0.18 0.22 0.3 0.45]
#define SAND_BOOST 0.8 // [0.0 0.4 0.8 1.0]
#define DISTANCE_FOG
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
#define MORNING_MIST 0.6 // [0.0 0.3 0.6 0.9] low ground mist at sunrise and in swamps
#define BIOME_FOG 1.0 // [0.0 0.5 1.0 1.5] denser fog in swamps, dark forests, cold biomes
#define WATER_CLARITY 1.0 // [0.0 0.5 1.0 1.5] clearer, paler shallows
#define WATER_REFLECT 1.0 // [0.0 0.5 1.0 1.5] distant sky reflection
#define WATER_FOAM_AMT 1.0 // [0.0 0.5 1.0 1.3] foam sheets
#define HORIZON_HAZE 1.0 // [0.0 0.5 1.0 1.5] white haze where sea meets sky
// 0.20 lighting
#define COLORED_LIGHT // light sources tint nearby block light in their own colour
#define COLORED_LIGHT_STRENGTH 0.8 // [0.4 0.6 0.8 1.0]
#define CAVE_FOG // darker, denser fog underground
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
#define WIND_SPEED 1.0 // [0.5 0.75 1.0 1.5]
#define WIND_SHEEN 0.15 // [0.0 0.05 0.10 0.15 0.2] light sheen where gusts bend the grass
#define GRASS_TONE 1 // [0 1] 0 = cool green, 1 = warm meadow green
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
#define DISTANCE_BLUE 0.35 // [0.0 0.2 0.35 0.5] far mountains fade to soft blue
#define TIME_GRADING // per time-of-day colour grading (sunrise, noon, golden hour, blue hour, night)
#define TIME_GRADING_STRENGTH 1.0 // [0.0 0.5 1.0 1.5]
#define WEATHER_FX // rain fog, sandstorms in hot dry biomes, snow haze
#define RAIN_FOG 1.0 // [0.0 0.5 1.0 1.5]
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
#define NETHER_FOG 1.0 // [0.0 0.5 1.0 1.5] banded Nether fog in the biome colour, rising embers
#define END_FOG 1.0 // [0.0 0.5 1.0 1.5] violet End fog and painted End sky
#define LEAF_TRANSLUCENCY 0.35 // [0.0 0.2 0.35 0.5] backlit leaves glow toward the sun
#define NIGHT_GLOW 1.0 // [0.0 0.5 1.0] faint glow on flowers at night
#define FXAA // light anti-aliasing that keeps outlines crisp
//#define DISTANCE_BLUR // optional soft blur of far terrain
#define DISTANCE_BLUR_STRENGTH 1.0 // [0.5 1.0 1.5 2.0]
#define WATER_WAKE // V-shaped wake behind you and your boat
#define WATERFALL_BLOBS // big stylized foam blobs on falling water
#define GLOW_SHALLOWS // glowing cyan shallows with white wave bands (also at night)
#define GLOW_SHALLOWS_AMT 1.0 // [0.0 0.5 1.0 1.5]
#define SUNSET_STREAK // long sun streak on water at sunrise/sunset
#define LIGHT_HALO 0.6 // [0.0 0.3 0.6 1.0] soft glow around lanterns, torches and lava
#define SUN_HALO 0.6 // [0.0 0.3 0.6 1.0] glowing sun disk halo
#define RAIN_STREAKS 1.0 // [0.0 0.5 1.0] rain streaks and darker blue night rain mood
#define FOREST_RAYS 0.8 // [0.0 0.4 0.8 1.2] stronger god rays in forests
#define FOREST_HAZE 0.35 // [0.0 0.2 0.35 0.5] blue depth haze between trees
#define FOLIAGE_CONTRAST 0.6 // [0.0 0.3 0.6 1.0] sunlit yellow-green vs cool shade on grass and leaves
#define SHADOW_PENUMBRA 1.0 // [0.5 1.0 1.5 2.0] how fast shadows soften away from the caster
#define SHADOW_TEMPORAL // temporal shadow smoothing (history buffer, reprojection + clamp)
#define SHADOW_FILTER // screen-space edge smoothing of shadows (depth/normal aware)
#define SHADOW_FILTER_SIZE 1.0 // [0.5 1.0 1.5 2.0] size of the shadow edge smoothing
