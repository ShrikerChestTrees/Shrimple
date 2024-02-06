#define RENDER_SHADOW_DH
#define RENDER_GEOMETRY

layout(triangles) in;
layout(triangle_strip, max_vertices=12) out;

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in VertexData {
    vec4 color;
    float cameraViewDist;

    flat uint materialId;
} vIn[];

out VertexData {
    vec4 color;
    float cameraViewDist;

    flat uint materialId;

    #if defined RENDER_SHADOWS_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
        flat vec2 shadowTilePos;
    #endif
} vOut;

uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform float far;

#ifdef RENDER_SHADOWS_ENABLED
    uniform mat4 gbufferProjection;
    uniform mat4 shadowModelView;
    uniform float dhFarPlane;
    uniform float near;
#endif

#ifdef IRIS_FEATURE_SSBO
    #include "/lib/buffers/scene.glsl"
#endif

#ifdef RENDER_SHADOWS_ENABLED
    #include "/lib/utility/matrix.glsl"
    #include "/lib/buffers/shadow.glsl"
    #include "/lib/shadows/common.glsl"

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/cascaded/common.glsl"
    #else
        #include "/lib/shadows/distorted/common.glsl"
    #endif
#endif


#if defined WORLD_SHADOW_ENABLED && SHADOW_TYPE == SHADOW_TYPE_CASCADED
    // returns: tile [0-3] or -1 if excluded
    int GetShadowRenderTile(const in vec3 blockPos) {
        const int max = 4;

        for (int i = 0; i < max; i++) {
            if (CascadeContainsPosition(blockPos, i, 3.0)) return i;
        }

        return -1;
    }
#endif

void main() {
    // float minDist = vIn[0].cameraViewDist;
    // minDist = min(minDist, vIn[1].cameraViewDist);
    // minDist = min(minDist, vIn[2].cameraViewDist);
    // if (minDist < 0.5 * min(shadowDistance, far)) return;

    #ifdef RENDER_SHADOWS_ENABLED
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            vec3 originShadowViewPos = (gl_in[0].gl_Position.xyz + gl_in[1].gl_Position.xyz + gl_in[2].gl_Position.xyz) * rcp(3.0);

            int shadowTile = GetShadowRenderTile(originShadowViewPos);
            if (shadowTile < 0) return;

            #ifdef SHADOW_CSM_OVERLAP
                int cascadeMin = max(shadowTile - 1, 0);
                int cascadeMax = min(shadowTile + 1, 3);
            #else
                int cascadeMin = shadowTile;
                int cascadeMax = shadowTile;
            #endif

            for (int c = cascadeMin; c <= cascadeMax; c++) {
                if (c != shadowTile) {
                    #ifdef SHADOW_CSM_OVERLAP
                        // duplicate geometry if intersecting overlapping cascades
                        if (!CascadeContainsPosition(originShadowViewPos, c, 9.0)) continue;
                    #else
                        continue;
                    #endif
                }

                vec2 shadowTilePos = shadowProjectionPos[c];

                for (int v = 0; v < 3; v++) {
                    vOut.shadowTilePos = shadowTilePos;

                    vOut.color = vIn[v].color;
                    vOut.materialId = vIn[v].materialId;
                    vOut.cameraViewDist = vIn[v].cameraViewDist;

                    gl_Position = cascadeProjection[c] * gl_in[v].gl_Position;

                    gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
                    gl_Position.xy = gl_Position.xy * 0.5 + shadowTilePos;
                    gl_Position.xy = gl_Position.xy * 2.0 - 1.0;

                    EmitVertex();
                }

                EndPrimitive();
            }
        #else
            for (int v = 0; v < 3; v++) {
                vOut.color = vIn[v].color;
                vOut.materialId = vIn[v].materialId;
                vOut.cameraViewDist = vIn[v].cameraViewDist;

                #ifdef IRIS_FEATURE_SSBO
                    gl_Position = shadowProjectionEx * gl_in[v].gl_Position;
                #else
                    gl_Position = gl_ProjectionMatrix * gl_in[v].gl_Position;
                #endif

                gl_Position.xyz = distort(gl_Position.xyz);

                EmitVertex();
            }

            EndPrimitive();
        #endif
    #endif
}