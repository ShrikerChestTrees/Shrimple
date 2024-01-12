#define SKY_LIGHT_COLOR_DAY_R 232 // [0]
#define SKY_LIGHT_COLOR_DAY_G 230 // [0]
#define SKY_LIGHT_COLOR_DAY_B 221 // [0]

#define SKY_LIGHT_COLOR_HORIZON_R 207 // [0]
#define SKY_LIGHT_COLOR_HORIZON_G 138 // [0]
#define SKY_LIGHT_COLOR_HORIZON_B 31  // [0]

#define SKY_LIGHT_COLOR_NIGHT_R 220 // [0]
#define SKY_LIGHT_COLOR_NIGHT_G 219 // [0]
#define SKY_LIGHT_COLOR_NIGHT_B 210 // [0]

const vec3 worldSunColor     = _RGBToLinear(vec3(SKY_LIGHT_COLOR_DAY_R, SKY_LIGHT_COLOR_DAY_G, SKY_LIGHT_COLOR_DAY_B) / 255.0);
const vec3 worldHorizonColor = _RGBToLinear(vec3(SKY_LIGHT_COLOR_HORIZON_R, SKY_LIGHT_COLOR_HORIZON_G, SKY_LIGHT_COLOR_HORIZON_B) / 255.0);
const vec3 worldMoonColor    = _RGBToLinear(vec3(SKY_LIGHT_COLOR_NIGHT_R, SKY_LIGHT_COLOR_NIGHT_G, SKY_LIGHT_COLOR_NIGHT_B) / 255.0);

// const float phaseAir = 0.25;
// const float AirAmbientF = 0.0;
// float AirScatterF = mix(0.002, 0.004, skyRainStrength);
// float AirExtinctF = mix(0.001, 0.008, skyRainStrength);

const float LightningRangeInv = rcp(200.0);
const float LightningBrightness = 20.0;


float GetSkyHorizonF(const in float celestialUpF) {
    //float horizonF = smoothstep(0.0, 0.6, abs(celestialUpF + 0.12));
    float horizonF = abs(celestialUpF + 0.12);
    return 1.0 - saturate(horizonF);
}

vec3 GetSkySunColor(const in float sunUpF) {
    float horizonF = GetSkyHorizonF(sunUpF);
    return mix(worldSunColor, worldHorizonColor, horizonF);
}

vec3 GetSkyMoonColor(const in float moonUpF) {
    float horizonF = GetSkyHorizonF(moonUpF);
    return mix(worldMoonColor, worldHorizonColor, horizonF);
}

#if !defined IRIS_FEATURE_SSBO || defined RENDER_BEGIN
    vec3 CalculateSkyLightColor(const in vec3 sunDir) {
        vec3 skyLightColor = sunDir.y > 0.0 ? worldSunColor : worldMoonColor;

        float sunF = smoothstep(-0.1, 0.2, sunDir.y);
        float brightness = mix(WorldMoonBrightnessF, WorldSunBrightnessF, sunF);

        float horizonF = GetSkyHorizonF(sunDir.y);
        skyLightColor = mix(skyLightColor, worldHorizonColor, horizonF) * brightness;

        #if MC_VERSION > 11900
            skyLightColor *= (1.0 - 0.99*smootherstep(darknessFactor));// + 0.04 * smootherstep(darknessLightFactor);
        #endif

        return skyLightColor;
    }
#endif

vec3 CalculateSkyLightWeatherColor(const in vec3 skyLightColor) {
    return skyLightColor * (1.0 - 0.8*skyRainStrength);
}

#ifndef RENDER_BEGIN
    vec3 GetSkyLightColor(const in vec3 sunDir) {
        #ifdef IRIS_FEATURE_SSBO
            return WorldSkyLightColor;
        #else
            return CalculateSkyLightColor(sunDir);
        #endif
    }

    vec3 GetSkyLightColor() {
        #ifdef IRIS_FEATURE_SSBO
            return WorldSkyLightColor;
        #else
            vec3 localSunDirection = normalize((gbufferModelViewInverse * vec4(sunPosition, 1.0)).xyz);
            return CalculateSkyLightColor(localSunDirection);
        #endif
    }

    // vec3 GetSkyLightWeatherColor(const in vec3 skyLightColor) {
    //     #ifdef IRIS_FEATURE_SSBO
    //         return WeatherSkyLightColor;
    //     #else
    //         return CalculateSkyLightWeatherColor(skyLightColor);
    //     #endif
    // }
#endif
