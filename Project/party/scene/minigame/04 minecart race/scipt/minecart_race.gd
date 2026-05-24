### Manages the Minecart Race party game
extends PartyGameCharacterSpawner

@export var path: PathFollow3D;
@export var camera: Camera3D;
@export var minecart_animator: AnimationPlayer

var lever_state: LEVER_STATES
enum LEVER_STATES {
	UP,
	DOWN
}

## How fast should the minecart go without pumping
const MINECART_MIN_SPEED: float = 10.0
## How fast should the minecart go with pumping
const MINECART_MAX_SPEED: float = 35.0
## How much speed should be added each pump
const MINECART_ADDITIVE_SPEED: float = 5.0
## How much speed should be added on an incline
const MINECART_INCLINE_SPEED: float = 15.0
var speed


func on_spawn_finished() -> void:
	lever_state = LEVER_STATES.UP
	speed = MINECART_MIN_SPEED

	
func _physics_process(_delta: float) -> void:
	process_pump()


##If the lever is up, pump down, and vice versa
func process_pump() -> void:
	if minecart_animator.is_playing():
		return

	if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()) && lever_state == LEVER_STATES.UP:
		start_player_pump_down()
		return
	
	if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()) && lever_state == LEVER_STATES.DOWN:
		start_player_pump_up()

## Pushes the minecart lever down
func start_player_pump_down() -> void:
	minecart_animator.play("down")
	speed += MINECART_ADDITIVE_SPEED
	return

## Pushes the minecart lever up
func start_player_pump_up() -> void:
	minecart_animator.play("up")
	return