### Represents a single party game.
class_name MinigameResource extends Resource

@export var localization_key : String
func get_description_key() -> String:
	return localization_key + "_desc"

@export_file("*.tscn") var scene_path : String
@export_range(1, 32, 1) var minigame_index : int = 1
