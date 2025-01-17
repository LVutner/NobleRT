/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Normals encoding / decoding from: https://aras-p.info/texts/CompactNormalStorage.html

const float scale = 1.7777;
vec2 encodeNormal(vec3 normal) {
    vec2 enc = normal.xy / (normal.z + 1.0);
    enc /= scale;
    return enc * 0.5 + 0.5;
}

vec3 decodeNormal(vec2 enc) {
    vec3 nn = vec3(enc, 0.0) * vec3(vec2(2.0 * scale), 0.0) + vec3(vec2(-scale), 1.0);
    float g = 2.0 / dot(nn.xyz, nn.xyz);
    return vec3(g * nn.xy, g - 1.0);
}

float pack2x8(vec2 x, float pattern) {
	return dot(floor(255.0 * x + pattern), vec2(1.0 / 65535.0, 256.0 / 65535.0));
}

vec2 unpack2x8(float pack) {
	pack *= 65535.0 / 256.0;
	vec2 xy; xy.y = floor(pack); xy.x = pack - xy.y;
	return vec2(256.0 / 255.0, 1.0 / 255.0) * xy;
}

float distanceSquared(vec3 v1, vec3 v2) {
	vec3 u = v2 - v1;
	return dot(u, u);
}

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

vec2 saturate(vec2 x) {
    return clamp(x, vec2(0.0), vec2(1.0));
}

vec3 saturate(vec3 x) {
    return clamp(x, vec3(0.0), vec3(1.0));
}

vec4 saturate(vec4 x) {
    return clamp(x, vec4(0.0), vec4(1.0));
}

// Improved smoothstep function suggested by Ken Perlin
// https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/perlin-noise-part-2/improved-perlin-noise
float quintic(float edge0, float edge1, float x) {
    x = saturate((x - edge0) / (edge1 - edge0));
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

// https://seblagarde.wordpress.com/2014/12/01/inverse-trigonometric-functions-gpu-optimization-for-amd-gcn-architecture/
float ACos(in float x) { 
    x = abs(x); 
    float res = -0.156583 * x + HALF_PI; 
    res *= sqrt(1.0 - x); 
    return (x >= 0) ? res : PI - res; 
}

float ASin(float x) {
    return HALF_PI - ACos(x);
}

float ATanPos(float x)  { 
    float t0 = (x < 1.0) ? x : 1.0 / x;
    float t1 = t0 * t0;
    float poly = 0.0872929;
    poly = -0.301895 + poly * t1;
    poly = 1.0 + poly * t1;
    poly = poly * t0;
    return (x < 1.0) ? poly : HALF_PI - poly;
}

float ATan(float x) {     
    float t0 = ATanPos(abs(x));     
    return (x < 0.0) ? -t0 : t0; 
}

/* SOURCES
https://fr.wikipedia.org/wiki/Th%C3%A9orie_de_Mie
https://www.shadertoy.com/view/wlBXWK
*/

float rayleighPhase(float cosTheta) {
    const float rayleigh = 3.0 / (16.0 * PI);
    return rayleigh * (1.0 + (cosTheta * cosTheta));
}

float miePhase(float g, float cosTheta) {
    const float mie = 3.0 / (8.0 * PI);
    float gg = g*g; // The direction mie scatters the light in. Closer to -1 means more towards a single direction (ShaderToy - Atmospheric scattering explained by skythedragon)
    float num = (1.0 - gg) * (1.0 + (cosTheta*cosTheta));
    float denom = (2.0 + gg) * pow(1.0 + gg - 2.0 * g * cosTheta, 1.5);
    return mie * (num / denom);
}

float heyneyGreensteinPhase(float g, float cosTheta) {
    const float heyney = 1.0 / (4.0 * PI);
    return heyney * ((1.0 - (g*g)) / pow(1.0 + (g*g) - 2.0 * g * cosTheta, 1.5));
}

// Provided by LVutner.#1925
vec3 hemisphereSample(vec2 r) {
    float phi = r.x * 2.0 * PI;
    float cosTheta = 1.0 - r.y;
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

// Provided by lith#0281
vec3 randomHemisphereDirection(vec2 r) {
    float radius = sqrt(r.y);
    float xOffset = radius * cos(PI2 * r.x);
    float yOffset = radius * sin(PI2 * r.x);
    float zOffset = sqrt(1.0 - r.y);
    return normalize(vec3(xOffset, yOffset, zOffset));
}
