extends PartyGameCanoeMover

@export var path : Path3D
## Path follower to track position 
@export var path_follower : PathFollow3D

var lap_length : float
var river_velocity : Vector3
var wall_bounce_velocity : Vector3
var river_speed : float = DEFAULT_RIVER_SPEED
const DEFAULT_RIVER_SPEED : float = 8.0
const WALL_BOUNCE_STRENGTH : float = 50.0
const WALL_BOUNCE_FRICTION : float = 20.0
const MINIMUM_BOUNCE_DOT : float = -0.75

func apply_movement() -> void:
	super()
	
	process_wall_bounce()
	character_body.velocity = path_follower.global_basis.z * river_speed + wall_bounce_velocity
	character_body.move_and_slide()
	sync_path_follower()

func sync_path_follower() -> void:
	var old_progress : float = path_follower.progress_ratio
	path_follower.progress = path.curve.get_closest_offset(character_body.global_position)
	var delta : float = abs(path_follower.progress_ratio - old_progress)
	if delta > 0.1 && delta < 0.9: # Invalid progress change
		path_follower.progress_ratio = old_progress

func calculate_cpu_input() -> void:
	var diff : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	# Dumb algorithm that often leads to moving backwards
	var input : float
	
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.EASY:
		input = sign(path_follower.to_local(character_body.global_position).x)
		request_paddle(input, true) # Easy CPU paddles fast then waits for an uncomfortably long time
		return
	
	# Better algorithm. Occasional wall bumps
	var forward_dir : Vector3 = Vector3.MODEL_FRONT.rotated(Vector3.UP, _move_angle)
	var angle : float = path_follower.global_basis.z.signed_angle_to(forward_dir, Vector3.UP)
	input = sign(angle)
	
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		request_paddle(input, true) # Normal CPU paddles fast then waits for an uncomfortably long time
		return
		
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.HARD:
		request_paddle(input, false) # Hard CPU paddle slowly, but consistently
		return
	
	if abs(angle) < PI * 0.2: # Extra wall avoidance on turns for extreme cpus
		var offset : float = path_follower.to_local(character_body.global_position).x
		if abs(offset) > 12:
			input = sign(offset)
	request_paddle(input, true) # Extreme CPU paddles fast consistently

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
