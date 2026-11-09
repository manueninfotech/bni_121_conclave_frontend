#version 460 core
// Flowing silk, ported from React Bits' <Silk /> (single pass: folds, sheen,
// depth shading and grain; no bloom / pointer interaction). Driven from
// lib/features/active_conclave/presentation/round/card_backdrop.dart.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;        // 0,1
uniform float uTime;       // 2
uniform vec3 uColor;       // 3,4,5
uniform vec3 uSheenColor;  // 6,7,8
uniform float uScale;      // 9
uniform float uRotation;   // 10
uniform float uNoise;      // 11
uniform float uSheen;      // 12
uniform float uDepth;      // 13
uniform float uWave;       // 14
uniform float uRipple;     // 15
uniform float uSeed;       // 16

out vec4 fragColor;

const float E = 2.71828182845904523536;

float grainNoise(vec2 p) {
  vec2 r = E * sin(E * p);
  return fract(r.x * r.y * (1.0 + p.x));
}

vec2 rotateUv(vec2 uv, float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, -s, s, c) * uv;
}

float silk(vec2 uv0) {
  vec2 uv = rotateUv(uv0 * uScale, uRotation);
  vec2 tex = uv * uScale + vec2(uSeed, uSeed * 0.7);
  float t = uTime;
  tex.y += 0.03 * uWave * sin(8.0 * tex.x - t);
  return 0.6 + 0.4 * sin(5.0 * (tex.x + tex.y + cos(3.0 * tex.x + 5.0 * tex.y) + 0.02 * t)
      + uRipple * sin(20.0 * (tex.x + tex.y - 0.1 * t)));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  uv.y = 1.0 - uv.y;

  float pattern = silk(uv);
  float n = clamp((pattern - 0.2) / 0.8, 0.0, 1.0);

  // Surface normal from the fold field -> relief and gloss.
  vec2 stepUv = 1.5 / uSize;
  float gx = silk(uv + vec2(stepUv.x, 0.0)) - pattern;
  float gy = silk(uv + vec2(0.0, stepUv.y)) - pattern;
  vec3 normal = normalize(vec3(-gx * 26.0, -gy * 26.0, 1.0));
  vec3 toLight = normalize(vec3(-0.55, 0.7, 0.85));
  float relief = 1.0 + (dot(normal, toLight) - toLight.z) * 1.8 * uDepth;
  vec3 halfway = normalize(toLight + vec3(0.0, 0.0, 1.0));
  float gloss = pow(max(dot(normal, halfway), 0.0), 48.0) * smoothstep(0.25, 0.85, n);
  float crest = pow(n, 5.0);
  float shine = (gloss * 0.85 + crest * 0.4) * uSheen;

  // Keep the darkest folds well above black so the card stays brand red and
  // white text on it stays readable.
  float floorValue = mix(0.55, 0.32, uDepth);
  float curve = pow(n, 1.0 + 1.4 * uDepth);
  float shade = floorValue + (1.0 - floorValue) * curve;
  vec3 tone = mix(uColor, pow(uColor, vec3(1.45)), (1.0 - n) * uDepth);
  float grain = grainNoise(frag) / 15.0 * uNoise;
  vec3 lit = tone * shade * relief - vec3(grain);
  vec3 tint = mix(uColor, uSheenColor, 0.8);
  vec3 c = lit + tint * (shine + crest * 0.15);

  // Soft clip the highlights.
  vec3 over = max(c - 0.75, 0.0);
  c = min(c, 0.75) + 0.25 * (1.0 - exp(-over * 4.0));
  fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
