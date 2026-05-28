class_name GiantStake extends Node

@export var animator: AnimationPlayer
### If true, start already spawned
@export var starting_stake: bool = false
@export var collision: CollisionShape3D

### How many hits for wood type
const MAX_HITS_WOOD: int = 3
### How many hits for metal type
const MAX_HITS_BONUS: int = 5
### Chance of stake becoming metal (eg: 5 = 1/5 chance)
const CHANCE_FOR_BONUS: int = 5
### Current number of hits
var num_hits: int = 0
### Is this stake a bonus stake	
var is_bonus: bool = false
### Can we currently hit this stake
var is_enabled: bool = false
var is_fallen: bool = false

func _ready() -> void:
	initialize_stake()

func initialize_stake() -> void:
	if !starting_stake:
		animator.play("standby")
	else:
		animator.play("wood_stage_0")

	return

func spawn_stake() -> void:
	is_fallen = true
	
	if is_bonus:
		animator.play("metal_fall")

	
	return

@rpc("any_peer", "call_local", "reliable")
func hit_stake() -> void:
	num_hits += 1
	
	if !is_bonus:
		if num_hits >= MAX_HITS_WOOD:
			is_enabled = false
	else:
		if num_hits >= MAX_HITS_BONUS:
			is_enabled = false
	
	update_stake()
	return

@rpc("any_peer", "call_local", "reliable")
func update_stake() -> void:
	if !is_bonus:
		animator.play("wood_stage_" + str(num_hits))
	else:
		animator.play("metal_stage_" + str(num_hits))

	return

func set_fall(fall: bool) -> void:
	is_fallen = fall

func set_bonus() -> void:
	var rng = RandomNumberGenerator.new()

	if rng.randi_range(1, CHANCE_FOR_BONUS) == 1:
		is_bonus = true
	else:
		is_bonus = false
