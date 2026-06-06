class_name TournamentPalaceWinCounter extends Control

@export var win_counters : Array[Control]
var win_animators : Array[AnimationPlayer]
var win_count : int

func _ready() -> void:
	for i in win_counters.size():
		win_animators.append(win_counters[i].get_node("AnimationPlayer"))

func set_max_win(count : int) -> void:
	for i in win_counters.size():
		win_counters[i].visible = i < count

func set_win() -> void:
	win_animators[win_count].play("win")
	win_count += 1

func reset_wins() -> void:
	win_count = 0
	for i in win_animators.size():
		win_animators[i].play("RESET")
		win_animators[i].advance(0.0)
