class_name AttractionSettingOption extends Control

@export_range(1, 3, 1) var option_count : int = 1
@export var animator : AnimationPlayer
@export var double_option_selections : Array[Control]
@export var triple_option_selections : Array[Control]
var _current_selection : int

func _ready() -> void:
	double_option_selections[_current_selection].visible = true
	triple_option_selections[_current_selection].visible = true
	animator.play("option%s" % option_count)
	animator.advance(0.0)

func set_selection(index : int) -> void:
	if _current_selection < double_option_selections.size():
		double_option_selections[_current_selection].visible = false
	triple_option_selections[_current_selection].visible = false
	_current_selection = index
	if _current_selection < double_option_selections.size():
		double_option_selections[_current_selection].visible = true
	triple_option_selections[_current_selection].visible = true

func show_option() -> void:
	animator.play("show")

func hide_option() -> void:
	animator.play("hide")
