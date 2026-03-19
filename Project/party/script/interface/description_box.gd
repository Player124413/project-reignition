### Description/dialog box for party mode.
class_name DescriptionBox extends Control

@export var animator : AnimationPlayer
@export var label : Label

func set_text(text : String) -> void:
	label.text = text

func show_description() -> void:
	animator.play("show")
	animator.seek(0, true)

func show_button() -> void:
	animator.play("show-button")
	animator.advance(0.0)

func hide_button() -> void:
	animator.play("hide-button")
	animator.advance(0.0)

func hide_description() -> void:
	animator.play("hide")
	animator.seek(0, true)
