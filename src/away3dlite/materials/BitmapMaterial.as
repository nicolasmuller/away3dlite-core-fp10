package away3dlite.materials
{
	import away3dlite.arcane;
	import flash.display.*;
	
	use namespace arcane;
	
    /**
     * Basic bitmap material
     */
	public class BitmapMaterial extends Material
	{
		public var source:String;
		
		/** @private Stage3DRenderer */
		protected var _mipmap:Boolean = false;
		/** @private Stage3DRenderer */
		protected var _opaque:Boolean = true;
		/** @private Stage3DRenderer */
		protected var _premultipliedAlphas:Boolean = true;
		
		/**
		 * Defines the bitmapData object to be used as the material's texture.
		 */
		public function get bitmap():BitmapData
		{
			return _graphicsBitmapFill.bitmapData;
		}
		
		public function set bitmap(val:BitmapData):void
		{
			_graphicsBitmapFill.bitmapData = val;
		}
		
		/**
		 * Defines whether repeat is used when drawing the material.
		 */
		public function get repeat():Boolean
		{
			return _graphicsBitmapFill.repeat;
		}
		
		public function set repeat(val:Boolean):void
		{
			_graphicsBitmapFill.repeat = val;
			_program = null;
		}
		
		/**
		 * Defines whether smoothing is used when drawing the material.
		 */
		public function get smooth():Boolean
		{
			return _graphicsBitmapFill.smooth;
		}
		
		public function set smooth(val:Boolean):void
		{
			_graphicsBitmapFill.smooth = val;
			_program = null;
		}
		
		/**
		 * Returns the width of the material's bitmapdata object.
		 */
		public function get width():int
		{
			return _graphicsBitmapFill.bitmapData.width;
		}
		
		/**
		 * Returns the height of the material's bitmapdata object.
		 */
		public function get height():int
		{
			return _graphicsBitmapFill.bitmapData.height;
		}
		
		/**
		 * Defines wether the Stage3D mipmapping should be used (smoother display at reduced size)
		 */
		public function get mipmap():Boolean 
		{
			return _mipmap;
		}
		
		public function set mipmap(value:Boolean):void 
		{
			_mipmap = value;
			_program = null;
		}
		
		/**
		 * Defines wether to bitmap rendering can be optimized for non-transparent blending
		 */
		public function get opaque():Boolean 
		{
			return _opaque;
		}
		
		public function set opaque(value:Boolean):void 
		{
			_opaque = value;
			_program = null;
		}
		
		/**
		 * Defines wether the bitmap needs pre-computed alphas correction (true for Flash bitmapDatas)
		 */
		public function get premultipliedAlphas():Boolean 
		{
			return _premultipliedAlphas;
		}
		
		public function set premultipliedAlphas(value:Boolean):void 
		{
			_premultipliedAlphas = value;
			_program = null;
		}
        
		/**
		 * Creates a new <code>BitmapMaterial</code> object.
		 * 
		 * @param	bitmap		The bitmapData object to be used as the material's texture.
		 * @param	opaque		(Stage3D) Optimize rendering for non-transparent textures 
		 * @param	mipmap		(Stage3D) Generate mip-mapping textures (smoother display at reduced size)
		 */
		public function BitmapMaterial(bitmap:BitmapData = null, opaque:Boolean = true, mipmap:Boolean = false)
		{
			super();
			_opaque = opaque;
			_mipmap = mipmap;
			
			_graphicsBitmapFill.bitmapData = bitmap || new BitmapData(100, 100, false, 0x000000);
			
			graphicsData = Vector.<IGraphicsData>([_graphicsStroke, _graphicsBitmapFill, _triangles, _graphicsEndFill]);
			graphicsData.fixed = true;
			
			trianglesIndex = 2;
		}
	}
}