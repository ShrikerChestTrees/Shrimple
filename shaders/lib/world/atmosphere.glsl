const float SkyDensityF = SKY_FOG_DENSITY * 0.01;
const float CaveFogDensityF = SKY_CAVE_FOG_DENSITY * 0.01;

#ifdef DISTANT_HORIZONS
    float SkyFar = max(4000.0, dhFarPlane);
#else
    const float SkyFar = 4000.0;
#endif

#ifdef WORLD_SKY_ENABLED
    #if SKY_VOL_FOG_TYPE != VOL_TYPE_NONE
        // float AirDensityF = mix(SkyDensityF, max(SkyDensityF, 0.16), weatherStrength);
        float AirDensityF = mix(SkyDensityF, min(SkyDensityF * 6.0, 1.0), weatherStrength);
    #else
        const float AirDensityF = 0.0;
    #endif

    const float AirDensityRainF = 0.08;
    const vec3 AirScatterColor_rain = _RGBToLinear(vec3(0.1));
    const vec3 AirExtinctColor_rain = _RGBToLinear(1.0 - vec3(0.698, 0.702, 0.722));

    const float AirAmbientF = 0.02;//mix(0.02, 0.0, weatherStrength);
    const vec3 AirScatterColor = _RGBToLinear(vec3(0.5));
    const vec3 AirExtinctColor = _RGBToLinear(1.0 - vec3(0.698, 0.702, 0.722));//mix(0.02, 0.006, weatherStrength);
#else
    const float AirDensityF = SkyDensityF;
    vec3 AirAmbientF = RGBToLinear(fogColor);

    const vec3 AirScatterColor = vec3(0.07);
    const vec3 AirExtinctColor = vec3(0.02);
#endif

#ifdef SKY_CAVE_FOG_ENABLED
    float GetCaveFogF() {
        float eyeLightF = eyeBrightnessSmooth.y / 240.0;
        return 1.0 - smoothstep(0.0, 0.1, eyeLightF);
        //densityFinal = mix(densityFinal, CaveFogDensityF, caveF);
    }
#endif
