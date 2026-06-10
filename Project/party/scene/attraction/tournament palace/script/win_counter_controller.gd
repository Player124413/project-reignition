class_name TournamentPalaceWinCounter extends Control

@export var round_win : AudioStreamPlayer
@export var bracket_win : AudioStreamPlayer
@export var win_counters : Array[Control]
var win_animators : Array[AnimationPlayer]
var win_count : int
var _max_win : int

func _ready() -> void:
	for i in win_counters.size():
		win_animators.append(win_counters[i].get_node("AnimationPlayer"))

func set_max_win(count : int) -> void:
	_max_win = count
	for i in win_counters.size():
		win_counters[i].visible = i < count

func set_win() -> void:
	win_animators[win_count].play("win")
	win_count += 1
	round_win.play()
	if win_count >= _max_win:
		bracket_win.play()

func reset_wins() -> void:
	win_count = 0
	for i in win_animators.size():
		win_animators[i].play("RESET")
		win_animators[i].advance(0.0)
