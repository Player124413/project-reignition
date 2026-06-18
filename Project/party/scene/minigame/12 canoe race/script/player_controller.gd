extends PartyGameCanoeMover

@export var path : Path3D
## Path follower to track position 
@export var path_follower : PathFollow3D

var lap_length : float
var river_velocity : Vector3
var wall_bounce_velocity : Vector3
var river_speed : float = DEFAULT_RIVER_SPEED
const DEFAULT_RIVER_SPEED : float = 10.0
const WALL_BOUNCE_STRENGTH : float = 60.0
const WALL_BOUNCE_FRICTION : float = 20.0
const MINIMUM_BOUNCE_DOT : float = -0.75

func apply_movement() -> void:
	super()
	
	process_wall_bounce()
	character_body.velocity = path_follower.global_basis.z * river_speed + wall_bounce_velocity
	character_body.move_and_slide()
	path_follower.progress = path.curve.get_closest_offset(character_body.global_position)
	
	race_tracker.set_progress_raw(get_progress())

func process_wall_bounce() -> void:
	if character_body.is_on_wall():
		var collider : Object = character_body.get_last_slide_collision().get_collider()
		if collider is CharacterBody3D: # Don't bounce off other players
			return
		
		var dot : float = character_body.global_basis.z.normalized().dot(character_body.get_wall_normal().normalized())
		if dot < MINIMUM_BOUNCE_DOT:
			_move_speed = 0.0
			wall_bounce_velocity += character_body.get_wall_normal() * WALL_BOUNCE_STRENGTH
			character_animator.play_voice("balance")
	wall_bounce_velocity = wall_bounce_velocity.move_toward(Vector3.ZERO, WALL_BOUNCE_FRICTION * get_physics_process_delta_time())


func get_progress() -> float:
	if race_tracker.player_laps[player_index] == 0:
		return 0.0
	return lap_length * race_tracker.player_laps[player_index] + path_follower.progress
