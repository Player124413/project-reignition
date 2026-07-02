class_name PartyGameCursorMover extends PartyGameCharacterSpawner

@export_group("Components")
@export var rollback_timer: RollbackTimer
@export var cursor_texture_rect: TextureRect

@export_group("Movement Settings")
@export var cursor_move_speed: float = 10
@export var cpu_move_speed: float = 130

@export var cursor_min_clamp: Vector2
@export var cursor_max_clamp: Vector2

var color: Color
## The current input being processed.
var _input: Vector2
## The current speed we're moving at.
var _move_speed: float

func on_spawn_finished() -> void:
	super()
	_move_speed = cursor_move_speed
	cursor_texture_rect.get_child(0).self_modulate = get_color()
	cursor_texture_rect.get_child(1).self_modulate = get_color()
	cursor_min_clamp = Vector2.ZERO
	cursor_max_clamp = get_viewport().get_visible_rect().size

func _physics_process(_delta: float) -> void:
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
	
	if !is_cpu():
		_input = get_input_axis()

func process_movement_tick() -> void:
	apply_movement()
	

func apply_movement() -> void:
	cursor_texture_rect.global_position.x += _input.x * _move_speed
	cursor_texture_rect.global_position.y -= _input.y * _move_speed
	cursor_texture_rect.global_position = cursor_texture_rect.global_position.clamp(cursor_min_clamp, cursor_max_clamp - cursor_texture_rect.size)
func calculate_cpu_input() -> Vector2:
	return Vector2.ZERO

## Moves the cpu cursor to the specified position
func request_cpu_position(pos: Vector2) -> void:
	if NetworkManager.is_hosting_game:
		cursor_texture_rect.position.x = move_toward(cursor_texture_rect.position.x, pos.x, get_physics_process_delta_time() * cpu_move_speed) # * _move_speed)
		cursor_texture_rect.position.y = move_toward(cursor_texture_rect.position.y, pos.y, get_physics_process_delta_time() * cpu_move_speed) # * _move_speed)
