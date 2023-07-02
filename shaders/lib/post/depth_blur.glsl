mat2 GetBlurRotation() {
    float dither = InterleavedGradientNoise(gl_FragCoord.xy);

    float angle = dither * TAU;
    float s = sin(angle), c = cos(angle);
    return mat2(c, -s, s, c);
}

vec3 GetBlur(const in sampler2D depthSampler, const in vec2 texcoord, const in float fragDepthL, const in float minDepth, const in float viewDist, const in bool isWater) {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 pixelSize = rcp(viewSize);

    #if defined WATER_BLUR && DIST_BLUR_MODE == DIST_BLUR_NONE
        if (!isWater) return texelFetch(BUFFER_FINAL, ivec2(texcoord * viewSize), 0).rgb;
    #endif

    float distScale = isWater ? DIST_BLUR_SCALE_WATER : far;
    distScale = mix(distScale, DIST_BLUR_SCALE_BLIND, blindness);

    float distF = 0.0;
    #if DIST_BLUR_MODE == DIST_BLUR_DOF
        float centerDepthL = linearizeDepthFast(centerDepthSmooth, near, far);
        centerDepthL = clamp(centerDepthL, near, far);

        distF = abs(viewDist - centerDepthL);
        bool distSign = viewDist >= centerDepthL;
        float minScale = max(centerDepthL, 1.0);
        float distScaleDOF = distSign ? max(far - centerDepthL, minScale) : max(centerDepthL, 1.0);
        distF = min(distF / distScaleDOF, 1.0);
    #elif DIST_BLUR_MODE == DIST_BLUR_FAR
        if (!isWater) distF = min(viewDist / far, 1.0);
    #endif

    #ifdef WATER_BLUR
        if (isWater) {
            float waterDistF = min(viewDist / DIST_BLUR_SCALE_WATER, 1.0);
            distF = max(distF, waterDistF);
        }
    #endif

    //distF = smoothstep(0.0, 1.0, distF);
    //distF = pow(distF, 1.2);

    uint sampleCount = 1;
    //if (distScale > EPSILON)
        sampleCount = uint(ceil(DIST_BLUR_SAMPLES * distF));

    const float goldenAngle = PI * (3.0 - sqrt(5.0));
    const float PHI = (1.0 + sqrt(5.0)) / 2.0;

    mat2 rotation = GetBlurRotation();
    float radius = distF * DIST_BLUR_RADIUS;

    //float sampleLod = max(distF - 0.5, 0.0);

    vec3 color = vec3(0.0);
    float maxWeight = 0.0;

    for (uint i = 0; i < min(sampleCount, DIST_BLUR_SAMPLES); i++) {
        vec2 sampleCoord = texcoord;
        vec2 diskOffset = vec2(0.0);

        if (sampleCount > 1) {
            float r = sqrt((i + 0.5) / sampleCount);
            float theta = i * goldenAngle + PHI;
            
            float sine = sin(theta);
            float cosine = cos(theta);
            
            diskOffset = rotation * (vec2(cosine, sine) * r);
            sampleCoord = saturate(sampleCoord + diskOffset * radius * pixelSize);
        }

        ivec2 sampleUV = ivec2(sampleCoord * viewSize);

        float sampleDepth = texelFetch(depthSampler, sampleUV, 0).r;
        //float sampleDepth = textureLod(depthSampler, sampleCoord, 0.0).r;
        float sampleDepthL = linearizeDepthFast(sampleDepth, near, far);
        sampleDepthL = clamp(sampleDepthL, near, far);
        //sampleDepthL = max(sampleDepthL - minDepth, 0.0);

        float sampleDistF = 0.0;
        #if DIST_BLUR_MODE == DIST_BLUR_DOF
            sampleDistF = abs(sampleDepthL - centerDepthL);
            bool sampleDistSign = sampleDepthL >= centerDepthL;
            float sampleDistScaleDOF = max(sampleDistSign ? (far - centerDepthL) : centerDepthL, 1.0);
            sampleDistF = saturate(sampleDistF / sampleDistScaleDOF);

            if (sampleDistSign && !distSign) sampleDistF = 0.0;
        #elif DIST_BLUR_MODE == DIST_BLUR_FAR
            //float distF = min(viewDist / distScale, 1.0);
            if (!isWater) sampleDistF = saturate((sampleDepthL - minDepth) / far);
            
            //float minSampleDepthL = min(fragDepthL, sampleDepthL);
        #endif

        #ifdef WATER_BLUR
            if (isWater) {
                float sampleWaterDistF = saturate((sampleDepthL - minDepth) / DIST_BLUR_SCALE_WATER);
                sampleDistF = sampleWaterDistF;//max(sampleDistF, sampleWaterDistF);
            }
        #endif

        sampleDistF = min(sampleDistF, distF);
        //sampleDistF = smoothstep(0.0, 1.0, sampleDistF);

        //float sampleDistF = min(minSampleDepthL / distScale, 1.0);
        float sampleLod = max(sampleDistF - 0.5, 0.0);

        //vec3 sampleColor = texelFetch(BUFFER_FINAL, sampleUV, 0).rgb;
        vec3 sampleColor = textureLod(BUFFER_FINAL, sampleCoord, sampleLod).rgb;
        float sampleWeight = exp(-3.0 * length2(diskOffset));

        if (sampleCount > 1) {
            #ifdef RENDER_TRANSLUCENT_POST_BLUR
                float sampleWeatherDepth = texelFetch(BUFFER_WEATHER_DEPTH, sampleUV, 0).r;
                sampleDepth = min(sampleDepth, sampleWeatherDepth);
            #endif

            sampleWeight *= step(minDepth, sampleDepth) * sampleDistF;

            //float minSampleDepth = max(min(fragDepthL, sampleDepthL) - minDepth, 0.0);
            //sampleWeight *= min(minSampleDepthL / distScale, 1.0);
        }

        color += sampleColor * sampleWeight;
        maxWeight += sampleWeight;
    }

    if (maxWeight < 1.0) {
        color += texelFetch(BUFFER_FINAL, ivec2(texcoord * viewSize), 0).rgb * (1.0 - maxWeight);
    }
    else {
        color /= maxWeight;
    }

    return color;
}