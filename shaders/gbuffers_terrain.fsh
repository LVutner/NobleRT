/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

varying vec2 TexCoords;
varying vec2 LightmapCoords;
varying vec3 Normal;
varying vec4 Color;
varying float blockId;

uniform sampler2D colortex0;
uniform sampler2D colortex3;

void main() {
    vec4 Albedo = texture2D(colortex0, TexCoords) * Color;

    /*DRAWBUFFERS:0123*/
    gl_FragData[0] = Albedo;
    gl_FragData[1] = vec4(Normal * 0.5f + 0.5f, 1.0f);
    gl_FragData[2] = vec4(LightmapCoords, 0.0f, 1.0f);
    gl_FragData[3] = vec4(blockId, 0.0f, 0.0f, 1.0f);
}
