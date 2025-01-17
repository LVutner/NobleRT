/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 boxBlur(vec2 coords, sampler2D tex, int size) {
    vec4 color = texture2D(tex, coords);

    int SAMPLES = 1;
    for(int x = -size; x <= size; x++) {
        for(int y = -size; y <= size; y++) {
            vec2 offset = vec2(x, y) * pixelSize;
            color += texture2D(tex, coords + offset);
            SAMPLES++;
        }
    }
    return color / SAMPLES;
}

vec4 bokeh(vec2 coords, sampler2D tex, vec2 resolution, int quality, float radius) {
    vec4 color = texture2D(tex, coords);
    vec2 noise = uniformAnimatedNoise();

    int SAMPLES = 1;
    for(int i = 0; i < quality; i++) {
        for(int j = 0; j < quality; j++) {
            vec2 offset = ((vec2(i, j) + noise) - quality * 0.5) / quality;
            
            if(length(offset) < 0.5) {
                color += texture2D(tex, coords + ((offset * radius) * resolution));
                SAMPLES++;
            }
        }
    }
    return color / SAMPLES;
}

vec4 radialBlur(vec2 coords, sampler2D tex, vec2 resolution, int quality, float size) {
    vec4 color = texture2D(tex, texCoords);
    vec2 radius = size / resolution;

    int SAMPLES = 1;
    for(int i = 0; i < quality; i++){
        float d = (i * PI2) / quality;
        vec2 sampleCoords = coords + vec2(sin(d), cos(d)) * radius;
            
        color += texture2D(tex, sampleCoords);
        SAMPLES++;
    }
    return saturate(color / SAMPLES);
}

const int WEIGHTS0_KERNEL = 49;
const int WEIGHTS1_KERNEL = 11;
const float gaussianWeights0[] = float[](
    0.014692925,
    0.015287874,
    0.015880068,
    0.016467365,
    0.017047564,
    0.017618422,
    0.018177667,
    0.018723012,
    0.019252171,
    0.019762876,
    0.020252889,
    0.020720021,
    0.021162151,
    0.021577234,
    0.021963326,
    0.022318593,
    0.022641326,
    0.022929960,
    0.023183082,
    0.023399442,
    0.023577968,
    0.023717775,
    0.023818168,
    0.023878653,
    0.023898908,
    0.023878653,
    0.023818168,
    0.023717775,
    0.023577968,
    0.023399442,
    0.023183082,
    0.022929960,
    0.022641326,
    0.022318593,
    0.021963326,
    0.021577234,
    0.021162151,
    0.020720021,
    0.020252889,
    0.019762876,
    0.019252171,
    0.018723012,
    0.018177667,
    0.017618422,
    0.017047564,
    0.016467365,
    0.015880068,
    0.015287874,
    0.014692925
);

const float gaussianWeights1[] = float[](
	0.019590831,
	0.042587370,
	0.077902496,
	0.119916743,
	0.155336773,
	0.169331570,
	0.155336773,
	0.119916743,
	0.077902496,
	0.042587370,
	0.019590831
);

vec3 gaussianBlur(vec2 coords, sampler2D tex, vec2 direction, float scale) {
    vec3 color = vec3(0.0);

    for(int i = 0; i < 11; i++) {
        vec2 sampleCoords = (coords + (direction * float(i - 5) * pixelSize)) * scale;
        color += texture2D(tex, sampleCoords).rgb * gaussianWeights1[i];
    }
    return color;
}

float edgeWeight(vec2 sampleCoords, vec3 pos, vec3 normal) { 
    vec3 posAt = getViewPos(sampleCoords);
    float posWeight = 1.0 / max(1e-5, pow(distance(pos, posAt), 4.0));

    vec3 normalAt = normalize(decodeNormal(texture2D(colortex1, sampleCoords).xy));
    float normalWeight = max(pow(saturate(dot(normal, normalAt)), 8.0), 0.0);

    float depthAt = linearizeDepth(texture2D(depthtex0, sampleCoords).r);
    float depth = linearizeDepth(texture2D(depthtex0, texCoords).r);
    float depthWeight = pow(1.0 / (1.0 + abs(depthAt - depth)), 5.0);

    float screenWeight = float(saturate(sampleCoords) == sampleCoords);
    return saturate(posWeight * normalWeight * depthWeight) * screenWeight;
}

vec4 heavyGaussianFilter(vec2 coords, vec3 viewPos, vec3 normal, sampler2D tex, vec2 direction) {
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    for(int i = -49; i <= 49; i++) {
        vec2 sampleCoords = coords + (direction * float(i - 24) * pixelSize);
        float weight = edgeWeight(sampleCoords, viewPos, normal) * gaussianWeights0[abs(i)];

        color += texture2D(tex, sampleCoords) * weight;
        totalWeight += weight;
    }
    return color / max(0.0, totalWeight);
}

vec4 fastGaussianFilter(vec2 coords, vec3 viewPos, vec3 normal, sampler2D tex, vec2 direction) {
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    for(int i = 0; i < 11; i++) {
        vec2 sampleCoords = coords + (direction * float(i - 5) * pixelSize);
        float weight = edgeWeight(sampleCoords, viewPos, normal) * gaussianWeights1[abs(i)];

        color += texture2D(tex, sampleCoords) * weight;
        totalWeight += weight;
    }
    return color / max(0.0, totalWeight);
}
