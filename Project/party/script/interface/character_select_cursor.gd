extends Control

## Emitted when the cursor moves in a direction.
signal moved(index : int, direction : Vector2i)
## Emitted when the cursor confirms a selection.
signal confirmed(index : int)
## Emitted when the cursor cancels a selection.
signal cancelled(index : int)
## Emitted when the cursor updates a random selection.
signal update_random(index : int)

@export var player_label : SyncedLabel
@export var animator : AnimationPlayer
## Index of the port currently being configured.
var port_index : int
## Index of the controller to read inputs from.
var controller_index : int
## Tracks whether the player is scrolling.
var is_scrolling : bool
## Tracks the current scroll time.
var scroll_timer : float

## Is the cursor currently scrolling to select random?
var is_selecting_random : bool
## How many times to cycle randomly before visually choosing the character.
var random_count : int

## Tracks the currently select portrait. Read and modified from the select menu.
var current_selection : Vector2i

## Tracks whether this cursor is listening to player inputs.
var is_processing_inputs : bool
## Tracks whether this cursor has finished making all of its selections.
var is_hidden : bool

func _process(delta: float) -> void:
	if !is_processing_inputs || (NetworkManager.is_online && !is_multiplayer_authority()):
		return
	
	if is_selecting_random:
		if is_zero_approx(scroll_timer):
			update_random.emit(get_index())
			scroll_timer = Menu.SELECTION_SCROLLING_INTERVAL
		else:
			scroll_timer = move_toward(scroll_timer, 0, delta)
		return
	
	if !is_hidden:
		# Only process directions and selections when being shown
		var input_axis : Vector2i = Vector2i.ZERO
		if !is_selecting_random:
			input_axis.x = sign(Input.get_axis("move_left" + str(controller_index), "move_right" + str(controller_index)))
			input_axis.y = sign(Input.get_axis("move_up" + str(controller_index), "move_down" + str(controller_index)))
		
		if input_axis == Vector2i.ZERO:
			is_scrolling = false
			scroll_timer = 0
		elif is_zero_approx(scroll_timer):
			# Emit a movement signal for the character select menu to handle
			moved.emit(get_index(), input_axis)
			scroll_timer = Menu.SELECTION_SCROLLING_INTERVAL if is_scrolling else Menu.SELECTION_INTERVAL
			is_scrolling = true
		else:
			scroll_timer = move_toward(scroll_timer, 0, delta)
		if Input.is_action_just_pressed("button_primary" + str(controller_index)):
			confirm()
	
	if Input.is_action_just_pressed("button_secondary" + str(controller_index)):
		cancel()

## Emits a confirmation signal for the character select menu to handle.
func confirm() -> void:
	disable_processing()
	confirmed.emit(get_index())

## Emits a cancellation signal for the character select menu to handle.
func cancel() -> void:
	disable_processing()
	cancelled.emit(get_index())

func enable_processing() -> void:
	is_processing_inputs = true

func disable_processing() -> void:
	is_processing_inputs = false

@rpc("any_peer", "call_local", "reliable")
func request_enable_processing() -> void:
	enable_processing()

func initialize() -> void:
	disable_processing()
	animator.play("port" + str(get_index() + 1))
	animator.advance(0.0)
	animator.play("init")
	animator.advance(0.0)
	controller_index = PartyManager.get_player_data(get_index()).local_player_index

@rpc("any_peer", "call_local", "reliable")
func set_current_selection(selection : Vector2i) -> void:
	current_selection = selection

## Sets the cursor's position and shows it.
@rpc("any_peer", "call_local", "reliable")
func set_cursor_position(new_position : Vector2) -> void:
	animator.play("show")
	animator.seek(0.0)
	is_hidden = false
	global_position = new_position

## Sets the cursor's position and shows it.
@rpc("any_peer", "call_local", "reliable")
func select_random(cycle_count : int) -> void:
	random_count = cycle_count
	is_selecting_random = true

@rpc("any_peer", "call_local", "reliable")
func decrement_random_count() -> void:
	random_count -= 1
	random_count = max(random_count, 0)

## Sets the cursor's position and shows it.
@rpc("any_peer", "call_local", "reliable")
func finish_random() -> void:
	is_selecting_random = false
	disable_processing()

## Starts the looping animation.
func start_loop() -> void:
	set_multiplayer_authority(PartyManager.get_player_data(get_index()).device)
	enable_processing()
	animator.play("loop")

## Hides the cursors position.
@rpc("any_peer", "call_local", "reliable")
func hide_cursor() -> void:
	is_hidden = true
	enable_processing() # Re-enable processing so player can cancel their selection
	animator.play("hide")

@rpc("any_peer", "call_local", "reliable")
func set_player_tag(player_index : int):
	port_index = player_index
	var tag : String = PartyManager.get_player_data(port_index).player_tag
	player_label.set_synced_text(tag)
