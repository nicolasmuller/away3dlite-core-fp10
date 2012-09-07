Away3D Lite
=============

Fastest and smallest 3d engine for Flash 10+. And now Stage3D!


Stage3D (new)
-----
Introducing a new Stage3DRenderer (WIP) for Flash 11, while still keeping full FP10 compatibility.

The goal is to have a rudimentary (but simple and fast) Stage3D renderer for simple 3D scenes.

**Features:**
 - automatic quads to triangles conversion, double-sided materials,
 - BitmapMaterial / BitmapMaterialEx (mipmap, transparency control),
 - ColorMaterial (color, alpha),
 - additive blendmode (Object3D's blendMode),
 - custom shaders (Object3D's arcane _program).

**TODO:**
 - check stability, leaks
 - fix projection to match exactly the FP10 output (it's close but not enough to reuse the original mouse handling),
 
**Example usage:** 
 - code: https://gist.github.com/3659167
 - running: http://philippe.elsass.me/lab/away3dlite-stage3d