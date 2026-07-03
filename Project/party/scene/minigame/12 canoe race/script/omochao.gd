extends Node

@export var animator : AnimationPlayer

func _ready() -> void:
	# Randomize animations so omochaos aren't in sync with each other
	animator.seek(randf() * animator.current_animation_length)
