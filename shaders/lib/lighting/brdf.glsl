/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float trowbridgeReitzGGX(float NdotH, in float alpha) {
    // GGXTR(N,H,α) = α² / π*((N*H)²*(α² + 1)-1)²
    alpha *= alpha;
    float denom = ((NdotH * NdotH) * (alpha - 1.0) + 1.0);
    return alpha / (PI * denom * denom);
}

float geometrySchlickBeckmann(float cosTheta, float roughness) {
    // SchlickGGX(N,V,k) = N*V/(N*V)*(1 - k) + k
    float denom = cosTheta * (1.0 - roughness) + roughness;
    return cosTheta / denom;
}

float geometrySmith(float NdotV, float NdotL, float roughness) {
    float r = roughness + 1.0;
    roughness = (r * r) / 8.0;

    float ggxV = geometrySchlickBeckmann(NdotV, roughness);
    float ggxL = geometrySchlickBeckmann(NdotL, roughness);
    return (ggxV * ggxL) / max(4.0 * NdotL * NdotV, EPS);
}

float geometrySchlickGGX(float NdotV, float alpha) {
    return (2.0 * NdotV) / (NdotV + sqrt(alpha + (1.0 - alpha) * (NdotV + NdotV)));
}

float geometryCookTorrance(float NdotH, float NdotV, float VdotH, float NdotL) {
    float NdotH2 = 2.0 * NdotH;
    float g1 = (NdotH2 * NdotV) / VdotH;
    float g2 = (NdotH2 * NdotL) / VdotH;
    return min(1.0, min(g1, g2));
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 schlickGaussian(float HdotL, vec3 F0) {
    float sphericalGaussian = exp2(((-5.55473 * HdotL) - 6.98316) * HdotL);
    return sphericalGaussian * (1.0 - F0) + F0;
}

// Provided by LVutner: more to read here: http://jcgt.org/published/0007/04/01/
vec3 sampleGGXVNDF(vec3 Ve, vec2 Xi, float alpha) {

	// Section 3.2: transforming the view direction to the hemisphere configuration
	vec3 Vh = normalize(vec3(alpha * Ve.xy, Ve.z));

	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
	vec3 T1 = lensq > 0.0 ? vec3(-Vh.y, Vh.x, 0.0) * inversesqrt(lensq) : vec3(1.0, 0.0, 0.0);
	vec3 T2 = cross(Vh, T1);

	// Section 4.2: parameterization of the projected area
	float r = sqrt(Xi.y);	
	float xOffset = r * cos(PI2 * Xi.x);
	float yOffset = r * sin(PI2 * Xi.x);
	float s = 0.5 * (1.0 + Vh.z);
	yOffset = (1.0 - s) * sqrt(1.0 - (xOffset * xOffset)) + s * yOffset;

	// Section 4.3: reprojection onto hemisphere
	vec3 Nh = xOffset * T1 + yOffset * T2 + sqrt(max(0.0, 1.0 - (xOffset * xOffset) - (yOffset * yOffset))) * Vh;

	// Section 3.4: transforming the normal back to the ellipsoid configuration
	return normalize(vec3(alpha * Nh.x, alpha * Nh.y, max(0.0, Nh.z)));	
}

// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile?sessionInvalidated=true
vec3 envBRDFApprox(vec3 F0, float NdotV, float roughness) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
    vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
    return F0 * AB.x + AB.y;
}

vec3 cookTorranceSpecular(float NdotH, float HdotL, float NdotV, float NdotL, float roughness, vec3 F0) {
    float D = trowbridgeReitzGGX(NdotH, roughness * roughness);
    vec3 F = schlickGaussian(HdotL, F0);
    float G = geometrySmith(NdotV, NdotL, roughness);
        
    return clamp(D * F * G, 0.0, 1.0);
}

/*
    Thanks LVutner for the help!
    https://github.com/LVutner
    https://gist.github.com/LVutner/c07a3cc4fec338e8fe3fa5e598787e47
*/

vec3 cookTorrance(vec3 N, vec3 V, vec3 L, material data, vec3 lightmap, vec3 shadowmap) {
    bool isMetal = data.F0 * 255.0 > 229.5;
    float alpha = data.roughness * data.roughness;

    vec3 H = normalize(V + L);
    float NdotV = abs(dot(N, V)) + 1e-5;
    float NdotL = saturate(dot(N, L));
    float NdotH = saturate(dot(N, H));
    float VdotH = saturate(dot(V, H));
    float HdotL = saturate(dot(H, L));

    vec3 specular;
    #if SPECULAR == 1
        vec3 specularColor = isMetal ? data.albedo : vec3(data.F0);
        specular = cookTorranceSpecular(NdotH, HdotL, NdotV, NdotL, data.roughness, specularColor);
    #endif

    vec3 diffuse = vec3(0.0);
    if(!isMetal) {
        // OREN-NAYAR MODEL - QUALITATIVE 
        // http://www1.cs.columbia.edu/CAVE/publications/pdfs/Oren_CVPR93.pdf
        
        vec2 angles = acos(vec2(NdotL, NdotV));
        if(angles.x < angles.y) angles = angles.yx;
        float cosA = saturate(dot(normalize(V - NdotV * N), normalize(L - NdotL * N)));

        vec3 A = data.albedo * (INV_PI - 0.09 * (alpha / (alpha + 0.4)));
        vec3 B = data.albedo * (0.125 * (alpha /  (alpha + 0.18)));
        diffuse = clamp(A + B * max(0.0, cosA) * sin(angles.x) * tan(angles.y), 0.0, 1.0);
    }

    vec3 Lighting = (diffuse + specular) * (NdotL * shadowmap) * getDayColor() * SUN_INTENSITY;
    Lighting += data.emission * data.albedo;

    if(!isMetal) {
        vec3 ambient = GI == 0 ? AMBIENT : PTGI_AMBIENT;

        Lighting += ambient * data.albedo;
        #if GI == 0
            Lighting *= lightmap;
        #endif
    }
    return Lighting;
}
