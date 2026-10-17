// Solace - user options (parsed by Iris for the settings menu)
#define CEL_BANDS 3 // [2 3 4 5]
#define CEL_EDGE 0.06 // [0.01 0.03 0.06 0.1 0.15 0.2]
#define SHADOWS
#define SHADOW_SOFTNESS 1 // [0 1 2]
#define SHADOW_TINT_R 0.36 // [0.24 0.30 0.36 0.42 0.50]
#define SHADOW_TINT_G 0.40 // [0.28 0.34 0.40 0.46 0.52]
#define SHADOW_TINT_B 0.54 // [0.40 0.47 0.54 0.62 0.70]
#define OUTLINES
//#define OUTLINE_NORMALS // also ink block-grid/normal edges
#define OUTLINE_THICKNESS 1.0 // [0.5 1.0 1.5 2.0 3.0]
#define OUTLINE_STRENGTH 0.90 // [0.25 0.5 0.7 0.85 1.0]
#define OUTLINE_R 0.10 // [0.0 0.06 0.10 0.15 0.3 0.5]
#define OUTLINE_G 0.10 // [0.0 0.05 0.10 0.15 0.3 0.5]
#define OUTLINE_B 0.165 // [0.0 0.10 0.165 0.2 0.3 0.5]
#define OUTLINE_FADE 128.0 // [32.0 64.0 96.0 128.0 160.0 256.0]
#define AMBIENT_BOOST 1.35 // [1.0 1.15 1.35 1.5 1.7]
#define FOLIAGE_LIME 0.45 // [0.0 0.2 0.45 0.6 0.8]
#define SATURATION 1.25 // [1.0 1.1 1.25 1.4 1.6]
#define WARM_SAT_LIMIT 0.55 // [0.0 0.25 0.55 0.8 1.0]
#define LUMA_CAP 0.86 // [0.76 0.82 0.86 0.92 1.00]
#define VIBRANCE 0.30 // [0.0 0.15 0.30 0.50 0.75]
#define LIME_GREENS 0.12 // [0.0 0.06 0.12 0.2 0.35]
#define WARMTH 0.15 // [0.0 0.08 0.15 0.30 0.45]
#define WATER_WAVES
#define WATER_FOAM
#define WATER_SPARKLE
#define SCENE_TINT 0.5 // [0.0 0.25 0.5 0.75 1.0]
#define DISTANCE_FOG
#define FOG_STRENGTH 0.5 // [0.0 0.25 0.5 0.75 1.0]
#define UNDERWATER_FOG 0.6 // [0.2 0.4 0.6 0.8 1.0]
#define SKY_BANDS 6 // [3 4 6 8 12]

const int shadowMapResolution = 1024; // [512 1024 2048]
const float shadowDistance = 64.0; // [48.0 64.0 96.0 128.0]
const float sunPathRotation = -25.0;
