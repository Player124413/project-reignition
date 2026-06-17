extends PartyGameCanoeMover

@export var path : Path3D
## Path follower to track position 
@export var path_follower : PathFollow3D

var river_velocity : Vector3
var river_speed : float = DEFAULT_RIVER_SPEED
const DEFAULT_RIVER_SPEED : float = 10.0

func apply_movement() -> void:
	super()
	character_body.velocity = path_follower.global_basis.z * river_speed
	character_body.move_and_slide()
	path_follower.progress = path.curve.get_closest_offset(character_body.global_position)
