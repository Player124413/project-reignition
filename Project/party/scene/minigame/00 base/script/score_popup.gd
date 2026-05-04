class_name ScorePopup extends Control

@export var animator : AnimationPlayer
@export var plus_label : Label
@export var amount_label : Label

signal repool 

func show_popup(player_index : int, score : int, screen_position : Vector2) -> void:
	global_position = screen_position
	amount_label.text = str(score)
	amount_label.label_settings = PartyManager.get_player_data(player_index).character_data.score_font
	plus_label.label_settings = amount_label.label_settings
	animator.seek(0.0)
	animator.play("show")

func on_animation_finished() -> void:
	repool.emit()
