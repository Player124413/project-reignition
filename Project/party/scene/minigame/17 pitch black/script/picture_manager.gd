class_name PictureManager extends Node3D

@export var env_animator: AnimationPlayer
@export var pictures: Array[Picture]
@export var players: Array[PartyGameCursorMover]

var frame_dict: Dictionary = {"Character": 0, "IncorrectNumber": 1}
var frame_dict_array: Array[Dictionary]

var characters: Array[Picture.CHARACTER]
var correction_num: Array[int]
##Current pic in sequence
var current_pic: int = 0
var rng: RandomNumberGenerator
##How many total pictures can we have in a round
const max_pictures: int = 49

func _ready() -> void:
	characters.resize(max_pictures)
	correction_num.resize(max_pictures)
	initialize_starting_picture()
	initialize_frame_array()
	return

##Setup demo picture
func initialize_starting_picture() -> void:
	rng = RandomNumberGenerator.new()
	set_character(Picture.CHARACTER.DEMO)
	pictures[0].set_incorrect_picture(1)

func initialize_frame_array():
	for i in range(max_pictures):
		frame_dict_array.append(frame_dict.duplicate())
	
	var num: int = 0
	for i in range(8): # Set characters
		for j in range(1, 7): # Set incorrect numbers
			frame_dict_array[num].set("Character", i)
			frame_dict_array[num].set("IncorrectNumber", j)
			num += 1
	frame_dict_array.shuffle()

func get_next_picture() -> void:
	var next_char: Picture.CHARACTER
	var next_int: int
	var incorrect_picture: int

	current_pic += 1
	next_char = frame_dict_array[current_pic].get("Character")
	next_int = frame_dict_array[current_pic].get("IncorrectNumber")
	incorrect_picture = rng.randi_range(0, 3)

	for picture in pictures:
		picture._character = next_char
		picture.set_correct_picture()
			
	pictures[incorrect_picture].set_incorrect_picture(next_int)
	
	return

func get_correct_picture_pos() -> Vector2:
	return Vector2.ZERO

func set_character(chara: Picture.CHARACTER):
	for pic in pictures:
		pic._character = chara

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
	for player in players:
		player._state = player.STATE.IDLE
		player.CPU_CAN_SEARCH = true
	await get_tree().create_timer(4).timeout
	get_next_picture()
	for pic in pictures:
		pic.animator.play("spin_btf")
