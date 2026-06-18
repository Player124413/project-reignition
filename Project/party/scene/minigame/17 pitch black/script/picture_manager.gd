class_name PictureManager extends Node3D

@export var env_animator: AnimationPlayer
@export var pictures: Array[Picture]
var characters: Array[Picture.CHARACTER]
var correction_num: Array[int]
var current_pic: int = 0
##How many total pictures can we have in a round
const max_pictures: int = 49

func _ready() -> void:
	characters.resize(max_pictures)
	correction_num.resize(max_pictures)
	initialize_starting_picture()
	return

##Setup demo picture
func initialize_starting_picture() -> void:
	set_character(Picture.CHARACTER.DEMO)
	pictures[0].set_incorrect_picture(1)
	characters[0] = Picture.CHARACTER.DEMO
	correction_num[0] = 1

func get_next_picture() -> void:
	return

func set_character(chara: Picture.CHARACTER):
	for pic in pictures:
		pic._character = chara

func is_dupe(num: int) -> bool:
	return false

func play_correct_sequence() -> void:
	env_animator.play("blackout", -1, -1.0, true)
	for i in pictures.size():
		if pictures[i].wrong:
			pictures[i].play_correction_sequence()
			break
	await get_tree().create_timer(6).timeout
	for pic in pictures:
		pic.animator.play("spin_ftb")

	env_animator.play("blackout")
	await get_tree().create_timer(4).timeout
	get_next_picture()
	
	for pic in pictures:
		pic.animator.play("spin_btf")
