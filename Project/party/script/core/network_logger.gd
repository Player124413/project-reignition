extends Control

@export var label : Label
@export var animator : AnimationPlayer

func log_message(message : StringName) -> void:
	label.text = message
	animator.play("show")
	animator.advance(0.0)
