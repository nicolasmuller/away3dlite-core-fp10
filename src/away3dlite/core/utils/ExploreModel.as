package away3dlite.core.utils 
{
	import away3dlite.containers.ObjectContainer3D;
	import away3dlite.core.base.Mesh;
	import away3dlite.core.base.Object3D;
	
	/**
	 * ...
	 * @author Philippe
	 */
	public class ExploreModel 
	{
		
		static public function allChildren(container:ObjectContainer3D, onAny:Function, onMesh:Function = null, onContainer:Function = null):void
		{
			for each(var c:Object3D in container.children)
			{
				if (onAny != null) if (!onAny(c)) return;
				if (c is ObjectContainer3D) 
				{
					if (onContainer != null) if (!onContainer(c)) return;
					allChildren(c as ObjectContainer3D, onAny, onMesh, onContainer);
				}
				else if (c is Mesh) 
				{
					var m:Mesh = c as Mesh;
					if (onMesh != null) if (!onMesh(m)) return;
				}
			}
		}
		
	}

}