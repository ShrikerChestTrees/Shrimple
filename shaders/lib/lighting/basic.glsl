#if defined IRIS_FEATURE_SSBO && DYN_LIGHT_MODE != DYN_LIGHT_NONE
    // float G(const in float NoV, const in float k) {
    //     return rcp(NoV * (1.0 - k) + k);
    // }

    // float GGX(vec3 N, vec3 V, vec3 L, float roughness, float F0) {
    //     vec3 H = normalize(V + L);
    //     float NoL = saturate(dot(N, L));
    //     float NoV = saturate(dot(N, V));
    //     float NoH = saturate(dot(N, H));
    //     float LoH = saturate(dot(L, H));

    //     float alpha = pow2(roughness);
    //     float a2 = pow2(alpha);
    //     float k = alpha * 0.5;

    //     float denom = pow2(NoH) * (a2 - 1.0) + 1.0;
    //     float D = a2 / (PI * denom * denom);

    //     float F = F0 + (1.0 - F0) * pow(1.0 - LoH, 5.0);

    //     return NoL * D * F * G(NoL, k) * G(NoV, k);
    // }

    float GetLightNoL(const in vec3 localNormal, const in vec3 texNormal, const in vec3 lightDir, const in float sss) {
        float NoL = 1.0;

        #if DYN_LIGHT_DIRECTIONAL > 0 || DYN_LIGHT_MODE == DYN_LIGHT_TRACED
            if (dot(localNormal, localNormal) > EPSILON)
                NoL = dot(localNormal, lightDir);

            if (dot(texNormal, texNormal) > EPSILON) {
                float texNoL = dot(texNormal, lightDir);
                NoL = min(NoL, texNoL);
            }
        #endif

        #if MATERIAL_SSS != SSS_NONE
            NoL = mix(max(NoL, 0.0), abs(NoL), sss);
        #else
            NoL = max(NoL, 0.0);
        #endif

        #if DYN_LIGHT_MODE != DYN_LIGHT_TRACED
            NoL = mix(1.0, NoL, DynamicLightDirectionalF);
        #endif

        return NoL;
    }

    float SampleLightDiffuse(const in float NoLm, const in float F) {
        // float lightAtt = 1.0 - saturate(lightDist / lightRange);
        // lightAtt = pow(lightAtt, 5.0);

        return NoLm * (1.0 - F);
    }

    float SampleLightSpecular(const in float NoVm, const in float NoLm, const in float NoHm, const in float F, const in float roughL) {
        float a = NoHm * roughL;
        float k = roughL / (1.0 - pow2(NoHm) + pow2(a));
        float D = min(pow2(k) * rcp(PI), 65504.0);

        float GGX_V = NoLm * (NoVm * (1.0 - roughL) + roughL);
        float GGX_L = NoVm * (NoLm * (1.0 - roughL) + roughL);
        float G = saturate(0.5 / (GGX_V + GGX_L));

        return D * G * F;
    }

    void SampleDynamicLighting(inout vec3 blockDiffuse, inout vec3 blockSpecular, const in float roughL, const in vec3 localPos, const in vec3 localNormal, const in vec3 texNormal, const in float sss, const in vec3 blockLightDefault) {
        uint gridIndex;
        vec3 lightFragPos = localPos + 0.06 * localNormal;
        uint lightCount = GetSceneLights(lightFragPos, gridIndex);

        if (gridIndex != DYN_LIGHT_GRID_MAX) {
            #if defined RENDER_TEXTURED || defined RENDER_PARTICLES
                bool hasGeoNormal = false;
            #else
                bool hasGeoNormal = true;
            #endif

            #ifdef MATERIAL_SPECULAR
                vec3 localViewDir = -normalize(localPos);
                float lightNoVm = max(dot(texNormal, localViewDir), EPSILON);
            #endif

            blockDiffuse = vec3(0.0);

            for (uint i = 0u; i < lightCount; i++) {
                SceneLightData light = GetSceneLight(gridIndex, i);

                vec3 lightPos = light.position;
                vec3 lightColor = light.color;

                #if DYN_LIGHT_MODE == DYN_LIGHT_TRACED
                    #if DYN_LIGHT_TRACE_MODE == DYN_LIGHT_TRACE_DDA && DYN_LIGHT_PENUMBRA > 0 && !defined RENDER_TRANSLUCENT
                        float size = ((light.data >> 8u) & 31u) / 31.0;
                        size *= 0.5 * DynamicLightPenumbraF;

                        vec3 offset = GetLightPenumbraOffset() * size;
                        lightColor *= max(1.0 - 2.0*dot(offset, offset), 0.0);
                        lightPos += offset;
                    #endif

                    vec3 lightVec = lightFragPos - lightPos;
                    uint traceFace = 1u << GetLightMaskFace(lightVec);
                    if ((light.data & traceFace) == traceFace) continue;
                    if (dot(lightVec, lightVec) >= pow2(light.range)) continue;
                #else
                    vec3 lightVec = lightFragPos - lightPos;
                #endif

                #if DYN_LIGHT_MODE == DYN_LIGHT_TRACED && defined RENDER_FRAG
                    if ((light.data & 1u) == 1u) {
                        vec3 traceOrigin = GetLightGridPosition(lightPos);
                        vec3 traceEnd = traceOrigin + 0.99*lightVec;

                        #if DYN_LIGHT_TRACE_METHOD == DYN_LIGHT_TRACE_RAY
                            lightColor *= TraceRay(traceOrigin, traceEnd, light.range);
                        #else
                            lightColor *= TraceDDA(traceEnd, traceOrigin, light.range);
                        #endif
                    }
                #endif

                vec3 lightDir = normalize(-lightVec);
                float lightNoLm = GetLightNoL(localNormal, texNormal, lightDir, sss);

                if (lightNoLm > EPSILON) {
                    float lightDist = length(lightVec);
                    float lightAtt = 1.0 - saturate(lightDist / light.range);
                    lightAtt = pow(lightAtt, 5.0);

                    float F = 0.0;
                    #ifdef MATERIAL_SPECULAR
                        const float f0 = 0.04;

                        vec3 lightH = normalize(lightDir + localViewDir);
                        float lightVoHm = max(dot(localViewDir, lightH), EPSILON);

                        float invCosTheta = 1.0 - lightVoHm;
                        F = f0 + (max(1.0 - roughL, f0) - f0) * pow5(invCosTheta);
                    #endif

                    blockDiffuse += SampleLightDiffuse(lightNoLm, F) * lightAtt * lightColor;

                    #ifdef MATERIAL_SPECULAR
                        float lightNoHm = max(dot(texNormal, lightH), EPSILON);

                        blockSpecular += SampleLightSpecular(lightNoVm, lightNoLm, lightNoHm, F, roughL) * lightAtt * lightColor;
                    #endif
                }
            }

            blockDiffuse *= DynamicLightBrightness;
            blockSpecular *= DynamicLightBrightness;

            // #if DYN_LIGHT_MODE != DYN_LIGHT_TRACED
            //     accumDiffuse *= blockLight;
            // #endif

            #ifdef DYN_LIGHT_FALLBACK
                // TODO: shrink to shadow bounds
                vec3 offsetPos = localPos + LightGridCenter;
                //vec3 maxSize = SceneLightSize
                float fade = minOf(min(offsetPos, SceneLightSize - offsetPos)) / 8.0;
                blockDiffuse = mix(blockLightDefault, blockDiffuse, saturate(fade));
                blockSpecular = mix(vec3(0.0), blockSpecular, saturate(fade));
            #endif
        }
        else {
            #ifdef DYN_LIGHT_FALLBACK
                blockDiffuse += blockLightDefault;
            //#else
            //    blockDiffuse = vec3(0.0);
            #endif
        }
    }

    void SampleHandLight(inout vec3 blockDiffuse, inout vec3 blockSpecular, const in vec3 fragLocalPos, const in vec3 fragLocalNormal, const in vec3 texNormal, const in float roughL, const in float sss) {
        vec2 noiseSample = GetDynLightNoise(vec3(0.0));
        vec3 result = vec3(0.0);

        //if (heldItemId == 115) return vec3(1.0);

        vec3 lightFragPos = fragLocalPos + 0.06 * fragLocalNormal;

        #ifdef MATERIAL_SPECULAR
            vec3 localViewDir = -normalize(fragLocalPos);
            float lightNoVm = max(dot(texNormal, localViewDir), 0.0);
        #endif

        if (heldBlockLightValue > 0) {
            vec3 lightLocalPos = (gbufferModelViewInverse * vec4(HandLightOffsetR, 1.0)).xyz;
            if (!firstPersonCamera) lightLocalPos += eyePosition - cameraPosition;
            //if (!firstPersonCamera) lightLocalPos = HandLightPos1;

            vec3 lightVec = lightLocalPos - lightFragPos;
            if (dot(lightVec, lightVec) < pow2(heldBlockLightValue)) {
                vec3 lightColor = GetSceneItemLightColor(heldItemId, noiseSample);

                #if DYN_LIGHT_MODE == DYN_LIGHT_TRACED && defined RENDER_FRAG
                    vec3 traceOrigin = GetLightGridPosition(lightLocalPos);
                    vec3 traceEnd = traceOrigin - 0.99*lightVec;

                    #if DYN_LIGHT_TRACE_MODE == DYN_LIGHT_TRACE_DDA && DYN_LIGHT_PENUMBRA > 0 && !defined RENDER_TRANSLUCENT
                        float lightSize = GetSceneItemLightSize(heldItemId);
                        //ApplyLightPenumbraOffset(traceOrigin, lightSize * 0.5);
                        vec3 offset = GetLightPenumbraOffset();
                        lightColor *= 1.0 - length(offset);
                        traceOrigin += offset * lightSize * 0.5;
                    #endif

                    #if DYN_LIGHT_TRACE_METHOD == DYN_LIGHT_TRACE_RAY
                        lightColor *= TraceRay(traceOrigin, traceEnd, heldBlockLightValue);
                    #else
                        lightColor *= TraceDDA(traceEnd, traceOrigin, heldBlockLightValue);
                    #endif
                #endif

                vec3 lightDir = normalize(lightVec);
                float lightNoLm = GetLightNoL(fragLocalNormal, texNormal, lightDir, sss);

                if (lightNoLm > EPSILON) {
                    float lightDist = length(lightVec);
                    float lightAtt = 1.0 - saturate(lightDist / heldBlockLightValue);
                    lightAtt = pow(lightAtt, 5.0);

                    float F = 0.0;
                    #ifdef MATERIAL_SPECULAR
                        const float f0 = 0.04;

                        vec3 lightH = normalize(lightDir + localViewDir);
                        float lightVoHm = max(dot(localViewDir, lightH), EPSILON);

                        float invCosTheta = 1.0 - lightVoHm;
                        F = f0 + (max(1.0 - roughL, f0) - f0) * pow5(invCosTheta);
                    #endif

                    blockDiffuse += SampleLightDiffuse(lightNoLm, F) * lightAtt * lightColor;

                    #ifdef MATERIAL_SPECULAR
                        float lightNoHm = max(dot(texNormal, lightH), 0.0);

                        blockSpecular += SampleLightSpecular(lightNoVm, lightNoLm, lightNoHm, F, roughL) * lightAtt * lightColor;
                    #endif
                }
            }
        }

        if (heldBlockLightValue2 > 0) {
            vec3 lightLocalPos = (gbufferModelViewInverse * vec4(HandLightOffsetL, 1.0)).xyz;
            if (!firstPersonCamera) lightLocalPos += eyePosition - cameraPosition;

            vec3 lightVec = lightLocalPos - lightFragPos;
            if (dot(lightVec, lightVec) < pow2(heldBlockLightValue2)) {
                vec3 lightColor = GetSceneItemLightColor(heldItemId2, noiseSample);

                #if DYN_LIGHT_MODE == DYN_LIGHT_TRACED && defined RENDER_FRAG
                    vec3 traceOrigin = GetLightGridPosition(lightLocalPos);
                    vec3 traceEnd = traceOrigin - 0.99*lightVec;

                    #if DYN_LIGHT_TRACE_MODE == DYN_LIGHT_TRACE_DDA && DYN_LIGHT_PENUMBRA > 0 && !defined RENDER_TRANSLUCENT
                        float lightSize = GetSceneItemLightSize(heldItemId2);
                        //ApplyLightPenumbraOffset(traceOrigin, lightSize * 0.5);
                        vec3 offset = GetLightPenumbraOffset();
                        lightColor *= 1.0 - length(offset);
                        traceOrigin += offset * lightSize * 0.5;
                    #endif

                    #if DYN_LIGHT_TRACE_METHOD == DYN_LIGHT_TRACE_RAY
                        lightColor *= TraceRay(traceOrigin, traceEnd, heldBlockLightValue2);
                    #else
                        lightColor *= TraceDDA(traceEnd, traceOrigin, heldBlockLightValue2);
                    #endif
                #endif
                
                vec3 lightDir = normalize(lightVec);
                float lightNoLm = GetLightNoL(fragLocalNormal, texNormal, lightDir, sss);

                if (lightNoLm > EPSILON) {
                    float lightDist = length(lightVec);
                    float lightAtt = 1.0 - saturate(lightDist / heldBlockLightValue2);
                    lightAtt = pow(lightAtt, 5.0);

                    float F = 0.0;
                    #ifdef MATERIAL_SPECULAR
                        const float f0 = 0.04;

                        vec3 lightH = normalize(lightDir + localViewDir);
                        float lightVoHm = max(dot(localViewDir, lightH), EPSILON);

                        float invCosTheta = 1.0 - lightVoHm;
                        F = f0 + (max(1.0 - roughL, f0) - f0) * pow5(invCosTheta);
                    #endif

                    blockDiffuse += SampleLightDiffuse(lightNoLm, F) * lightAtt * lightColor;

                    #ifdef MATERIAL_SPECULAR
                        float lightNoHm = max(dot(texNormal, lightH), 0.0);

                        blockSpecular += SampleLightSpecular(lightNoVm, lightNoLm, lightNoHm, F, roughL) * lightAtt * lightColor;
                    #endif
                }
            }
        }

        blockDiffuse *= DynamicLightBrightness;
        blockSpecular *= DynamicLightBrightness;
    }
