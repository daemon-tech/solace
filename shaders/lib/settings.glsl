// Solace - user options (parsed by Iris for the settings menu)
#define CEL_BANDS 3 // [2 3 4 5]
#define CEL_EDGE 0.06 // [0.01 0.03 0.06 0.1 0.15 0.2]
#define SHADOWS
#define SHADOW_SOFTNESS 1 // [0 1 2]
#define SHADOW_TINT_R 0.40 // [0.30 0.36 0.40 0.46 0.50]
#define SHADOW_TINT_G 0.43 // [0.34 0.40 0.43 0.48 0.52]
#define SHADOW_TINT_B 0.54 // [0.44 0.50 0.54 0.62 0.70]
#define OUTLINES
#define WATER_SAT 0.95 // [0.6 0.75 0.85 0.95 1.1]
#define WATER_BRIGHT 1.0 // [0.85 1.0 1.15 1.3]
#define GROUND_GRADE // grass ground graded toward target hue, flat soft light
#define GROUND_GRADE_STRENGTH 0.6 // [0.3 0.45 0.6 0.75 0.9]
#define GRASS_SMOOTH 0.8 // [0.0 0.4 0.6 0.8 1.0] low-pass grass top texture detail
#define FOLIAGE_SMOOTH 0.65 // [0.0 0.35 0.5 0.65 0.85] smooth leaf masses instead of checker noise
#define HIDE_LEAF_LITTER // leaf litter specks off (smooth even ground)
#define GRASS_SWAY 0.10 // [0.0 0.05 0.10 0.15]
#define GRASS_SWAY_SPEED 1.2 // [0.6 1.2 2.0]
#define WATER_OPACITY 1.0 // [0.6 0.8 1.0 1.2]
#define WATER_DEPTH_TINT 0.85 // [0.4 0.55 0.7 0.85]
#define EDGE_STYLE 1 // [0 1 2] 0 off, 1 soft coloured edges, 2 black ink
#define SOFT_EDGE_STRENGTH 0.45 // [0.2 0.3 0.45 0.6 0.8]
#define STYLE 1 // [0 1] 0 Normal (vanilla-like packs), 1 Cartoony
#if STYLE == 1
#define STYLE_K 1.0
#else
#define STYLE_K 0.55
#endif
//#define OUTLINE_NORMALS // inner block edges (normal Sobel)
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
#define LIME_GREENS 0.38 // [0.0 0.06 0.12 0.25 0.30 0.38 0.45]
#define WARMTH 0.15 // [0.0 0.08 0.15 0.30 0.45]
#define WATER_WAVES
#define WATER_FOAM
#define WATER_SPARKLE
#define SCENE_TINT 0.6 // [0.0 0.25 0.5 0.6 0.75 1.0]
#define DUSK_TINT 1.0 // [0.0 0.25 0.5 0.85 1.0]
#define BLOOM
#define GODRAYS
#define GODRAYS_STRENGTH 0.35 // [0.0 0.2 0.35 0.5 0.7]
#define CANOPY_GLOW 0.12 // [0.0 0.06 0.12 0.2 0.3]
#define BLOOM_STRENGTH 0.6 // [0.0 0.3 0.6 0.9 1.2]
#define HAZE 0.22 // [0.0 0.1 0.18 0.22 0.3 0.45]
#define SAND_BOOST 0.8 // [0.0 0.4 0.8 1.0]
#define DISTANCE_FOG
#define FOG_STRENGTH 0.55 // [0.0 0.25 0.55 0.75 1.0]
#define UNDERWATER_FOG 0.6 // [0.2 0.4 0.6 0.8 1.0]
#define SKY_BANDS 6 // [3 4 6 8 12]

const int shadowMapResolution = 1024; // [512 1024 2048]
const float shadowDistance = 64.0; // [48.0 64.0 96.0 128.0]
const float sunPathRotation = -25.0;
