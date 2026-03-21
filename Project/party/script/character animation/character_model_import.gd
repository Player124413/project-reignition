@tool # Needed so it runs in editor.
extends EditorScenePostImport

func _post_import(scene):
	var script = load("res://party/script/character animation/character_feature_animator.gd")
	scene.get_child(0).name = "CharacterRoot"
	var skeleton = scene.get_child(0).get_child(0)
	skeleton.set_script(script)
	skeleton.update_meshes()
	return scene
