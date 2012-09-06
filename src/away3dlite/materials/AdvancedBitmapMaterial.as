package away3dlite.materials 
{
	import away3dlite.arcane;
	import flash.display.BitmapData;
	
	use namespace arcane;
	
	/**
	 * BitmapMaterial class with additional options to configure the shader
	 * @author Philippe
	 */
	public class AdvancedBitmapMaterial extends BitmapMaterial 
	{
		/** @private */
		protected var _mipmap:Boolean;
		/** @private */
		//protected var _transparent:Boolean;
		/** @private */
		protected var _precomputedAlphas:Boolean;
		
		/**
		 * Creates a new <code>BitmapMaterial</code> object.
		 * 
		 * @param	bitmap		The bitmapData object to be used as the material's texture.
		 */
		public function AdvancedBitmapMaterial(bitmap:BitmapData = null) 
		{
			super(bitmap);
		}
		
		/**
		 * Defines wether the Stage3D mipmapping should be used
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
		 * Defines wether to bitmap contains alpha transparency
		 
		public function get transparent():Boolean 
		{
			return _transparent;
		}
		
		public function set transparent(value:Boolean):void 
		{
			_transparent = value;
			_program = null;
		}*/
		
		/**
		 * Defines wether the bitmap needs pre-computed alphas correction
		 */
		public function get precomputedAlphas():Boolean 
		{
			return _precomputedAlphas;
		}
		
		public function set precomputedAlphas(value:Boolean):void 
		{
			_precomputedAlphas = value;
			_program = null;
		}
	}

}