class_name PartyGameCursorMover extends PartyGameCharacterSpawner

@export_group("Components")
@export var rollback_timer: RollbackTimer
@export var cursor_texture_rect: TextureRect

@export_group("Movement Settings")
@export var cursor_move_speed: float = 10

var color: Color


## The current input being processed.
var _input: Vector2
## The current speed we're moving at.
var _move_speed: float

func on_spawn_finished() -> void:
	_move_speed = cursor_move_speed
	print("MOVE SPEED: " + str(_move_speed))
	cursor_texture_rect.get_child(0).self_modulate = get_color()
	cursor_texture_rect.get_child(1).self_modulate = get_color()

func _physics_process(delta: float) -> void:
	print("PROCESSING PHYSICS")
	if is_multiplayer_authority():
		process_inputs()
	
	process_movement_tick()
	if is_multiplayer_authority():
		process_rollback()

func get_color() -> Color:
	match character_animator.data.character_name:
		"party_sonic":
			return Color.AQUA
		"party_tails":
			return Color.YELLOW
		"party_knuckles":
			return Color.RED
		"party_amy":
			return Color.FUCHSIA
		"party_shadow":
			return Color.MIDNIGHT_BLUE
		"party_cream":
			return Color.DARK_ORANGE
		"party_silver":
			return Color.LIGHT_GRAY
		"party_blaze":
			return Color.BLUE_VIOLET
	return Color.WHITE


#####################
### ROLLBACK CODE ###
#####################
const RB_POS: int = 0
const RB_SPD: int = 1
const RB_INPUT: int = 2

func on_rollback_applied(rb_params: Array) -> void:
	cursor_texture_rect.global_position = rb_params[RB_POS]
	_move_speed = rb_params[RB_SPD]
	_input = rb_params[RB_INPUT]

func process_rollback() -> void:
	rollback_timer.set_param(RB_POS, cursor_texture_rect.global_position)
	rollback_timer.set_param(RB_SPD, _move_speed)
	rollback_timer.set_param(RB_INPUT, _input)
	rollback_timer.process_rollback()

func process_inputs() -> void:
	if _is_gameplay_finished:
		_input = Vector2.ZERO
	
	print("Checking input")
	if _input != Vector2.ZERO:
		print("Processing input!")
	
	if !is_cpu():
		_input = get_input_axis()
	#elif player_index != -1:

func process_movement_tick() -> void:
	apply_movement()
	

func apply_movement() -> void:
	cursor_texture_rect.global_position += _input * _move_speed
