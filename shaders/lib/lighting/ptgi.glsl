/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computePTGI(in vec3 screenPos, bool isMetal) {
    vec3 radiance = vec3(0.0);
    vec3 weight = vec3(1.0);

    vec3 hitPos = screenPos;
    vec3 viewDir = -normalize(screenToView(screenPos));

    for(int i = 0; i < GI_BOUNCES; i++) {
        vec2 noise = uniformAnimatedNoise();

        /* Updating our position for the next bounce */
        vec3 normal = normalize(decodeNormal(texture2D(colortex1, hitPos.xy).xy));
        hitPos = screenToView(hitPos) + normal * EPS;

        /* Tangent Bitangent Normal */
        vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
        mat3 TBN = mat3(tangent, cross(normal, tangent), normal);
        
        /* Sampling a random direction in an hemisphere using noise and raytracing in that direction */
        vec3 sampleDir = TBN * randomHemisphereDirection(noise);
        bool hit = raytrace(hitPos, sampleDir, GI_STEPS, uniformNoise(i).r, hitPos);

        //Sample new data
        vec3 F0 = vec3(texture2D(colortex2, hitPos.xy).g);
        float roughness = texture2D(colortex2, hitPos.xy).r;
		vec3 albedo = texture2D(colortex0, hitPos.xy).rgb;
		
		////////////////////////////////////////////////////////////
		//Diffuse part
        vec3 H = normalize(viewDir + sampleDir);
        float NdotL = saturate(dot(normal, sampleDir));
        float NdotV = saturate(dot(normal, viewDir));
        float NdotH = saturate(dot(normal, H));
		
		float kappa = PI; //smol hack for brighter diffuse
		
		vec3 diffuse_brdf = isMetal ? vec3(0.0) : hammonDiffuse(NdotL, NdotV, NdotH, dot(viewDir, sampleDir), roughness, albedo) * NdotL * kappa;
		
		////////////////////////////////////////////////////////////
		//Specular part
        vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, noise.xy, roughness);
        vec3 reflected = reflect(viewDir, TBN * microfacet);

        H = normalize(viewDir + reflected);
        NdotL = saturate(dot(normal, reflected));
        NdotV = saturate(dot(normal, viewDir));
        NdotH = saturate(dot(normal, H));
        float HdotL = saturate(dot(H, reflected));

        vec3 specular_brdf = cookTorranceSpecular(NdotH, HdotL, NdotV, NdotL, roughness, F0) * texture2D(colortex9, hitPos.xy).rgb * NdotL;

		//Accumulation
        weight *= diffuse_brdf + specular_brdf;
        radiance += weight;
    }
    return radiance;
}
