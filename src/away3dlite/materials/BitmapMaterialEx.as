package away3dlite.materials 
{
	import away3dlite.arcane;
	import flash.display.BitmapData;
	
	use namespace arcane;
	
	/**
	 * BitmapMaterial class with additional options to configure the shader
	 * @author Philippe
	 */
	public class BitmapMaterialEx extends BitmapMaterial 
	{
		/** @private */
		protected var _mipmap:Boolean;
		/** @private */
		protected var _opaque:Boolean;
		/** @private */
		protected var _premultipliedAlphas:Boolean = true;
		
		/**
		 * Creates a new <code>BitmapMaterial</code> object.
		 * 
		 * @param	bitmap		The bitmapData object to be used as the material's texture.
		 * @param	opaque		Optimize rendering for non-transparent textures
		 * @param	mipmap		Generate mip-mapping textures (smoother display at reduced size)
		 */
		public function BitmapMaterialEx(bitmap:BitmapData = null, opaque:Boolean = true, mipmap:Boolean = false) 
		{
			super(bitmap);
			_opaque = opaque;
			_mipmap = mipmap;
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
	}

}