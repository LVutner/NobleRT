/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/fragment/bayer.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/worldTime.glsl"

/*
const int colortex4Format = RGBA16F;
*/

void main() {

     /*DRAWBUFFERS:4*/
     if(texture2D(depthtex0, texCoords).r == 1.0) {
          vec3 sunDir = shadowLightPosition * 0.01;
          vec3 viewPos = getViewPos(texCoords);
          vec3 eyeDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

          float angle = quintic(0.999, 0.99995, dot(sunDir, normalize(viewPos)));
          vec3 sky = mix(getDayTimeSkyGradient(eyeDir, viewPos), vec3(2.0), angle); 
          
          gl_FragData[0] = vec4(saturate(sky), 1.0);
          return;
     }
     gl_FragData[0] = texture2D(colortex0, texCoords);
}