#endif

#ifdef RENDER_VERTEX
    #if defined RENDER_TERRAIN || defined RENDER_WATER
        bool IsFoliageBlock(const in int blockId) {
            bool result = false;

            switch (blockId) {
                case BLOCK_LEAVES:
                
                case BLOCK_ALLIUM:
                case BLOCK_AZURE_BLUET:
                case BLOCK_BEETROOTS:
                case BLOCK_BLUE_ORCHID:
                case BLOCK_CARROTS:
                case BLOCK_CAVE_VINE:
                case BLOCK_CAVEVINE_BERRIES:
                case BLOCK_CORNFLOWER:
                case BLOCK_DANDELION:
                case BLOCK_FERN:
                case BLOCK_GRASS:
                case BLOCK_KELP:
                case BLOCK_LARGE_FERN_LOWER:
                case BLOCK_LARGE_FERN_UPPER:
                case BLOCK_LILAC_LOWER:
                case BLOCK_LILAC_UPPER:
                case BLOCK_LILY_OF_THE_VALLEY:
                case BLOCK_OXEYE_DAISY:
                case BLOCK_PEONY_LOWER:
                case BLOCK_PEONY_UPPER:
                case BLOCK_POPPY:
                case BLOCK_POTATOES:
                case BLOCK_ROSE_BUSH_LOWER:
                case BLOCK_ROSE_BUSH_UPPER:
                case BLOCK_SAPLING:
                case BLOCK_SEAGRASS:
                case BLOCK_SUGAR_CANE:
                case BLOCK_SUNFLOWER_LOWER:
                case BLOCK_SUNFLOWER_UPPER:
                case BLOCK_SWEET_BERRY_BUSH:
                case BLOCK_TALL_GRASS_LOWER:
                case BLOCK_TALL_GRASS_UPPER:
                case BLOCK_TULIP:
                case BLOCK_WHEAT:
                case BLOCK_WITHER_ROSE:
                    result = true;
                    break;
            }

            return result;
        }
    #endif

    void BasicVertex() {
        vec4 pos = gl_Vertex;

        #if defined RENDER_TERRAIN || defined RENDER_WATER
            vBlockId = int(mc_Entity.x + 0.5);

            #ifdef ENABLE_WAVING
                ApplyWavingOffset(pos.xyz, vBlockId);
            #endif
        #endif

        vec4 viewPos = gl_ModelViewMatrix * pos;

        vPos = viewPos.xyz;

        #ifdef RENDER_BILLBOARD
            vec3 vNormal;
            vec3 vLocalNormal;
        #endif

        vNormal = normalize(gl_NormalMatrix * gl_Normal);
        vLocalNormal = mat3(gbufferModelViewInverse) * vNormal;

        #if defined WORLD_SKY_ENABLED && defined WORLD_SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && !defined RENDER_BILLBOARD
            vec3 lightDir = normalize(shadowLightPosition);
            geoNoL = dot(lightDir, vNormal);

            vLit = geoNoL;

            #if defined RENDER_TERRAIN && defined FOLIAGE_UP
                if (IsFoliageBlock(vBlockId))
                    vLit = dot(lightDir, gbufferModelView[1].xyz);
            #endif
        #else
            geoNoL = 1.0;
            vLit = 1.0;
        #endif

        vLocalPos = (gbufferModelViewInverse * viewPos).xyz;
        vBlockLight = vec3(0.0);

        #if defined WORLD_SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                shadowTile = -1;
            #endif

            ApplyShadows(vLocalPos, vLocalNormal, geoNoL);
        #endif

        #if DYN_LIGHT_MODE != DYN_LIGHT_TRACED && !defined RENDER_CLOUDS
            vec3 blockLightDefault = textureLod(lightmap, vec2(lmcoord.x, (0.5/16.0)), 0).rgb;
            blockLightDefault = RGBToLinear(blockLightDefault);

            #if defined IRIS_FEATURE_SSBO && DYN_LIGHT_MODE == DYN_LIGHT_VERTEX && !defined RENDER_BILLBOARD
                #if defined RENDER_TERRAIN || defined RENDER_WATER
                    float sss = GetBlockSSS(vBlockId);
                #else
                    const float sss = 0.0;
                #endif

                const float roughL = 0.2;

                vec3 blockDiffuse = vec3(0.0);
                vec3 blockSpecular = vec3(0.0);
                SampleDynamicLighting(blockDiffuse, blockSpecular, roughL, vLocalPos, vLocalNormal, vec3(0.0), sss, blockLightDefault);
                SampleHandLight(blockDiffuse, blockSpecular, vLocalPos, vLocalNormal, vec3(0.0), roughL, sss);

                vBlockLight += blockDiffuse * saturate((lmcoord.x - (0.5/16.0)) * (16.0/15.0));
            #endif

            #if defined IRIS_FEATURE_SSBO && DYN_LIGHT_MODE != DYN_LIGHT_NONE
                #ifdef RENDER_ENTITIES
                    vec4 light = GetSceneEntityLightColor(entityId);
                    vBlockLight += vec3(light.a / 15.0);
                #elif defined RENDER_HAND
                    // TODO: change ID depending on hand
                    float lightRange = heldBlockLightValue;//GetSceneItemLightRange(heldItemId);
                    vBlockLight += vec3(lightRange / 15.0);
                #elif defined RENDER_TERRAIN || defined RENDER_WATER
                    float lightRange = GetSceneBlockEmission(vBlockId);
                    vBlockLight += vec3(lightRange);
                #endif
            #else
                vBlockLight += blockLightDefault;
            #endif
        #endif

        gl_Position = gl_ProjectionMatrix * viewPos;
    }
