package away3dlite.core.render 
{
	import away3dlite.arcane;
	import away3dlite.containers.*;
	import away3dlite.core.base.*;
	import away3dlite.core.render.Renderer;
	import away3dlite.materials.*;
	import com.adobe.utils.AGALMiniAssembler;
	import com.adobe.utils.PerspectiveMatrix3D;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DRenderMode;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DTriangleFace;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.textures.Texture;
	import flash.display3D.VertexBuffer3D;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	import flash.geom.Matrix3D;
	import flash.geom.Point;
	import flash.geom.Utils3D;
	import flash.geom.Vector3D;
	import flash.system.Capabilities;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import flash.display.*;
	import flash.utils.Dictionary;
	
	use namespace arcane;
	
	/**
	 * Stage3D renderer for a view.
	 * 
	 * @see away3dlite.containers.View3D
	 * @author Philippe
	 */
	public class Stage3DRenderer extends Renderer
	{
		public static const STAGE3D_READY:String = "stage3dReady";
		public static const STAGE3D_FAILED:String = "stage3dFailed";
		
		private var _mesh:Mesh;
		private var _screenVertices:Vector.<Number>;
		private var _uvtData:Vector.<Number>;
		private var _material:Material;
		private var _i:int;
		private var _j:int;
		private var _k:int;
		private var _material_graphicsData:Vector.<IGraphicsData>;
		private var _graphicsDatas:Dictionary = new Dictionary(true);
		
		private function collectFaces(object:Object3D):void
		{
			if (!object.visible || object._perspCulling)
				return;
			
			_mouseEnabledArray.push(_mouseEnabled);
			_mouseEnabled = object._mouseEnabled = (_mouseEnabled && object.mouseEnabled);
			
			if (object is ObjectContainer3D) {
				var children:Array = (object as ObjectContainer3D).children;
				var child:Object3D;
				
				for each (child in children)
				{
					collectFaces(child);
				}
				
			}
			
			if (object is Mesh) {
				var mesh:Mesh = object as Mesh;
				_clipping.collectFaces(mesh, _faces);
				
				if (_view.mouseEnabled && _mouseEnabled)
					collectScreenVertices(mesh);
				
				_view._totalFaces += mesh._faces.length;
			}
			
			_mouseEnabled = _mouseEnabledArray.pop();
			
			++_view._totalObjects;
			++_view._renderedObjects;
		}
		
		/**
		 * Creates a new <code>Stage3DRenderer</code> object.
		 */
		public function Stage3DRenderer(contextID:int = 0)
		{
			super();
			this.contextID = contextID;
			alphas = new <Number>[1.0, 1.0, 1.0, 1.0];
			Material.DEFAULT_SMOOTH = true;
		}
		
		/**
		 * @inheritDoc
		 */
		public override function getFaceUnderPoint(x:Number, y:Number):Face
		{
			if (!_faces.length)
				return null;
			
			collectPointVertices(x, y);
			
			_screenZ = 0;
			
			collectPointFace(x, y);
			
			return _pointFace;
		}
		
		/**
		 * @inheritDoc
		 */
		public override function render():void
		{
			super.render();
			
			_faces = new Vector.<Face>();
			collectFaces(_scene); // for clipping
			_faces.fixed = true;
			_view._renderedFaces = _faces.length;
			
			/*if (_mouseEnabled) {
				_view.graphics.clear();
				_view.graphics.beginFill(0, 0);
				_view.graphics.drawRect(mousePos.x - 10, mousePos.y - 10, 20, 20);
			}*/
			
			render3D();
			
			if (!_faces.length)
				return;
			
			_sort.fixed = false;
			_sort.length = _faces.length;
			_sort.fixed = true;
			if (_mouseEnabled) sortFaces();
		}
		
		/* STAGE 3D RENDER */
		
		private function render3D():void 
		{
			if (!stageReady()) return;
			
			// clear
			var rgb:int = stage.color;
			var r:Number = ((rgb >> 16) & 0xff) / 256;
			var g:Number = ((rgb >> 8) & 0xff) / 256;
			var b:Number = (rgb & 0xff) / 256;
			context.clear(r, g, b); 
			context.setCulling(culling);
			
			// projection matrix
			mProjection.identity();
			mProjection.append(_view.scene.transform.matrix3D);
			mProjection.append(_view.camera.invSceneMatrix3D);
			mProjection.appendScale(sceneScale, -sceneScale, sceneScale);
			mProjection.append(projection);
			
			// render
			off = 0;
			renderContainer(_view.scene, mProjection, 1);
			//trace(off);
			
			context.present();
		}
		
		private function renderContainer(cont:ObjectContainer3D, mParent:Matrix3D, alpha:Number):void 
		{
			alpha *= cont.alpha;
			for each(var c:Object3D in cont.children)
			{
				if (!c.visible) continue;
				
				c.viewMatrix3D.copyRawDataFrom(mParent.rawData);
				c.viewMatrix3D.prepend(c.transform.matrix3D);
				
				c._screenPosition = Utils3D.projectVector(c.viewMatrix3D, zero);
				c._screenPosition.x *= stageWidth / 2;
				c._screenPosition.y *= -stageHeight / 2;
				
				if (c is ObjectContainer3D) renderContainer(c as ObjectContainer3D, c.viewMatrix3D, alpha);
				else if (c is Mesh) 
				{
					var mesh:Mesh = c as Mesh;
					if (mesh._offscreen) off++;
					if (canRender(mesh))
					{
						var renderInfo:MeshRenderInfo = updateMeshBuffers(mesh);
						
						var len:int = renderInfo.length;
						var blendMode:String = mesh.blendMode;
						var localAlpha:Number = alpha * mesh.alpha;
						for (var i:int = 0; i < len; i++) 
						{
							// set shader and blending option
							if (setProgram(renderInfo.material[i], blendMode, localAlpha))
							{
								// move x,y,z in register 0
								context.setVertexBufferAt(0, renderInfo.vertexBuffer[i], 0, Context3DVertexBufferFormat.FLOAT_3);
								// move u,v,t or r,g,b,a in register 1
								context.setVertexBufferAt(1, renderInfo.vertexBuffer[i], 3, renderInfo.vertexInfoFormat[i]);
								// set projection matrix
								context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, c.viewMatrix3D, true);
								// alpha
								if (localAlpha != 1) {
									alphas[0] = alphas[1] = alphas[2] = alphas[3] = localAlpha;
									context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, alphas);
								}
								// provide triangles
								context.drawTriangles(renderInfo.indexBuffer[i]);
							}
						}
					}
				}
			}
		}
		
		/* STAGE 3D SETUP */ 
		
		public var culling:String = "front";
		public var contextID:int = 0;
		
		/** allow the creation of textures (nearest power of 2 size) smaller than original bitmap */
		public var optimizeTextureSize:Number = 0.1;
		/** limit texture size */
		public var maxTextureSize:int = 2048;
		/** report failure if no Hardware mode is available */
		public var failOnSoftware:Boolean = true;
		/** FP11.4 Stage3D profile (defaults to BASELINE_CONSTRAINED for better compatibility) */
		public var stage3DProfile:String = "baselineConstrained";
		
		private var off:int;
		private var alphas:Vector.<Number>;
		
		arcane var stage:Stage;
		arcane var stageWidth:int;
		arcane var stageHeight:int;
		arcane var context:Context3D;
		arcane var program:Program3D;
		arcane var renderMode:String;
		arcane var programs:Object = {};
		arcane var mProjection:Matrix3D = new Matrix3D();
		arcane var zero:Vector3D = new Vector3D();
		arcane var projection:PerspectiveMatrix3D = new PerspectiveMatrix3D();
		arcane var sceneScale:Number = 1/100;
		arcane var bmps:Vector.<BitmapData> = new Vector.<BitmapData>();
		arcane var textures:Vector.<Texture> = new Vector.<Texture>();
		arcane var toDispose:Vector.<Mesh> = new Vector.<Mesh>();
		arcane var mousePos:Point = new Point();
		
		arcane var PROGRAMS:XML = <programs>
			<color>
				<vertex><![CDATA[
					m44 op, va0, vc0	// m44 to output point
					mov v1, va1			// interpolate Vertex Color (va1), to the variable register v1
				]]></vertex>
				<fragment><![CDATA[
					mov oc, v1			// move the Vertex Color (v1) to the output color
				]]></fragment>
			</color>
			<color-opacity>
				<vertex><![CDATA[
					m44 op, va0, vc0	// m44 to output point
					mov v1, va1			// interpolate Vertex Color (va1), to the variable register v1
				]]></vertex>
				<fragment><![CDATA[
					mul oc, v1, fc0		// multiply the Vertex Color (v1) by alpha constant (fc0) and output
				]]></fragment>
			</color-opacity>
			<bitmap>
				<vertex><![CDATA[
					m44 op, va0, vc0	// m44 to output point
					mov v1, va1			// interpolate the UVs (va1) into variable register v1
				]]></vertex>
				<fragment><![CDATA[
					tex oc, v1, fs1 <>	// sample the texture (fs1) at the interpolated UV coordinates (v1) and output
				]]></fragment>
			</bitmap>
			<bitmap-opacity>
				<vertex><![CDATA[
					m44 op, va0, vc0	// m44 to output point
					mov v1, va1			// interpolate the UVs (va1) into variable register v1
				]]></vertex>
				<fragment><![CDATA[
					tex ft0, v1, fs1 <>	// sample the texture (fs1) at the interpolated UV coordinates (v1) and store in temp (ft0)
					mul oc, ft0, fc0	// multiply sampled color (ft0) by alpha constant (fc0) and output
				]]></fragment>
			</bitmap-opacity>
		</programs>;
		
		public function dispose(e:Event = null):void
		{
			_view.removeEventListener(Event.REMOVED_FROM_STAGE, dispose);
			
			recycle();
			
			stage.stage3Ds[contextID].removeEventListener(ErrorEvent.ERROR, context3dError);
			stage.stage3Ds[contextID].removeEventListener(Event.CONTEXT3D_CREATE, context3dCreate);
			if (context) {
				context.setTextureAt(1, null);
				context.setVertexBufferAt(0, null);
				context.setVertexBufferAt(1, null);
				context.dispose();
				context = null;
			}
			
			//stage.removeEventListener(MouseEvent.MOUSE_MOVE, stage_mouse);
			stageWidth = stageHeight = 0;
			stage = null;
		}
		
		private function init():void
		{
			if (this.stage) dispose();
			this.stage = _view.stage;
			
			// wait for Stage3D to provide us a Context3D
			stage.stage3Ds[contextID].addEventListener(ErrorEvent.ERROR, context3dError);
			stage.stage3Ds[contextID].addEventListener(Event.CONTEXT3D_CREATE, context3dCreate);
			
			var fp:Number = parseFloat(Capabilities.version.split(" ")[1].replace(',', '.'));
			var requestContext3D:Function = stage.stage3Ds[contextID].requestContext3D;
			if (fp >= 11.4) requestContext3D(Context3DRenderMode.AUTO, stage3DProfile);
			else requestContext3D(Context3DRenderMode.AUTO);
			
			//stage.addEventListener(MouseEvent.MOUSE_MOVE, stage_mouse);
			
			_view.addEventListener(Event.REMOVED_FROM_STAGE, dispose);
		}
		
		private function stage_mouse(e:MouseEvent):void 
		{
			if (_view) {
				mousePos.x = _view.mouseX;
				mousePos.y = _view.mouseY;
				//if (_view && context && e.target == stage) _view.fireMouseEvent(e.type, e.ctrlKey, e.shiftKey);
			}
		}
		
		/**
		 * Failed to create a 3D context
		 */
		private function context3dError(e:ErrorEvent):void 
		{
			_view.dispatchEvent(new Event(STAGE3D_FAILED));
		}
		
		/**
		 * We've got a 3D context, maybe accelerated
		 */
		private function context3dCreate(event:Event):void 
		{
			var ctx:Context3D = event.target.context3D;
			if (failOnSoftware && ctx.driverInfo.indexOf("Software") >= 0)
			{
				ctx.dispose();
				dispose();
				_view.renderer = new BasicRenderer();
				_view.dispatchEvent(new Event(STAGE3D_FAILED));
			}
			else
			{
				context = ctx;	
				context.enableErrorChecking = true;
				_view.dispatchEvent(new Event(STAGE3D_READY));
			}
		}
		
		/**
		 * Dispose all programs and buffers (for when you want to clear the scene)
		 */
		public function recycle():void 
		{
			bmps.length = 0;
			for each(var tex:Texture in textures)
				if (tex) tex.dispose();
			textures.length = 0;
			
			for each(var mesh:Mesh in toDispose)
			{
				if (mesh.material is BitmapMaterial)
					BitmapMaterial(mesh.material)._program = null;
				
				var renderInfo:MeshRenderInfo = mesh._renderInfo;
				if (renderInfo) {
					renderInfo.dispose();
					mesh._renderInfo = null;
				}
			}
			toDispose.length = 0;
			
			for (var pid:String in programs) 
			{
				if (programs[pid]) programs[pid].dispose();
				delete programs[pid];
			}
			program = null;
		}
		
		/**
		 * Init/check the rendering context status and stage dimensions
		 */
		private function stageReady():Boolean 
		{
			if (!stage || !_view) {
				if (_view && _view.stage) init();
				return false;
			}
			var sw:int = _view.x * 2;
			var sh:int = _view.y * 2;
			if (stageWidth != sw || stageHeight != sh) setSize(sw, sh);
			return stageWidth > 0 && stageHeight > 0 && context;
		}
		
		private function setSize(width:int, height:int):void
		{
			stageWidth = width;
			stageHeight = height;
			
			if (context && stageWidth && stageHeight) 
			{
				// compute projection matrix
				// TODO fix projection to match exactly the FP10 output
				var r:Number = stageWidth / stageHeight;
				var w:Number = (stageHeight / 1000);
				projection.perspectiveLH(w * r, w, 1, 1000);
				// setup context
				context.configureBackBuffer(stageWidth, stageHeight, 2, true);
			}
		}
		
		/**
		 * Determine if a mesh isn't empty and has a valid material
		 */
		private function canRender(mesh:Mesh):Boolean
		{
			return !mesh._offscreen && mesh.material
				&& (mesh.material is BitmapMaterial || mesh.material is ColorMaterial);
		}
		
		/**
		 * Build and upload mesh vertext/index buffers
		 */
		private function updateMeshBuffers(mesh:Mesh):MeshRenderInfo 
		{
			var renderInfo:MeshRenderInfo = mesh._renderInfo;
			if (renderInfo && !mesh._verticesDirty) 
				return renderInfo;
			
			// setup
			mesh._verticesDirty = false;
			if (!renderInfo) {
				mesh._renderInfo = renderInfo = new MeshRenderInfo();
				toDispose.push(mesh);
			}
			else renderInfo.dispose();
			
			var material:Material = mesh.material;
			var i:int, count:int;
			
			// VERTEX BUFFER
			var vertices:Vector.<Number> = mesh._vertices;
			var uvs:Vector.<Number> = mesh._uvtData;
			var vertexData:Vector.<Number> = new Vector.<Number>();
			var vindex:int = 0, tindex:int = 0;
			var format:String = null, size:int = 0;
			count = vertices.length / 3;
			
			if (material is BitmapMaterial)
			{
				for (i = 0; i < count; i++, vindex+=3, tindex+=3)
				{
					vertexData.push(
						vertices[vindex], vertices[vindex + 1], vertices[vindex + 2], 
						uvs[tindex], uvs[tindex + 1], uvs[tindex + 2]);
				}
				format = Context3DVertexBufferFormat.FLOAT_3;
				size = 6;
			}
			else if (material is ColorMaterial)
			{
				// TODO ColorMaterial buffer building will only use the main model color (consistent with FP10 rendering)
				vertexBuffer = context.createVertexBuffer(count, 7);
				var rgb:int = (material as ColorMaterial).color;
				var a:Number = (material as ColorMaterial).alpha;
				var r:Number = a * ((rgb >> 16) & 0xff) / 256;
				var g:Number = a * ((rgb >> 8) & 0xff) / 256;
				var b:Number = a * (rgb & 0xff) / 256;
				for (i = 0; i < count; i++, vindex+=3)
				{
					vertexData.push(
						vertices[vindex], vertices[vindex + 1], vertices[vindex + 2], 
						r, g, b, a);
				}
				format = Context3DVertexBufferFormat.FLOAT_4;
				size = 7;
			}
			else return renderInfo; // unsupported material
			
			// create buffer
			var vertexBuffer:VertexBuffer3D = context.createVertexBuffer(count, size);
			vertexBuffer.uploadFromVector(vertexData, 0, count);
			
			// INDEX BUFFER(s)
			var materials:Vector.<Material> = mesh._faceMaterials;
			var faces:int = materials.length;
			var indices:Vector.<int> = mesh._indices;
			var facelens:Vector.<int> = mesh._faceLengths;
			var iindex:int = 0, findex:int = 0, f:int = 0;
			count = 0;
			count = 0;
			do {
				// accumulate same-material faces
				var temp:Material = materials[f++] || material;
				if (f == faces) count++; 
				else if (temp == material) { 
					count++;
					continue;
				}
				else if (count == 0) {
					count++;
					material = temp;
					continue;
				}
				// copy/convert indices
				var indexes:Vector.<uint> = new Vector.<uint>();
				for (i = 0; i < count; i++, findex++)
				{
					var len:int = facelens[findex];
					if (len == 3) {
						indexes.push(indices[iindex], indices[iindex + 1], indices[iindex + 2]);
						iindex += 3;
					}
					else if (len == 4) { // convert quads to tris
						indexes.push(indices[iindex], indices[iindex + 1], indices[iindex + 3], indices[iindex + 1], indices[iindex + 2], indices[iindex + 3]);
						iindex += 4;
					}
				}
				if (mesh.bothsides) // double-sided
					indexes = indexes.concat( indexes.concat().reverse() );
					
				// create buffer
				var indexBuffer:IndexBuffer3D = context.createIndexBuffer(indexes.length);
				indexBuffer.uploadFromVector(indexes, 0, indexes.length);
				
				// store
				renderInfo.material.push(material);
				renderInfo.vertexBuffer.push(vertexBuffer);
				renderInfo.vertexInfoFormat.push(format);
				renderInfo.indexBuffer.push(indexBuffer);
				
				// next material
				count = 1; 
				material = temp;
			}
			while (f < faces);
			
			return renderInfo;
		}
		
		/**
		 * Create and upload texture
		 */
		private function createTexture(material:BitmapMaterial):void
		{
			if (!material || !material.bitmap) return;
			var bmp:BitmapData = material.bitmap;
			var texture:Texture = null;
			var n:int = bmps.length;
			for (var i:int = 0; i < n; i++)
				if (bmps[i] == bmp) {
					texture = textures[i];
					break;
				}
				
			if (!texture) 
			{
				texture = createAndUploadTexture(bmp, material.mipmap, material.smooth);
			}
			context.setTextureAt(1, texture);
		}
		
		/**
		 * Refresh texture
		 */
		public function invalidateTexture(bmp:BitmapData):void
		{
			var texture:Texture;
			var n:int = bmps.length;
			for (var i:int = 0; i < n; i++)
				if (bmps[i] == bmp) {
					texture = textures[i];
					textures[i] = null;
					bmps.splice(i, 1);
					textures.splice(i, 1);
					break;
				}
			if (texture) 
				texture.dispose();
		}
		
		/**
		 * Create program for this material
		 */
		private function setProgram(material:Material, blendMode:String, alpha:Number):Boolean 
		{
			var transparent:Boolean = false;
			var premultipliedAlphas:Boolean = true;
			var mipmap:Boolean = false;
			var additive:Boolean = blendMode == "add";
			var template:String;
			
			if (material is BitmapMaterial)
			{
				var bmat:BitmapMaterial = material as BitmapMaterial;
				
				// upload texture
				if (!bmat.bitmap) return false;
				createTexture(bmat);
				
				// options
				transparent = !bmat.opaque;
				premultipliedAlphas = bmat.premultipliedAlphas;
				mipmap = bmat.mipmap;
				
				// get program
				template = "bitmap";
				if (alpha < 1) template = "bitmap-opacity";
				
				if (!bmat._program) 
				{
					var textureOptions:String = "2d," 
						+ (bmat.repeat ? "repeat," : "clamp,")
						+ (bmat.smooth ? "linear," : "nearest,")
						+ (mipmap ? "miplinear" : "nomip");
					bmat._program = createAndCompileProgram(template, textureOptions);
				}
				
				// set active
				setBlendMode(additive, transparent, premultipliedAlphas);
				if (program != bmat._program) 
				{
					program = bmat._program;
					renderMode = template;
					context.setProgram(program);
				}
				return program != null;
			}
			
			else if (material is ColorMaterial)
			{
				var cmat:ColorMaterial = material as ColorMaterial;
				
				// clear texture
				context.setTextureAt(1, null);
				
				// options
				transparent = cmat.alpha < 1 || alpha < 1;
				
				// get program
				template = "color";
				if (alpha < 1) template = "color-opacity";
				
				if (!cmat._program) 
				{
					cmat._program = createAndCompileProgram(template, "");
				}
				
				// set active
				setBlendMode(additive, transparent, true);
				if (program != cmat._program) 
				{
					program = cmat._program;
					renderMode = template;
					context.setProgram(program);
				}
				return program != null;
			}
			return false;
		}
		
		/**
		 * Set GPU blending mode
		 */
		private function setBlendMode(additive:Boolean, transparent:Boolean, premultipliedAlphas:Boolean):void 
		{			
			if (additive)
			{
				if (premultipliedAlphas)
					context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE);
				else
					context.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA, Context3DBlendFactor.DESTINATION_ALPHA);
			}
			else
			{
				if (!transparent)
					context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
				else if (premultipliedAlphas)
					context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);
				else
					context.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);
			}
		}

		/**
		 * Create the vertext and fragment shaders that will run on the GPU
		 */
		private function createAndCompileProgram(template:String, textureOptions:String):Program3D 
		{
			var pid:String = template + ":" + textureOptions;
			if (programs[pid])
				return programs[pid];
			
			// get code
			var def:XMLList = PROGRAMS[template];
			if (!def.length()) {
				programs[pid] = null;
				return null;
			}
			var shaderCode:String = getCode(def.vertex);
			var fragmentCode:String = getCode(def.fragment).replace("<>", "<" + textureOptions + ">");
			
			// compile program
			var prog:Program3D = context.createProgram();
			
			var assembler:AGALMiniAssembler = new AGALMiniAssembler();
			var vertexShader:ByteArray = assembler.assemble(Context3DProgramType.VERTEX, shaderCode);
			var fragmentShader:ByteArray = assembler.assemble(Context3DProgramType.FRAGMENT, fragmentCode);
			
			// upload the combined program to the video Ram
			prog.upload(vertexShader, fragmentShader); 
			
			programs[pid] = prog;
			return prog;
		}
		
		private function getCode(code:String):String
		{
			var lines:Array = code.split(/[\r\n\t]+/g);
			for (var i:int = 0; i < lines.length; i++) 
			{
				var line:String = lines[i];
				if (line.indexOf("//") >= 0) lines[i] = line.split("//")[0];
			}
			return lines.join("\n");
		}
		
		private function createAndUploadTexture(bmp:BitmapData, mipmap:Boolean, smooth:Boolean):Texture 
		{
			var w:int = nearestPow2(bmp.width);
			var h:int = nearestPow2(bmp.height);
			var texture:Texture = context.createTexture(w, h, Context3DTextureFormat.BGRA, false);
			
			// mipmap texture generation
			if (mipmap && (w == h)) 
			{
				var s:int = w;
				var miplevel:int = 0;
				while (s > 0) {
					texture.uploadFromBitmapData(getResizedBitmapData(bmp, s, s, true, 0, smooth), miplevel);
					miplevel++; 
					s = s >> 1;
				}
			}
			else texture.uploadFromBitmapData(getResizedBitmapData(bmp, w, h, true, 0, smooth));
			
			bmps.push(bmp);
			textures.push(texture);
			return texture;
		}
		
		private function nearestPow2(v:int):int
		{
			var vo:int = Math.min(maxTextureSize, v * (1 - optimizeTextureSize));
			var p:int = 1;
			while (p < vo) p = p << 1;
			return p;
		}
		
		private function getResizedBitmapData(bmp:BitmapData, width:int, height:int, transparent:Boolean, background:uint, smooth:Boolean):BitmapData 
		{
			if (bmp.width == width && bmp.height == height) 
				return bmp;
			
			if (width < bmp.width) smooth = true; // always smooth reduced bitmaps 
			
			var b:BitmapData = new BitmapData(width, height, transparent, background);
			var m:Matrix = new Matrix();
			m.scale(width / bmp.width, height / bmp.height);
			b.draw(bmp, m, null, null, null, smooth);
			return b;
		}
	}
}


import away3dlite.materials.Material;
import flash.display3D.IndexBuffer3D;
import flash.display3D.VertexBuffer3D;
import flash.geom.Vector3D;

class MeshRenderInfo
{
	public var material:Vector.<Material>;
	public var vertexBuffer:Vector.<VertexBuffer3D>;
	public var vertexInfoFormat:Vector.<String>;
	public var indexBuffer:Vector.<IndexBuffer3D>;
	private var _clear:Boolean = true;
	
	public function MeshRenderInfo()
	{
		material = new Vector.<Material>();
		vertexBuffer = new Vector.<VertexBuffer3D>();
		vertexInfoFormat = new Vector.<String>();
		indexBuffer = new Vector.<IndexBuffer3D>();
	}
	
	public function dispose():void
	{
		_clear = true;
		material.length = 0;
		if (vertexBuffer.length) {
			for each(var vb:VertexBuffer3D in vertexBuffer)
				vb.dispose();
			vertexBuffer.length = 0;
		}
		if (indexBuffer) {
			for each(var ib:IndexBuffer3D in indexBuffer)
				ib.dispose();
			indexBuffer = null;
		}
	}
	
	public function get length():int { return material.length; }
	public function get clear():Boolean { return _clear; }
}
