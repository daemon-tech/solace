# Solace Shaders (prototype 0.14)

An original cartoon / cel-shading shaderpack for **Minecraft 26.3** with **Iris 1.11.x + Sodium 0.9.x**.
All GLSL is written from scratch. Closed source, All Rights Reserved.

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
- 0.5: sky excluded from grading/scene cast (night sky indigo, not bright blue), stylized stars, wider/brighter torch pools, dusk ambient lift, less blue shadow ambient on warm albedo, nearer blue-teal fog, better capture spots (sand beach, forest floor, water with sky).
- 0.4: visible ~1px depth outlines, brighter cool shadows, flat lime foliage (block.properties 10002), stronger torch pools, orange sunset / indigo night scene cast, more turquoise water (less deep-blue), F1 tip for captures.
- 0.3.1: underwater fog no longer floods sky pixels (flat cyan sky), explicit buffer clears, particles neutrally lit, default shadow distance 64 for software GL.
- 0.3: fix global hue bug: lighting was not white-balanced (strong blue-violet ambient added on top of a warm sun turned sand/stone pink-purple); neutral light balance, subtler cool shadows, gentler lime/warmth grading, sunset sky no longer averages to olive, underwater fog after grading, particle alpha cut-off.
- 0.2: less pink/bright sand (warm-hue saturation limit, luminance cap, saturation 1.25),
  livelier water, lighter underwater fog, NaN guards (fixes black squares), no outlines underwater.
- 0.1: first prototype.

## Install
Drop the zip into `.minecraft/shaderpacks/` and select it in Iris' shader menu.

## License
All Rights Reserved. Free for personal use and for videos/screenshots. No re-uploading, no redistribution, no modified versions for distribution. See LICENSE.
- 0.6: crisp 1px silhouette outlines, glow/bloom + atmospheric haze, stronger sunset cast, torch pools, night indigo shift, brighter sand + foam band, brighter cyan water, underwater depth fog.
- 0.7: brighter indigo night ambient, teal-blue night foliage, stronger dusk lift.
- 0.8: torch-pool flag keeps torch light warm at night, hue-preserving night shift, brighter lime greens, closer haze, full dusk cast.
- 0.9 / 0.9.1: deep-blue underwater depth fog, toned kelp, tuned shore foam widths.
- 0.9.2: stars only in full night, softer/narrower foam (dimmer at night), more yellow-lime land, deeper orange sunset sky.
