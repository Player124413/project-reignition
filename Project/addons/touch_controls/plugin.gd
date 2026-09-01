extends EditorPlugin
## Registers the Touch Controls addon in the Godot editor.

func _enter_tree() -> void:
	add_autoload_singleton("TouchControls", "res://addons/touch_controls/TouchControlsManager.gd")

func _exit_tree() -> void:
	remove_autoload_singleton("TouchControls")