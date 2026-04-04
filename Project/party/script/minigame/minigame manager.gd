### Place this node on the root of the
extends Node

## Library to attach to player animators when adding them to the scene
@export var anim_library : AnimationLibrary

## Where to spawn players.
@export var spawn_positions : Array[Node3D]

func _init() -> void:
	if PartyManager.get_player_data(0).character_data == null:
		initialize_debug_characters()

## Called when running a mini-game from the editor. Loads 4 default characters.
func initialize_debug_characters() -> void:
	print("Initializing default characters for debug mode.")
	for i in PartyManager.MAX_PLAYER_COUNT:
		var character_data : PartyCharacterResource = PartyManager._character_data.get(i)
		PartyManager.set_character_data(i, character_data.character_name)
