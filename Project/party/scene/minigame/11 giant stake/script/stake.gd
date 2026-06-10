class_name GiantStake extends Node3D

@export var animator: AnimationPlayer
@export var slam_animator: AnimationPlayer
@export var root: Node3D
### If true, start already spawned
@export var starting_stake: bool = false
@export var collision: Area3D
@export var hitbox_falling: CollisionShape3D
@export var smoke: GPUParticles3D
@export var sfx_hit_wood: GroupSfxPlayer
@export var sfx_hit_metal: GroupSfxPlayer
@export var sfx_hit_final: GroupSfxPlayer

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
	animator.play("standby")

@rpc("any_peer", "call_local", "reliable")
func spawn_stake(bonus: bool) -> void:
	if is_fallen:
		return
	
	if starting_stake:
		animator.speed_scale = 2.5


	is_bonus = bonus
	animator.play("metal" if is_bonus else "wood")
	animator.advance(0.0)

	animator.play("fall")
	animator.queue("started")
	animator.advance(0.0)
	reset_physics_interpolation()

## Called from the fall animation
func on_stake_landed() -> void:
	is_fallen = true
	is_enabled = true

@rpc("any_peer", "call_local", "reliable")
func hit_stake(this_index: int) -> void:
	var max_hits: int = MAX_HITS_BONUS if is_bonus else MAX_HITS_WOOD
	num_hits += 1

	var score: int = 3 if is_bonus else 1
	var projected_position: Vector3 = global_position + Vector3.UP * 2
	var screen_pos: Vector2 = get_viewport().get_camera_3d().unproject_position(projected_position)

	sfx_hit_wood.play_in_group()
	if is_bonus:
		sfx_hit_metal.play_in_group()

	if num_hits >= max_hits:
		smoke.RestartGroup()
		is_enabled = false
		animator.play("finished")
		sfx_hit_final.play_in_group()
		request_score_popup(this_index, score, screen_pos)
	root.position = Vector3.DOWN * (num_hits / (max_hits as float)) * STAKE_HEIGHT
	slam_animator.play("slam")

func _on_area_3d_area_entered(area: Area3D) -> void:
	var node = area
	while (node is not PartyGameCharacterSpawner):
		node = node.get_parent()
	
	if area.is_in_group("player"):
		if !hitbox_falling.disabled:
			rotate(Vector3(0, 1, 0), randf_range(0, TAU))
			is_enabled = false
			is_fallen = false
			animator.play("damaged")
			node.rpc("request_damage")

##Removes stake from end screen
func remove_stake() -> void:
	animator.play("remove")

@rpc("any_peer", "call_local", "reliable")
func request_score_popup(player_index: int, score: int, screen_pos: Vector2) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	MinigameManager.instance.request_score_popup(player_index, score, screen_pos)
	MinigameManager.instance.request_score_change(player_index, score)
