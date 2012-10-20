Away3D Lite
=============

Fastest and smallest 3d engine for Flash 10+. And now Stage3D!


Stage3D (new)
-----
Introducing a new Stage3DRenderer (WIP) for Flash 11, while still keeping full FP10 compatibility.

The goal is to have a rudimentary (but simple and fast) Stage3D renderer for simple 3D scenes.

**Features:**
 - some serious memory leaks fixes and added explicit .dispose methods,
 - using Stage3D constrained mode (if available), 
 - automatic fallback to DefaultRenderer,
 - automatic quads to triangles conversion, double-sided materials,
 - BitmapMaterial / BitmapMaterialEx (mipmap, transparency control),
 - ColorMaterial (color, alpha),
 - cascading Object3D.alpha blending,
 - additive blendmode (Object3D's blendMode),
 - Object3Ds have new properties: offscreen, screenPosition.

**Stage3DRenderer gotchas:** (lotsa)
 - approximative camera in Stage3D (not exactly matching Flash 10's),
 - no mouse events, no lightning,
 - for transparent PNGs to blend correctly, the Object3Ds order (in their container) is meaningful (transparent should be latest), not their z position,
 - to refresh a texture after a BitmapData change, call 'renderer.invalidateTexture(bmp)' (tested with MP4s and transparent FLVs).

**Stage3DRenderer TODO:**
 - mouse events,
 - adapt MovieMaterial,
 - lights,
 - custom shaders,
 - fix projection to match exactly the FP10 output (it's close but not enough to reuse the original mouse handling).

**Example usage:** 
 - code: https://gist.github.com/3659167
 - running: http://philippe.elsass.me/lab/away3dlite-stage3d