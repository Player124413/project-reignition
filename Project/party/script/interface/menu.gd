### Base class for menus in the party mode.
### Basically a copy of the C# implementation minus a few extra features.
### UNSUPPORTED: Mouse, Memory, Dynamic BGM.
class_name Menu extends Control

## The menu's main animator.
@export var animator : AnimationPlayer

## The index of the player who is controlling this menu.
@export var player_index : int = -1
## Updates the player_index and authority of this Menu.
func set_player_index(index : int) -> void:
	player_index = index # Update index
	if index == -1:
		set_multiplayer_authority(1) # Revert authority to host
	else:
		var data : PlayerData = PartyManager.get_player_data(index)
		set_multiplayer_authority(data.device) # Update authority

## Tracks whether the menu is currently processing.
@export var _is_menu_processing : bool
## Tracks the current selection.
var current_selection : Vector2i

## Tracks the current selection timer lockout.
var selection_timer : float

var input_axis : Vector2i
## Tracks whether the player is scrolling
var is_scrolling : bool

const SHOW_ANIMATION = "show"
const HIDE_ANIMATION = "hide"
const SELECTION_INTERVAL : float = .2;
const SELECTION_SCROLLING_INTERVAL : float = .1;

func _ready() -> void:
	initialize()
	if _is_menu_processing:
		show_menu()

func initialize() -> void:
	pass

func disable_processing() -> void:
	_is_menu_processing = false

func enable_processing() -> void:
	_is_menu_processing = true

func _process(_delta: float) -> void:
	process_cursor()
	if !_is_menu_processing:
		return
	
	process_input_axis()
	process_menu()

func process_input_axis() -> void:
	if player_index == -1:
		input_axis.x = sign(Input.get_axis("ui_left", "ui_right"))
		input_axis.y = sign(Input.get_axis("ui_up", "ui_down"))
		return
	input_axis.x = sign(Input.get_axis("move_left%s" % get_input_suffix(), "move_right%s" % get_input_suffix()))
	input_axis.y = sign(Input.get_axis("move_up%s" % get_input_suffix(), "move_down%s" % get_input_suffix()))

## Gets the input suffix for this player.
func get_input_suffix() -> String:
	return str(PartyManager.get_player_data(player_index).local_player_index)

func process_cursor() -> void:
	pass # Implemented in subclass

## Called every frame.
func process_menu() -> void:
	if !is_multiplayer_authority():
		return
	
	# Default behavior is to listen for inputs.
	if !is_zero_approx(selection_timer):
		selection_timer = move_toward(selection_timer, 0, get_process_delta_time())
		if input_axis == Vector2i.ZERO:
			selection_timer = 0
	elif input_axis != Vector2i.ZERO:
		update_selection()
	# Check button inputs
	if is_action_just_pressed("button_primary", "sys_select", "ui_select"):
		confirm()
	elif is_action_just_pressed("button_secondary", "sys_cancel", "ui_cancel"):
		cancel()
	elif is_action_just_pressed("button_pause", "sys_pause", "escape"):
		pause()

func start_selection_timer() -> void:
	selection_timer = SELECTION_SCROLLING_INTERVAL if is_scrolling else SELECTION_INTERVAL

## Called when changing the current selection.
func update_selection() -> void:
	pass # Implemented in subclass

## Called when confirming an option.
func confirm() -> void:
	pass # Implemented in subclass

## Called when cancelling an option.
func cancel() -> void:
	pass # Implemented in subclass

## Called when PAUSE is pressed.
func pause() -> void:
	pass # Implemented in subclass

## Shows the menu.
func show_menu() -> void:
	if animator.has_animation(SHOW_ANIMATION):
		animator.play(SHOW_ANIMATION)
	else: # Fallback
		visible = true

## Hides the menu.
func hide_menu() -> void:
	if animator.has_animation(HIDE_ANIMATION):
		animator.play(HIDE_ANIMATION)
		animator.advance(0.0)
	else: # Fallback
		visible = false

## Returns whether either inputs are pressed.
func is_action_just_pressed(player_input : StringName, input_id : StringName = "", built_in_input : StringName = "") -> bool:
	if player_index >= 0:
		return Input.is_action_just_pressed(player_input + get_input_suffix())
	return Input.is_action_just_pressed(input_id) || Input.is_action_just_pressed(built_in_input);
