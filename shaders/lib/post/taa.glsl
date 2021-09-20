/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
	Small TAA extension and its settings
	
	Used resources:
	https://www.gdcvault.com/play/1022970/Temporal-Reprojection-Anti-Aliasing-in
	https://ziyadbarakat.wordpress.com/2020/07/28/temporal-anti-aliasing-step-by-step/
*/
#define TAA_YCOCG //Enables clipping in YCoCG color space
#define TAA_VELOCITY_WEIGHT //Enables welocity weighting
#define TAA_LUMA_WEIGHT //Enables luminacne weighting by Timothy Lottes
#define TAA_LUMA_MIN 0.15 //Minimal luminance of fragment
#define TAA_FEEDBACK_MIN (TAA_STRENGTH) //Minimal blend factor for luma weight
#define TAA_FEEDBACK_MAX (TAA_STRENGTH+0.01) //Maximal blend factor for luma weight

vec3 reprojection(vec3 pos) {
    pos = pos * 2.0 - 1.0;

    vec4 currViewPos = gbufferProjectionInverse * vec4(pos, 1.0);
    currViewPos /= currViewPos.w;
    vec3 currWorldPos = (gbufferModelViewInverse * currViewPos).xyz;

    vec3 cameraOffset = (cameraPosition - previousCameraPosition) * float(pos.z > 0.56);

    vec3 prevWorldPos = currWorldPos + cameraOffset;
    vec4 prevClipPos = gbufferPreviousProjection * gbufferPreviousModelView * vec4(prevWorldPos, 1.0);
    return (prevClipPos.xyz / prevClipPos.w) * 0.5 + 0.5;
}

/*
    AABB Clipping from "Temporal Reprojection Anti-Aliasing in INSIDE"
    http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
*/

vec3 clip_aabb(vec3 aabb_min, vec3 aabb_max, vec3 p, vec3 q)
{
	vec3 p_clip = 0.5 * (aabb_max + aabb_min);
	vec3 e_clip = 0.5 * (aabb_max - aabb_min) + 1e-5;

	vec3 v_clip = q - p_clip;
	vec3 v_unit = v_clip.xyz / e_clip;
	vec3 a_unit = abs(v_unit);
	float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

	if (ma_unit > 1.0)
		return p_clip + v_clip / ma_unit;
	else
		return q;
}

vec3 taa_sample_color(sampler2D tex, vec2 uv)
{
	vec3 c = texture2D(tex, uv).xyz;
#ifdef TAA_YCOCG		
	c.xyz = vec3(
	c.x/4.0 + c.y/2.0 + c.z/4.0,
	c.x/2.0 - c.z/2.0,
	-c.x/4.0 + c.y/2.0 - c.z/4.0
	);
#endif
	return c.xyz;
}

vec3 taa_resolve_color(vec3 color)
{
#ifdef TAA_YCOCG
	color.xyz = saturate(vec3(
	color.x + color.y - color.z,
	color.x + color.z,
	color.x - color.y - color.z
	));
#endif	
	return color.xyz;
}

vec3 neighbourhoodClipping(sampler2D currColorTex, vec3 prevColor) 
{
    vec3 minColor = vec3(1.0);
	vec3 maxColor = vec3(0.0);
	vec3 avgColor = vec3(0.0);
	
    for(int x = -1; x <= 1; x++) 
	{
        for(int y = -1; y <= 1; y++) 
		{
            vec3 color = taa_sample_color(currColorTex, texCoords + vec2(x, y) * pixelSize).rgb;
 
            minColor = min(minColor, color); 
			maxColor = max(maxColor, color); 
			avgColor += color / 9.0;
        }
    }
    return clip_aabb(minColor, maxColor, clamp(avgColor, minColor, maxColor), prevColor);
}

// Thanks LVutner for the help with previous / current textures management!
vec3 computeTAA(sampler2D currTex, sampler2D prevTex) 
{
	//Reproject previous texture coordinates
    vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex1, texCoords).r)).xy;

	//Get velocity
	vec2 frameVelocity = (texCoords - prevTexCoords) * vec2(viewWidth, viewHeight);	
	
	//Sample current and previous color buffer
    vec3 currColor = taa_sample_color(currTex, texCoords).rgb;
    vec3 prevColor = taa_sample_color(prevTex, prevTexCoords).rgb;

	//Do neighbour clipping
    prevColor = neighbourhoodClipping(currTex, prevColor);

	//Initialize weight
	float blendWeight = 1.0;

#ifdef TAA_VELOCITY_WEIGHT	
	//Classic velocity weighting
	blendWeight *= exp(-length(frameVelocity)) * 0.5 + 0.5;
#endif

	//Luminance weight from Timothy Lottes
#ifdef TAA_LUMA_WEIGHT	
	#ifdef TAA_YCOCG	
		float currLuma = currColor.x;
		float prevLuma = prevColor.x;
	#else
		float currLuma = luma(currColor);
		float prevLuma = luma(prevColor);
	#endif

	float lumaWeight = 1.0-(abs(currLuma - prevLuma) / max(currLuma, max(prevLuma, TAA_LUMA_MIN)));
	
	//Luminance weight
	blendWeight *= mix(TAA_FEEDBACK_MIN, TAA_FEEDBACK_MAX, lumaWeight * lumaWeight);
#endif

	//Fallback if we are outside of viewport
	blendWeight *= float(saturate(prevTexCoords) == prevTexCoords);
	
	//Mix
	vec3 finalColor = mix(currColor, prevColor, blendWeight);
	
	//Resolve back and output
    return taa_resolve_color(finalColor); 
}
