class_name ScorePopup extends Control

@export var animator : AnimationPlayer
@export var plus_label : Label
@export var amount_label : Label

## The network time at which this popup was spawned.
var spawn_time : float
## The network time at which this popup was spawned.
var player_index : int

signal repool 

func show_popup(index : int, score : int, screen_position : Vector2, time : float) -> void:
	spawn_time = time
	player_index = index
	global_position = screen_position
	amount_label.text = str(score)
	amount_label.label_settings = PartyManager.get_player_data(player_index).character_data.score_font
	plus_label.label_settings = amount_label.label_settings
	animator.seek(0.0)
	animator.play("show")

## Cancels a popup
func abort_popup() -> void:
	animator.play("init")
	animator.seek(0.0)
	repool.emit()

func on_animation_finished() -> void:
	repool.emit()
