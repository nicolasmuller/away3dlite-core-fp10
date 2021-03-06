package away3dlite.core.render
{
	import away3dlite.arcane;
	import away3dlite.containers.*;
	import away3dlite.core.base.*;
	import away3dlite.core.clip.*;
	
	import flash.display.*;
	
	use namespace arcane;
	
	/**
	 * @author robbateman
	 */
	public class Renderer
	{
		/** @private */
		arcane function setView(view:View3D):void
		{
			_view = view;
			_view_graphics_drawGraphicsData = _view.graphics.drawGraphicsData;
		}
		
		private var k:int;
		private var q0:Vector.<int>;
		private var np0:Vector.<int>;
		private var _screenVertexArrays:Vector.<Vector.<Number>> = new Vector.<Vector.<Number>>();
        private var _screenVertices:Vector.<Number>;
        private var _screenPointVertexArrays:Vector.<Vector.<int>> = new Vector.<Vector.<int>>();
        private var _screenPointVertices:Vector.<int>;
        private var _index:int;
    	private var _indexX:int;
    	private var _indexY:int;
        /** @private */
		protected var i:int;
		/** @private */
		protected var j:int;
		/** @private */
		protected var q1:Vector.<int>;
		/** @private */
		protected var np1:Vector.<int>;
		/** @private */
		protected var _view:View3D;
		/** @private */
		protected var _scene:Scene3D;
		/** @private */
		protected var _face:Face;
		/** @private */
		protected var _faces:Vector.<Face> = new Vector.<Face>();
		/** @private */
		protected var _sort:Vector.<int> = new Vector.<int>();
		/** @private */
		protected var _faceStore:Vector.<int> = new Vector.<int>();
		/** @private */
		protected var _clipping:Clipping;
		/** @private */
		protected var _screenZ:int;
		/** @private */
		protected var _pointFace:Face;
		/** @private */
        protected var _mouseEnabled:Boolean;
        /** @private */
        protected var _mouseEnabledArray:Vector.<Boolean> = new Vector.<Boolean>();
        /** @private */
    	protected var _ind:Vector.<int>;
    	/** @private */
		protected var _vert:Vector.<Number>;
		/** @private */
		protected var _uvt:Vector.<Number>;
		/** @private */
		protected var _triangles:GraphicsTrianglePath = new GraphicsTrianglePath();
		/** @private */
		protected var _view_graphics_drawGraphicsData:Function;
		
		/** @private */
		protected function sortFaces():void
		{
	        // by pass
	        var _faces_length_1:int = int(_faces.length + 1);
	        
	        q0 = new Vector.<int>(256, true);
	        q1 = new Vector.<int>(256, true);
	        np0 = new Vector.<int>(_faces_length_1, true);
	        np1 = new Vector.<int>(_faces_length_1, true);
	        
            i = 0;
        	j = 0;
        	
            for each (_face in _faces) {
				np0[int(i+1)] = q0[k = (255 & (_sort[i] = _face.calculateScreenZ()))];
				q0[k] = int(++i);
            }
			
			i = 256;
			while (i--) {
				j = q0[i];
				while (j) {
					np1[j] = q1[k = (65280 & _sort[int(j-1)]) >> 8];
					j = np0[q1[k] = j];
				}
			}
		}
		
		/** @private */
		protected function collectPointFace(x:Number, y:Number):void
		{
			var pointCount:int;
			var pointTotal:int;
        	var pointCountX:int;
        	var pointCountY:int;
        	var i:int = _faces.length;
			while (i--) {
				if (_screenZ < _sort[i] && (_face = _faces[i]).mesh._mouseEnabled) {
					_screenPointVertices = _screenPointVertexArrays[_face.mesh._vertexId];
					
					if (_face.i3) {
        				pointTotal = 4;
	    				pointCount = _screenPointVertices[_face.i0] + _screenPointVertices[_face.i1] + _screenPointVertices[_face.i2] + _screenPointVertices[_face.i3];
					} else {
        				pointTotal = 3;
	    				pointCount = _screenPointVertices[_face.i0] + _screenPointVertices[_face.i1] + _screenPointVertices[_face.i2];
					}
	    			pointCountX = (pointCount >> 4);
	    			pointCountY = (pointCount & 15);
	    			if (pointCountX && pointCountX < pointTotal && pointCountY && pointCountY < pointTotal) {
	    				
	    				//flagged for edge detection
	    				var vertices:Vector.<Number> = _face.mesh._screenVertices;
						var v0x:Number = vertices[_face.x0];
						var v0y:Number = vertices[_face.y0];
						var v1x:Number = vertices[_face.x1];
						var v1y:Number = vertices[_face.y1];
						var v2x:Number = vertices[_face.x2];
						var v2y:Number = vertices[_face.y2];
						
						if ((v0x*(y - v1y) + v1x*(v0y - y) + x*(v1y - v0y)) < -0.001)
			                continue;
			
			            if ((x*(v2y - v1y) + v1x*(y - v2y) + v2x*(v1y - y)) < -0.001)
			                continue;
			            
			            if (_face.i3) {
			            	var v3x:Number = vertices[_face.x3];
							var v3y:Number = vertices[_face.y3];
							
			            	if ((v3x*(v2y - y) + x*(v3y - v2y) + v2x*(y - v3y)) < -0.001)
			            		continue;
			            	
			            	if ((v0x*(v3y - y) + x*(v0y - v3y) + v3x*(y - v0y)) < -0.001)
			            		continue;
			            	
			            } else if ((v0x*(v2y - y) + x*(v0y - v2y) + v2x*(y - v0y)) < -0.001) {
			                continue;
			            }
			            
	    				_screenZ = _sort[i];
						_pointFace = _face;
					}
				}
			}
		}
		
		/** @private */
		protected function collectScreenVertices(mesh:Mesh):void
		{
			mesh._vertexId = _screenVertexArrays.length;
			_screenVertexArrays.push(mesh._screenVertices);
		}
		
		/** @private */
		protected function collectPointVertices(x:Number, y:Number):void
		{
			_screenPointVertexArrays.fixed = false;
        	_screenPointVertexArrays.length = _screenVertexArrays.length;
        	_screenPointVertexArrays.fixed = true;
        	
        	var i:int = _screenVertexArrays.length;
        	
        	while (i--) {
				_screenVertices = _screenVertexArrays[i];
				_screenPointVertices = _screenPointVertexArrays[i] = new Vector.<int>(_index = _screenVertices.length/2, true);
        		
	        	while (_index--) {
	        		_indexY = (_indexX = _index*2) + 1;
	        		
	        		if (_screenVertices[_indexX] < x)
	        			_screenPointVertices[_index] += 0x10;
	        		
	        		if (_screenVertices[_indexY] < y)
	        			_screenPointVertices[_index] += 0x1;
	        	}
        	}
		}
		
		/**
		 * Creates a new <code>Renderer</code> object.
		 */
		function Renderer()
		{
			_ind = _triangles.indices = new Vector.<int>();
			_vert = _triangles.vertices = new Vector.<Number>();
			_uvt = _triangles.uvtData = new Vector.<Number>();
		}
		
		/**
		 * Returns the face object directly under the given point.
		 * 
		 * @param x		The x coordinate of the point.
		 * @param y		The y coordinate of the point.
		 */
		public function getFaceUnderPoint(x:Number, y:Number):Face
		{
			x;
			y;
			return null;
		}
		
		/**
		 * Renders the contents of the scene to the view.
		 * 
		 * @see awa3dlite.containers.Scene3D
		 * @see awa3dlite.containers.View3D
		 */
		public function render():void
		{
			_scene = _view.scene;
			
			_clipping = _view.screenClipping;
			
			_mouseEnabled = _scene.mouseEnabled;
			_mouseEnabledArray.length = 0;
			_pointFace = null;
			
			_screenVertexArrays.length = 0;
		}
		
		public function dispose():void 
		{
			_screenVertexArrays = null;
			_screenVertices = null;
			_screenPointVertexArrays = null;
			_screenPointVertices = null;
			_faces = null;
			_face = null;
			_faceStore = null;
			_sort = null;
			_mouseEnabledArray = null;
			q0 = null;
			np0 = null;
			q1 = null;
			np1 = null;
			_ind = null;
			_vert = null;
			_uvt = null;
			_view_graphics_drawGraphicsData = null;
			_view = null;
			_scene = null;
		}
	}
}
