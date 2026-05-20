### Manages the Minecart Race party game
extends PartyGameCharacterSpawner

@export var path: PathFollow3D;
@export var camera: Camera3D;
@export var minecart_animator: AnimationPlayer

## Is the player currently pumping the lever?
var is_pumping: bool
var lever_state: LEVER_STATES
enum LEVER_STATES {
	UP,
	DOWN
}

## How fast should the minecart go without pumping
const MINECART_DEFAULT_SPEED: float = 10.0
## How fast should the minecart go with pumping
const MINECART_PUMP_SPEED: float = 15.0
## How many frames can the player hold the lever before reverting to the default pump speed
const MINECART_PUMP_HOLD_TIME: float = 20

func on_spawn_finished() -> void:
	lever_state = LEVER_STATES.UP

	
func _physics_process(_delta: float) -> void:
	process_pump()


##If the lever is up, pump down, and vice versa
func process_pump() -> void:
	if is_pumping:
		return
	
	if minecart_animator.is_playing():
		return

	if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()) && lever_state == LEVER_STATES.UP:
		start_player_pump_down()
	
	if Input.is_action_just_pressed("button_secondary%s" % get_input_suffix()) && lever_state == LEVER_STATES.DOWN:
		start_player_pump_up()

## Pushes the minecart lever down
func start_player_pump_down() -> void:
	minecart_animator.play("down")
	return

## Pushes the minecart lever up
func start_player_pump_up() -> void:
	minecart_animator.play("up")
	return