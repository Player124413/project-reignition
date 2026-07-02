class_name PictureManager extends Node3D

@export var env_animator: AnimationPlayer
@export var pictures: Array[Picture]
@export var players: Array[PicturePlayerController]
@export var camera: Camera3D
@export var sfx_rotate: GroupSfxPlayer
@export var sfx_blackout: GroupSfxPlayer

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

	MinigameManager.instance.minigame_finished.connect(Callable(self, "finish_game"))
	return

##Setup demo picture
func initialize_starting_picture() -> void:
	rng = RandomNumberGenerator.new()
	set_character(Picture.CHARACTER.DEMO)
	pictures[0].set_incorrect_picture(1, Picture.CHARACTER.DEMO)

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
	if !NetworkManager.is_hosting_game:
		return
	var next_char: Picture.CHARACTER
	var next_int: int
	var incorrect_picture: int

	current_pic += 1
	next_char = frame_dict_array[current_pic].get("Character")
	next_int = frame_dict_array[current_pic].get("IncorrectNumber")
	incorrect_picture = rng.randi_range(0, 3)

	for picture in pictures:
		picture.rpc("set_correct_picture", next_char)
		#picture._character = next_char
		#picture.set_correct_picture()
			
	#pictures[incorrect_picture].set_incorrect_picture(next_int)
	pictures[incorrect_picture].rpc("set_incorrect_picture", next_int, next_char)
	
	return

func get_correct_picture_pos() -> Vector2:
	for picture in pictures:
		if picture.wrong:
			return camera.unproject_position(picture.correction_circle.global_position)
	return Vector2.ZERO

func set_character(chara: Picture.CHARACTER):
	for pic in pictures:
		pic._character = chara

func play_correct_sequence() -> void:
	for player in players:
		player.cursor.visible = false
		player._state = player.STATE.BUSY
		player._cpu_state = PicturePlayerController.CPU_STATE.WAITING
		player.lamp.get_child(0).visible = false
		player.lamp_light.visible = false
		

	env_animator.play("blackout", -1, -1.0, true)
	for i in pictures.size():
		if pictures[i].wrong:
			pictures[i].play_correction_sequence()
			break
	
	await get_tree().create_timer(6).timeout

	sfx_rotate.play_in_group()
	for pic in pictures:
		pic.animator.play("spin_ftb")

	if !MinigameManager.instance.is_minigame_finished:
		env_animator.play("blackout")
	sfx_blackout.play_in_group()
	for player in players:
		player.cursor.visible = true
		player._state = player.STATE.IDLE
		player.lamp.get_child(0).visible = true
		player.lamp_light.visible = true

	if !players[0].is_demo_complete:
		await get_tree().create_timer(4).timeout
	else:
		await get_tree().create_timer(1).timeout

	get_next_picture()

	sfx_rotate.play_in_group()
	for pic in pictures:
		pic.animator.play("spin_btf")
	
	await get_tree().create_timer(1).timeout

	for player in players:
		player._cpu_state = PicturePlayerController.CPU_STATE.SEARCHING
		player.update_target_pos()
		player.cpu_search_timer.start(player.CPU_SEARCH_TIME)

func finish_game() -> void:
	env_animator.play("blackout", -1, -1.0, true)
	for player in players:
		player.cursor.visible = false
		player.lamp.visible = false

@rpc("any_peer", "call_local", "reliable")
func request_score_popup(player_index: int, score: int, screen_pos: Vector2) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	MinigameManager.instance.request_score_popup(player_index, score, screen_pos)
	MinigameManager.instance.request_score_change(player_index, score)