#endif

#ifdef RENDER_FRAG
    #if defined RENDER_GBUFFER && !defined RENDER_CLOUDS
        vec4 GetColor() {
            vec4 color = texture(gtexture, texcoord);

            #ifndef RENDER_TRANSLUCENT
                if (color.a < alphaTestRef) {
                    discard;
                    return vec4(0.0);
                }
            #endif

            color.rgb *= glcolor.rgb;

            return color;
        }
    #endif

    //#if defined RENDER_GBUFFER || defined RENDER_DEFERRED || defined RENDER_COMPOSITE
        void GetFinalBlockLighting(inout vec3 blockDiffuse, inout vec3 blockSpecular, const in vec3 localPos, const in vec3 localNormal, const in vec3 texNormal, const in float lmcoordX, const in float roughL, const in float emission, const in float sss) {
            blockDiffuse += vec3(emission);//vBlockLight;

            #ifdef RENDER_GBUFFER
                vec3 blockLightDefault = textureLod(lightmap, vec2(lmcoordX, 1.0/32.0), 0).rgb;
            #else
                vec3 blockLightDefault = textureLod(TEX_LIGHTMAP, vec2(lmcoordX, 1.0/32.0), 0).rgb;
            #endif

            blockLightDefault = RGBToLinear(blockLightDefault);

            #if defined IRIS_FEATURE_SSBO && (DYN_LIGHT_MODE == DYN_LIGHT_PIXEL || DYN_LIGHT_MODE == DYN_LIGHT_TRACED || (DYN_LIGHT_MODE == DYN_LIGHT_VERTEX && (defined RENDER_WEATHER || defined RENDER_DEFERRED))) && !(defined RENDER_CLOUDS || defined RENDER_COMPOSITE)
                SampleDynamicLighting(blockDiffuse, blockSpecular, roughL, localPos, localNormal, texNormal, sss, blockLightDefault);

                SampleHandLight(blockDiffuse, blockSpecular, localPos, localNormal, texNormal, roughL, sss);

                // #if DYN_LIGHT_MODE != DYN_LIGHT_TRACED
                //     lit *= saturate((lmcoordX - (0.5/16.0)) * (16.0/15.0));
                // #endif

                //blockLight += lit;
            #else
                blockDiffuse += blockLightDefault;
            #endif

            #if defined IRIS_FEATURE_SSBO && DYN_LIGHT_MODE != DYN_LIGHT_NONE && !(defined WORLD_SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE) && !(defined RENDER_CLOUDS || defined RENDER_DEFERRED)
                if (gl_FragCoord.x < 0) blockDiffuse = texelFetch(shadowcolor0, ivec2(0.0), 0).rgb;
            #endif
        }

        vec3 GetFinalLighting(in vec3 albedo, const in vec3 blockDiffuse, const in vec3 blockSpecular, const in vec3 shadowColor, const in vec2 lmcoord, const in float roughL, const in float occlusion) {
            // weather darkening
            
            float worldBrightness = GetWorldBrightnessF();

            #ifndef RENDER_CLOUDS
                #ifdef RENDER_GBUFFER
                    vec3 skyLight = textureLod(lightmap, vec2(1.0/32.0, lmcoord.y), 0).rgb;
                #else
                    vec3 skyLight = textureLod(TEX_LIGHTMAP, vec2(1.0/32.0, lmcoord.y), 0).rgb;
                #endif

                skyLight = RGBToLinear(skyLight) * worldBrightness;

                //skyLight = skyLight * (1.0 - ShadowBrightnessF) + (ShadowBrightnessF);

                skyLight *= 1.0 - blindness;
            #else
                const float skyLight = 1.0;
            #endif

            vec3 ambientLight = skyLight;
            #if DYN_LIGHT_MODE != DYN_LIGHT_NONE && defined RENDER_DEFERRED
                vec2 lmFinal = saturate((lmcoord - (0.5/16.0)) / (15.0/16.0));
                lmFinal.x *= 0.16;
                lmFinal = saturate(lmFinal * (15.0/16.0) + (0.5/16.0));

                ambientLight = textureLod(TEX_LIGHTMAP, lmFinal, 0).rgb;
                ambientLight = RGBToLinear(ambientLight);
            #endif

            vec3 skyDiffuse = skyLight * shadowColor;
            vec3 skySpecular = vec3(0.0);

            float shadowingF = 1.0;
            #ifdef WORLD_SKY_ENABLED
                shadowingF = 1.0 - (1.0 - 0.5 * rainStrength) * (1.0 - ShadowBrightnessF);

                skyDiffuse *= 1.0 - shadowingF;

                #ifdef MATERIAL_SPECULAR
                    float skyNoVm = 1.0;
                    float skyNoLm = 1.0;
                    float skyNoHm = 1.0;

                    float skyF = 1.0;

                    skySpecular = vec3(0.0);//SampleLightSpecular(skyNoVm, skyNoLm, skyNoHm, skyF, roughL);
                #endif
            #endif

            vec3 ambient = albedo * ambientLight * occlusion * shadowingF * worldBrightness;
            vec3 diffuse = albedo * (blockDiffuse + skyDiffuse);
            return ambient + diffuse + blockSpecular + skySpecular;
        }
    //#endif
#endif
