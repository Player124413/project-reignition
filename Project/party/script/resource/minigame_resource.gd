### Represents a single party game.
class_name MinigameResource extends Resource

@export var localization_key : String
## How many entries of descriptions does this minigame have?
@export var description_count : int = 1

@export var thumbnail : Texture2D

@export_file("*.tscn") var scene_path : String
@export_range(1, 32, 1) var minigame_index : int = 1

@export var descriptions : PackedStringArray
