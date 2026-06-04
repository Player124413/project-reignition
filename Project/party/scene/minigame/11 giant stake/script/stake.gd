class_name GiantStake extends Node

@export var animator: AnimationPlayer
@export var root: Node3D
### If true, start already spawned
@export var starting_stake: bool = false
@export var collision: Area3D
@export var materials: Array[Material]

### How many hits for wood type
const MAX_HITS_WOOD: int = 3
### How many hits for metal type
const MAX_HITS_BONUS: int = 5

### The visual height of a stake.
const STAKE_HEIGHT: float = 5.0

### Current number of hits
var num_hits: int = 0
### Is this stake a bonus stake?
var is_bonus: bool = false
### Can we currently hit this stake
var is_enabled: bool = false
var is_fallen: bool = false
var is_chosen: bool = false

func _ready() -> void:
	animator.play("started" if starting_stake else "standby")

@rpc("any_peer", "call_local", "reliable")
func spawn_stake(bonus : bool) -> void:
	if is_fallen:
		return
	
	is_bonus = bonus
	animator.play("metal" if is_bonus else "wood")
	animator.advance(0.0)

	is_fallen = true
	animator.play("fall")
	animator.queue("started")
	animator.advance(0.0)
	reset_physics_interpolation()

@rpc("any_peer", "call_local", "reliable")
func hit_stake() -> void:
	var max_hits : int = MAX_HITS_BONUS if is_bonus else MAX_HITS_WOOD
	num_hits += 1
	if num_hits >= max_hits:
		is_enabled = false
		animator.play("finished")
	root.position = Vector3.DOWN * (num_hits / (max_hits as float)) * STAKE_HEIGHT

func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("crusher"):
		rpc("hit_stake")
	pass # Replace with function body.
