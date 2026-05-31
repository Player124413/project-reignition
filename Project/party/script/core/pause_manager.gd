extends Menu

signal paused
signal unpaused

var _is_reading_pause_inputs : bool
var _is_cursor_movement_enabled : bool
@export var options : Array[Control]
@export var cursor : Control
@export var cursor_animator : AnimationPlayer

func process_cursor() -> void:
	if get_tree().paused:
		return
	
	if !_is_reading_pause_inputs:
		return
	
	if PartyManager.current_mode == PartyManager.CURRENT_MODE_ENUM.COUNT || (!is_minigame_active() && PartyManager.current_mode != PartyManager.CURRENT_MODE_ENUM.WORLD_LIBRARY):
		return
	
	for i in PartyManager.MAX_PLAYER_COUNT:
		var data : PlayerData = PartyManager.get_player_data(i)
		if data.is_cpu_player():
			continue
		
		var suffix : String = str(data.local_player_index)
		if Input.is_action_just_pressed("button_pause%s" % suffix):
			rpc("request_show_menu", i, NetworkManager.calculate_transition_tick())
			return

func enable_pause_inputs() -> void:
	_is_reading_pause_inputs = true

func disable_pause_inputs() -> void:
	_is_reading_pause_inputs = false

func update_cursor_position() -> void:
	cursor.global_position = options[current_selection.y].global_position
	cursor_animator.play("show")

func enable_cursor_movement() -> void:
	_is_cursor_movement_enabled = true

func disable_cursor_movement() -> void:
	_is_cursor_movement_enabled = false

@rpc("any_peer", "call_local", "reliable")
func request_show_menu(index : int, target_tick : float) -> void:
	disable_processing()
	_is_reading_pause_inputs = false
	await get_tree().create_timer(NetworkManager.calculate_transition_delay(target_tick)).timeout
	set_player_index(index)
	show_menu()

@rpc("any_peer", "call_local", "reliable")
func request_hide_menu(target_tick : float) -> void:
	disable_processing()
	_is_reading_pause_inputs = false
	await get_tree().create_timer(NetworkManager.calculate_transition_delay(target_tick)).timeout
	set_player_index(-1)
	hide_menu()

func update_selection() -> void:
	if !_is_cursor_movement_enabled:
		return
	if input_axis.y == 0:
		return
	
	var old_selection : int = current_selection.y
	current_selection.y = clamp(current_selection.y + input_axis.y, 0, options.size() - 1)
	if old_selection != current_selection.y:
		rpc("change_cursor_selection", current_selection.y)

@rpc("any_peer", "call_local", "reliable")
func change_cursor_selection(selection : int) -> void:
	current_selection.y = selection
	disable_cursor_movement()
	cursor_animator.play("hide")

func show_menu() -> void:
	get_tree().paused = true
	paused.emit()
	rpc("change_cursor_selection", 0)
	super()

func unpause_tree() -> void:
	get_tree().paused = false
	unpaused.emit()

## Called externally. Cancels any pause menu animations and unpauses the tree.
func request_cancel_pause_menu() -> void:
	if !is_multiplayer_authority() || !get_tree().paused:
		return
	rpc("cancel_pause_menu")

@rpc("any_peer", "call_local", "reliable")
func cancel_pause_menu() -> void:
	animator.play("RESET")
	animator.advance(0.0)
	animator.play("init")
	animator.advance(0.0)
	unpause_tree()

func cancel() -> void:
	rpc("request_hide_menu", NetworkManager.calculate_transition_tick())

func pause() -> void:
	rpc("request_hide_menu", NetworkManager.calculate_transition_tick())

func confirm() -> void:
	if current_selection.y == 0: # Unpause
		rpc("request_hide_menu", NetworkManager.calculate_transition_tick())
		return
	
	if is_minigame_active(): # In a minigame. Load back to attraction
		NetworkManager.rpc("unload_scene", MinigameManager.instance.minigame_resource.scene_path, NetworkManager.TRANSITION_TYPE_ENUM.ATTRACTION)
		if PartyManager.current_mode == PartyManager.CURRENT_MODE_ENUM.WORLD_LIBRARY:
			return
	# Exiting an attraction
	print("Exiting out of attractions is unimplemented.") # TODO Return to attactions menu, not just the attraction
	
func is_minigame_active() -> bool:
	return is_instance_valid(MinigameManager.instance)
