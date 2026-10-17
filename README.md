# Solace (prototype 0.3.1)

An original cartoon / cel-shading shaderpack for **Minecraft 26.3** with **Iris 1.11.x + Sodium 0.9.x**.
All GLSL is written from scratch (MIT). Prototype codename; the final name is not decided.

## Features
- Cel-shaded lighting: quantized N·L + lightmap, 2–5 bands with adjustable smoothstep edge
- Thin outlines (Sobel on linear depth, optional normal edges) with colour / strength / distance fade
- Colour grading: saturation (reduced on warm hues), highlight cap, vibrance, lime-leaning greens, warm light
- Soft PCF shadow map (distorted), banded, cool blue/violet shadow tint; indigo nights; warm torch pools
- Banded 3-colour gradient sky by time of day, banded sun & moon
- Vanilla cloud geometry with flat toon shading (bluish underside, sunset tint)
- Stylized water: turquoise, wave normals, 4-step banded fresnel, depth gradient to deep blue,
  two shore-foam bands, sparkle streaks, sun glint
- Banded blue-teal distance fog, light cyan underwater fog
- Settings menu with LOW / MEDIUM / HIGH profiles

## Changelog
- 0.3.1: underwater fog no longer floods sky pixels (flat cyan sky), explicit buffer clears, particles neutrally lit, default shadow distance 64 for software GL.
- 0.3: fix global hue bug: lighting was not white-balanced (strong blue-violet ambient added on top of a warm sun turned sand/stone pink-purple); neutral light balance, subtler cool shadows, gentler lime/warmth grading, sunset sky no longer averages to olive, underwater fog after grading, particle alpha cut-off.
- 0.2: less pink/bright sand (warm-hue saturation limit, luminance cap, saturation 1.25),
  livelier water, lighter underwater fog, NaN guards (fixes black squares), no outlines underwater.
- 0.1: first prototype.

## Install
Drop the zip into `.minecraft/shaderpacks/` and select it in Iris' shader menu.

## License
MIT, see LICENSE.
