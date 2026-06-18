class_name PictureManager extends Node3D

@export var picture: Array[Picture]
var characters: Array[Picture.CHARACTER]
var correction_num: Array[int]
var current_pic: int = 0
const max_pictures: int = 49

func _ready() -> void:
	characters.resize(max_pictures)
	correction_num.resize(max_pictures)
	initialize_starting_picture()
	return

##Setup demo picture
func initialize_starting_picture() -> void:
	set_character(Picture.CHARACTER.DEMO)
	picture[0].set_incorrect_picture(1)
	characters[0] = Picture.CHARACTER.DEMO
	correction_num[0] = 1

func set_character(chara: Picture.CHARACTER):
	for pic in picture:
		pic._character = chara

func is_dupe(num: int) -> bool:
	return false

func play_correct_sequence() -> void:
	for i in range(4):
		if picture[i].wrong:
			picture[i].play_correction_sequence()
			return
