class_name CharacterSelectPreview extends Control

signal confirmed(index : int, selection : int, cursor_index : int)
signal cancelled(cursor_index : int)
signal anim_finished(port_index : int)

## Tracks the index of the cursor that is configuring this preview.
## Used to enable the cursor after finishing difficulty adjustments.
var cursor_index : int
## Index of the controller we're listening to inputs from.
var controller_index : int = -1
var current_difficulty : int = PlayerData.CPU_DIFFICULTY_ENUM.NORMAL
var is_scrolling : bool
var scroll_timer : float

@export var player_label : SyncedLabel
@export var character_label : SyncedLabel
@export var model_parent : Node3D
@export var animator : AnimationPlayer
@export var cursor : Control
@export var difficulty_options : Array[Label]

## Reference to the currently instanced model.
var instanced_model : CharacterAnimator
## Path of the model currently being shown.
var current_model_path : String
## How far apart the models should be in the 3d world.
const MODEL_POSITION_INCREMENT = 100

func initialize() -> void:
	animator.play("init")
	animator.advance(0.0)
	deselect()
	model_parent.global_position = Vector3.RIGHT * get_index() * MODEL_POSITION_INCREMENT

func show_preview() -> void:
	animator.play("show")
	var player_data : PlayerData = PartyManager.get_player_data(get_index())
	set_player_text(player_data.player_tag)
	character_label.set_synced_text("")

func _process(delta: float) -> void:
	process_model_loading()
	
	cursor.global_position = difficulty_options[current_difficulty].global_position
	
	if controller_index == -1 || !is_multiplayer_authority():
		return
	
	# Only process directions and selections when being shown
	var input_axis : int = sign(Input.get_axis("move_up" + str(controller_index), "move_down" + str(controller_index)))
	
	if input_axis == 0:
		is_scrolling = false
		scroll_timer = 0
	elif is_zero_approx(scroll_timer):
		rpc("set_difficulty", current_difficulty + input_axis)
		scroll_timer = Menu.SELECTION_SCROLLING_INTERVAL if is_scrolling else Menu.SELECTION_INTERVAL
		is_scrolling = true
	else:
		scroll_timer = move_toward(scroll_timer, 0, delta)
	if Input.is_action_just_pressed("button_primary" + str(controller_index)):
		controller_index = -1
		rpc("hide_difficulty")
		confirmed.emit(get_index(), current_difficulty, cursor_index)
	elif Input.is_action_just_pressed("button_secondary" + str(controller_index)):
		controller_index = -1
		rpc("hide_difficulty")
		cancelled.emit(cursor_index)

## Instances the model after it is loaded.
func process_model_loading() -> void:
	if current_model_path.is_empty() || is_instance_valid(instanced_model):
		return
	
	printt("Loading model " + current_model_path, ResourceLoader.load_threaded_get_status(current_model_path))
	if ResourceLoader.load_threaded_get_status(current_model_path) != ResourceLoader.THREAD_LOAD_LOADED:
		return
	
	# Instance model
	var model_scene : PackedScene = ResourceLoader.load_threaded_get(current_model_path) as PackedScene
	instanced_model = model_scene.instantiate() as CharacterAnimator
	model_parent.add_child(instanced_model)
	instanced_model.play_animation("select")
	instanced_model.play_voice("select")
	instanced_model.animation_event.connect(Callable(self, "on_select_finished"), CONNECT_ONE_SHOT)

# Tell Character Select screen we're done.
func on_select_finished(_info : int) -> void:
	anim_finished.emit(get_index())

## Sets the selected difficulty and updates the cursor's position.
@rpc("any_peer", "call_local", "reliable")
func set_difficulty(new_difficulty : int) -> void:
	if new_difficulty < 0:
		new_difficulty = PlayerData.CPU_DIFFICULTY_ENUM.COUNT - 1
	elif new_difficulty == PlayerData.CPU_DIFFICULTY_ENUM.COUNT:
		new_difficulty = 0
	current_difficulty = new_difficulty

@rpc("any_peer", "call_local", "reliable")
func show_difficulty(new_controller_index : int, device : int, new_cursor_index : int) -> void:
	print("Listening to controller %s on device %s" % [new_controller_index, device])
	cursor_index = new_cursor_index
	animator.play("show-cpu-difficulty")
	set_multiplayer_authority(device)
	set_difficulty(PlayerData.CPU_DIFFICULTY_ENUM.NORMAL)
	set_deferred("controller_index", new_controller_index)

@rpc("any_peer", "call_local", "reliable")
func hide_difficulty() -> void:
	controller_index = -1
	animator.play("hide-cpu-difficulty")
	set_multiplayer_authority(1)

@rpc("any_peer", "call_local", "reliable")
func set_player_text(text : String) -> void:
	if text.is_empty():
		# Use difficulty text
		text = difficulty_options[current_difficulty].text
	player_label.set_synced_text(text)

@rpc("any_peer", "call_local", "reliable")
func set_character_text(text : String) -> void:
	character_label.set_synced_text(text)

## Selects the character and loads the model
@rpc("authority", "call_local", "reliable")
func select(model_path : String) -> void:
	## Load character model
	current_model_path = model_path
	print("Started loading model " + current_model_path)
	if ResourceLoader.exists(current_model_path):
		ResourceLoader.load_threaded_request(current_model_path)

@rpc("authority", "call_local", "reliable")
func deselect() -> void:
	current_model_path = ""
	var player_data : PlayerData = PartyManager.get_player_data(get_index())
	set_player_text(player_data.player_tag)
	if is_instance_valid(instanced_model):
		# Delete instanced model
		instanced_model.queue_free()
