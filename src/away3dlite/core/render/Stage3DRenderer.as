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
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DTriangleFace;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.textures.Texture;
	import flash.display3D.VertexBuffer3D;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	import flash.geom.Matrix3D;
	import flash.geom.Utils3D;
	import flash.geom.Vector3D;
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
		private var _mesh:Mesh;
		private var _screenVertices:Vector.<Number>;
		private var _uvtData:Vector.<Number>;
		private var _material:Material;
		private var _i:int;
		private var _j:int;
		private var _k:int;
		
		private var _material_graphicsData:Vector.<IGraphicsData>;
		
		// Layer
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
			
			if (_view.mouseEnabled3D) collectFaces(_scene);
			
			_faces.fixed = true;
			
			_view._renderedFaces = _faces.length;
			
			render3D();
			
			if (!_faces.length)
				return;
			
			_sort.fixed = false;
			_sort.length = _faces.length;
			_sort.fixed = true;
			
			if (_view.mouseEnabled3D) sortFaces();
		}
		
		/* STAGE 3D RENDER */
		
		private function render3D():void 
		{
			if (!stageReady()) return;
			
			// clear
			var rgb:int = stage.color & 0xffffff;
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
			renderContainer(_view.scene, mProjection);
			
			context.present();
		}
		
		private function renderContainer(cont:ObjectContainer3D, mParent:Matrix3D):void 
		{
			for each(var c:Object3D in cont.children)
			{
				if (!c.visible) continue;
				
				c.viewMatrix3D.copyRawDataFrom(mParent.rawData);
				c.viewMatrix3D.prepend(c.transform.matrix3D);
				
				c._screenPosition = Utils3D.projectVector(c.viewMatrix3D, zero);
				c._screenPosition.x *= stageWidth / 2;
				c._screenPosition.y *= -stageHeight / 2;
				
				if (c is ObjectContainer3D) renderContainer(c as ObjectContainer3D, c.viewMatrix3D);
				else if (c is Mesh) 
				{
					var mesh:Mesh = c as Mesh;
					if (mesh._indices.length && setProgram(mesh.material))
					{
						var renderInfo:MeshRenderInfo = prepareMeshBuffers(mesh);
						context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, c.viewMatrix3D, true);
						context.drawTriangles(renderInfo.indexBuffer);
					}
				}
			}
		}
		
		/* STAGE 3D SETUP */ 
		
		public var culling:String = "front";
		public var contextID:int = 0;
		
		arcane var stage:Stage;
		arcane var stageWidth:int;
		arcane var stageHeight:int;
		arcane var context:Context3D;
		arcane var program:Program3D;
		arcane var programs:Object = {};
		arcane var mProjection:Matrix3D = new Matrix3D();
		arcane var zero:Vector3D = new Vector3D();
		arcane var projection:PerspectiveMatrix3D = new PerspectiveMatrix3D();
		arcane var sceneScale:Number = 1/100;
		arcane var bmps:Vector.<BitmapData> = new Vector.<BitmapData>();
		arcane var textures:Vector.<Texture> = new Vector.<Texture>();
		arcane var toDispose:Vector.<Mesh> = new Vector.<Mesh>();
		arcane var PROGRAMS:XML = <programs>
			<color>
				<vertex><![CDATA[
					m44 op, va0, vc0	// m44 to output point
					mov v0, va1			// interpolate the UVs (va0) into variable register v1
				]]></vertex>
				<fragment><![CDATA[
					tex oc v0, fs0 <>	// sample the texture (fs0) at the interpolated UV coordinates (v0) and output
				]]></fragment>
			</color>
			<bitmap>
				<vertex><![CDATA[
					m44 op, va0, vc0	// m44 to output point
					mov v0, va1			// interpolate the UVs (va0) into variable register v1
				]]></vertex>
				<fragment><![CDATA[
					tex oc v0, fs0 <>	// sample the texture (fs0) at the interpolated UV coordinates (v0) and output
				]]></fragment>
			</bitmap>
			<!--<bitmap-transparency>
				<vertex><![CDATA[
					m44 op, va0, vc0	// m44 to output point
					mov v0, va1			// interpolate the UVs (va0) into variable register v1
				]]></vertex>
				<fragment><![CDATA[
					tex oc v0, fs0 <>	// sample the texture (fs0) at the interpolated UV coordinates (v0) and output
				]]></fragment>
			</bitmap-transparency>-->
			<!--<bitmap-precomputed>
				<vertex><![CDATA[
					m44 op, va0, vc0	// m44 to output point
					mov v0, va1			// interpolate the UVs (va0) into variable register v1
				]]></vertex>
				<fragment><![CDATA[
					tex oc v0, fs0 <>	// sample the texture (fs0) at the interpolated UV coordinates (v0) and output
				]]></fragment>
			</bitmap-precomputed>-->
		</programs>;
		
		private function init():void
		{
			if (this.stage) dispose();
			this.stage = _view.stage;
			
			// wait for Stage3D to provide us a Context3D
			stage.stage3Ds[contextID].addEventListener(Event.CONTEXT3D_CREATE, context3dCreate);
			stage.stage3Ds[contextID].requestContext3D();
			
			stage.addEventListener(MouseEvent.MOUSE_MOVE, stage_mouse);
			
			_view.addEventListener(Event.REMOVED_FROM_STAGE, dispose);
		}
		
		private function dispose(e:Event = null):void
		{
			_view.removeEventListener(Event.REMOVED_FROM_STAGE, dispose);
			
			recycle();
			
			stage.stage3Ds[contextID].removeEventListener(Event.CONTEXT3D_CREATE, context3dCreate);
			if (context) {
				context.dispose();
				context = null;
			}
			
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, stage_mouse);
			stage = null;
		}
		
		/**
		 * Dispose all programs and buffers
		 */
		public function recycle():void 
		{
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
		}
		
		private function stage_mouse(e:MouseEvent):void 
		{
			if (_view && context && e.target == stage) _view.fireMouseEvent(e.type, e.ctrlKey, e.shiftKey);
		}
		
		/**
		 * We've got a 3D context
		 */
		private function context3dCreate(event:Event):void 
		{
			context = event.target.context3D;	
			context.enableErrorChecking = true;
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
				projection.perspectiveLH(w * r, w, 0.9, 1000);
				
				// setup context
				context.configureBackBuffer(stageWidth, stageHeight, 2, true);
				//context.setDepthTest(true, Context3DCompareMode.LESS);
				context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);
			}
		}
		
		/**
		 * Configure buffers
		 */
		private function prepareMeshBuffers(mesh:Mesh):MeshRenderInfo 
		{
			var renderInfo:MeshRenderInfo = updateMeshBuffers(mesh);
			
			// copy in register "0", from the buffer "vertexBuffer, starting from the postion "0" the FLOAT_3 next number
			context.setVertexBufferAt(0, renderInfo.vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3); // register "0" now contains x,y,z
			// copy in register "1" from "vertexBuffer", starting from index "3", the next FLOAT_3 numbers
			context.setVertexBufferAt(1, renderInfo.vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_3); // register 1 now contains u,v,t
			
			return renderInfo;
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
			
			// vertex buffer
			var vertexData:Vector.<Number> = new Vector.<Number>();
			var vertices:Vector.<Number> = mesh._vertices;
			var uvs:Vector.<Number> = mesh._uvtData;
			var count:int = vertices.length / 3;
			renderInfo.vertexBuffer = context.createVertexBuffer(count, 6);
			var vindex:int = 0;
			var tindex:int = 0;
			for (var i:int = 0; i < count; i++, vindex+=3, tindex+=3)
			{
				vertexData.push(
					vertices[vindex], vertices[vindex + 1], vertices[vindex + 2], 
					uvs[tindex], uvs[tindex + 1], uvs[tindex + 2]);
			}
			renderInfo.vertexBuffer.uploadFromVector(vertexData, 0, count);
			
			// index buffer
			var facelens:Vector.<int> = mesh._faceLengths;
			var indices:Vector.<int> = mesh._indices;
			var indexes:Vector.<uint> = new Vector.<uint>();
			var iindex:int = 0;
			for each(var len:int in facelens) 
			{
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
			
			count = indexes.length;
			renderInfo.indexBuffer = context.createIndexBuffer(count);
			renderInfo.indexBuffer.uploadFromVector(indexes, 0, count);
			
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
				var mipmap:Boolean = false;
				if (material is AdvancedBitmapMaterial && (material as AdvancedBitmapMaterial).mipmap)
					mipmap = true;
				texture = createAndUploadTexture(bmp, mipmap);
			}
			context.setTextureAt(0, texture);
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
		private function setProgram(material:Material):Boolean 
		{
			// TODO shader fixing precomputed alphas
			// TODO shader for ColorMaterial
			if (material is BitmapMaterial)
			{
				var bmat:BitmapMaterial = material as BitmapMaterial;
				
				// upload texture
				if (!bmat.bitmap) return false;
				createTexture(bmat);
				
				// get program
				if (!bmat._program) 
				{
					var template:String = "bitmap";
					var textureOptions:String = "2d," 
						+ (bmat.repeat ? "repeat," : "clamp,")
						+ (bmat.smooth ? "linear," : "nearest,");
					
					if (material is AdvancedBitmapMaterial)
					{
						var amat:AdvancedBitmapMaterial = material as AdvancedBitmapMaterial;
						//if (amat.transparent) template += "-transparency";
						//if (amat.precomputedAlphas) template += "-precomputed";
						textureOptions += (amat.mipmap ? "miplinear" : "nomip");						
					}
					else textureOptions += "nomip";
					
					bmat._program = createAndCompileProgram(template, textureOptions);
				}
				// set active
				if (program != bmat._program) 
				{
					program = bmat._program;
					context.setProgram(program);
				}
				return program != null;
			}
			return false;
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
		
		private function createAndUploadTexture(bmp:BitmapData, mipmap:Boolean):Texture 
		{
			var texture:Texture = context.createTexture(bmp.width, bmp.height, Context3DTextureFormat.BGRA, false);
			
			// mipmap texture generation
			if (mipmap && bmp.width == bmp.height) 
			{
				texture.uploadFromBitmapData(bmp, 0);
				var s:int = bmp.width >> 1;
				var miplevel:int = 1;
				while (s > 0) {
					texture.uploadFromBitmapData(getResizedBitmapData(bmp, s, s, true, 0), miplevel);
					miplevel++; 
					s = s >> 1;
				}
			}
			else texture.uploadFromBitmapData(bmp);
			
			bmps.push(bmp);
			textures.push(texture);
			return texture;
		}
		
		private function getResizedBitmapData(bmp:BitmapData, width:int, height:int, transparent:Boolean, background:uint):BitmapData 
		{
			var b:BitmapData = new BitmapData(width, height, transparent, background);
			var m:Matrix = new Matrix();
			m.scale(width / bmp.width, height / bmp.height);
			b.draw(bmp, m, null, null, null, true);
			return b;
		}
	}
}


import flash.display3D.IndexBuffer3D;
import flash.display3D.VertexBuffer3D;
import flash.geom.Vector3D;

class MeshRenderInfo
{	
	public var vertexBuffer:VertexBuffer3D;
	public var indexBuffer:IndexBuffer3D;
	public var screenPosition:Vector3D;
	
	public function MeshRenderInfo()
	{
	}
	
	public function dispose():void
	{
		if (vertexBuffer) {
			vertexBuffer.dispose();
			vertexBuffer = null;
		}
		if (indexBuffer) {
			indexBuffer.dispose();
			indexBuffer = null;
		}
	}
}
