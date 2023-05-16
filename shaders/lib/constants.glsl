#define AMBIENT_NONE 0
#define AMBIENT_DEFAULT 1
#define AMBIENT_FANCY 2

#define PUDDLES_NONE 0
#define PUDDLES_BASIC 1
#define PUDDLES_PIXEL 2
#define PUDDLES_FANCY 3

#define WATER_TEXTURED 0
#define WATER_COLORED 1

#define WATER_WAVES_NONE 0
#define WATER_WAVES_BASIC 1
#define WATER_WAVES_FANCY 2

#define SHADOW_TYPE_NONE 0
//#define SHADOW_TYPE_BASIC 1
#define SHADOW_TYPE_DISTORTED 2
#define SHADOW_TYPE_CASCADED 3

#define SHADOW_FILTER_NONE 0
#define SHADOW_FILTER_PCF 1
#define SHADOW_FILTER_PCSS 2

#define SHADOW_COLOR_DISABLED 0
#define SHADOW_COLOR_ENABLED 1
#define SHADOW_COLOR_IGNORED 2

#define NORMALMAP_NONE 0
#define NORMALMAP_GENERATED 1
#define NORMALMAP_LABPBR 2
#define NORMALMAP_OLDPBR 3

#define EMISSION_NONE 0
#define EMISSION_LABPBR 1
#define EMISSION_OLDPBR 2

#define SSS_NONE 0
#define SSS_DEFAULT 1
#define SSS_LABPBR 2

#define POROSITY_NONE 0
#define POROSITY_DEFAULT 1
#define POROSITY_LABPBR 2

#define OCCLUSION_NONE 0
#define OCCLUSION_DEFAULT 1
#define OCCLUSION_LABPBR 2

#define SPECULAR_NONE 0
#define SPECULAR_DEFAULT 1
#define SPECULAR_LABPBR 2
#define SPECULAR_OLDPBR 3

#define PARALLAX_NONE 0
#define PARALLAX_NORMAL 1
#define PARALLAX_SMOOTH 2
#define PARALLAX_SHARP 3

#define DYN_LIGHT_NONE 0
#define DYN_LIGHT_VERTEX 1
#define DYN_LIGHT_PIXEL 2
#define DYN_LIGHT_TRACED 3

#define LIGHT_TYPE_POINT 0
#define LIGHT_TYPE_AREA 1

#define DYN_LIGHT_COLOR_HC 0
#define DYN_LIGHT_COLOR_RP 1

#define DYN_LIGHT_TRACE_DDA 0
#define DYN_LIGHT_TRACE_RAY 1

#define DYN_LIGHT_BLOCK_NONE 0
#define DYN_LIGHT_BLOCK_EMIT 1
#define DYN_LIGHT_BLOCK_TRACE 2

#define PLAYER_SHADOW_NONE 0
#define PLAYER_SHADOW_BOX 1
#define PLAYER_SHADOW_CYLINDER 2

#define LIGHT_TINT_NONE 0
#define LIGHT_TINT_BASIC 1
#define LIGHT_TINT_ABSORB 2

#define VOLUMETRIC_BLOCK_NONE 0
#define VOLUMETRIC_BLOCK_EMIT 1
#define VOLUMETRIC_BLOCK_TRACE_FAST 2
#define VOLUMETRIC_BLOCK_TRACE_FULL 3

#define BLOCK_EMPTY 0
#define BLOCK_SOLID 0xFFFF
#define LIGHT_EMPTY 0
#define ENTITY_PHYSICSMOD_SNOW 829925

#define DEBUG_VIEW_NONE 0
#define DEBUG_VIEW_DEFERRED_COLOR 1
#define DEBUG_VIEW_DEFERRED_NORMAL_GEO 2
#define DEBUG_VIEW_DEFERRED_LIGHTING 3
#define DEBUG_VIEW_DEFERRED_SHADOW 4
#define DEBUG_VIEW_DEFERRED_FOG 5
#define DEBUG_VIEW_DEFERRED_NORMAL_TEX 6
#define DEBUG_VIEW_DEFERRED_ROUGH_METAL 7
#define DEBUG_VIEW_DEFERRED_VL 8
#define DEBUG_VIEW_BLOCK_DIFFUSE 9
#define DEBUG_VIEW_BLOCK_SPECULAR 10
#define DEBUG_VIEW_SHADOW_COLOR 11
#define DEBUG_VIEW_BLOOM_TILES 12
#define DEBUG_VIEW_WHITEWORLD 13

#define BUFFER_DEFERRED_COLOR colortex1
#define BUFFER_DEFERRED_SHADOW colortex2
#define BUFFER_DEFERRED_DATA colortex3
#define BUFFER_BLOCK_DIFFUSE colortex4
#define BUFFER_LIGHT_NORMAL colortex5
#define BUFFER_LIGHT_DEPTH colortex6
#define BUFFER_LIGHT_TA colortex7
#define BUFFER_LIGHT_TA_NORMAL colortex8
#define BUFFER_LIGHT_TA_DEPTH colortex9
#define BUFFER_VL colortex10
#define BUFFER_BLOCK_SPECULAR colortex11
#define BUFFER_TA_SPECULAR colortex12
#define BUFFER_ROUGHNESS colortex14
#define BUFFER_BLOOM_TILES colortex15

#define TEX_LIGHTMAP colortex13
#define TEX_RIPPLES colortex13
#define TEX_LIGHT_NOISE noisetex
