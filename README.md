Away3D Lite
=============

Fastest and smallest 3d engine for Flash 10+. And now Stage3D!


Stage3D (new)
-----
Introducing a new Stage3DRenderer (WIP) for Flash 11, while still keeping full FP10 compatibility.

The goal is to have a rudimentary (but simple and fast) Stage3D renderer for simple 3D scenes.

**Features:**
 - using Stage3D constrained mode, 
 - automatic fallback to DefaultRenderer,
 - automatic quads to triangles conversion, double-sided materials,
 - BitmapMaterial / BitmapMaterialEx (mipmap, transparency control),
 - ColorMaterial (color, alpha),
 - mesh.alpha blending,
 - additive blendmode (Object3D's blendMode).

**Gotchas:**
 - for transparent PNGs to blend correctly, the Object3Ds order (in their container) is meaningful (transparent should be latest), not their z position,
 - to refresh a texture after a BitmapData change, call 'renderer.invalidateTexture(bmp)' (tested with MP4s and transparent FLVs).

**TODO:**
 - check stability, leaks,
 - more tests (I tried Planes, Skybox6 and some multi-material Colladas),
 - lights,
 - custom shaders,
 - fix projection to match exactly the FP10 output (it's close but not enough to reuse the original mouse handling),
 - implement lights.

**Example usage:** 
 - code: https://gist.github.com/3659167
 - running: http://philippe.elsass.me/lab/away3dlite-stage3d