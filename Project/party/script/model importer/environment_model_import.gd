@tool # Needed so it runs in editor.
extends EditorScenePostImport

func _post_import(scene):
	process_child(scene)
	return scene

func process_child(node : Node) -> void:
	if node is MeshInstance3D:
		var mesh : MeshInstance3D = (node as MeshInstance3D)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # Default to No Shadows
		mesh.set_layer_mask_value(1, false)
		mesh.set_layer_mask_value(2, true)
	
	for child in node.get_children():
		process_child(child)
