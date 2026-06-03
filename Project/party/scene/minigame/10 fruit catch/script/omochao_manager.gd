## Manages the omochaos and fruit throws in the fruit catch minigame.
extends Node

@export var omochaos : Array[CharacterAnimator]
@export var fruits : Array[Node3D]

func _ready() -> void:
	for i in omochaos.size():
		omochaos[i].play_animation("select")


## TODO Calculate a fruit position
func spawn_fruit() -> void:
	pass
