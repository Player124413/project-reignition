### Controls the movement of majins on the game field.
extends Area3D

@export var animation_player : AnimationPlayer
@export var mesh : MeshInstance3D
@export var materials : Array[Material]

## Initial movement speed when spawning.
@export var initial_speed : float
## normal movement speed when hyper speed wears off.
@export var normal_speed : float

@export var movement_angle : float
var move_speed : float

## Bonus majin are worth 3 points instead of 1.
var is_bonus_majin : bool
var is_active : bool
var is_game_finished : bool

## How long the majin should be zooming after being spawned
const POSTSPAWN_HYPERSPEED_LENGTH : float = 1.0

## Reference to the physics world.
var world : World3D
## Length to use when checking for ground collisions.
const GROUND_CHECK_OFFSET : float = 50
## Length to use when checking for wall collisions.
const COLLISION_RADIUS : float = 2
## Bound for initial spawn locations.
const SPAWN_BOUNDS : Vector2 = Vector2(20, 20)
## Maximum amount of time to wait before spawning a new majin.
const MAX_SPAWN_INTERVAL : float = 5
## Minimum amount of time to wait before spawning a new majin.
const MIN_SPAWN_INTERVAL : float = 3

## Squish data. Used for network conflict resolution.
var squish_player : int = -1
var squish_time : float = -1

## Used to calculate the initial spawn time of the majins.
static var initial_spawn_index : int = 0
static var initial_spawn_counter : int = 0

## Generates a random spawn time.
func get_spawn_time() -> float:
	var spawn_time : float = lerp(MIN_SPAWN_INTERVAL , MAX_SPAWN_INTERVAL, randf())
	return NetworkTimeSynchronizer.get_time() + spawn_time

func get_initial_spawn_time() -> float:
	if randf() < 0.25 * initial_spawn_counter:
		initial_spawn_counter = 0
		initial_spawn_index += 1
	initial_spawn_counter += 1
	return NetworkTimeSynchronizer.get_time() + initial_spawn_index

## Generates a random spawn position.
func get_spawn_position() -> Vector2:
	var x : float = lerp(-SPAWN_BOUNDS.x, SPAWN_BOUNDS.x, randf())
	var y : float = lerp(-SPAWN_BOUNDS.y, SPAWN_BOUNDS.y, randf())
	return Vector2(x, y)

## Generates a random rotation for spawning.
func get_spawn_rotation() -> float:
	return randf() * TAU

func get_score_amount() -> int:
	return 3 if is_bonus_majin else 1

func _ready() -> void:
	if !NetworkManager.is_hosting_game: # Only host controls majin movement
		return
	
	set_multiplayer_authority(multiplayer.get_unique_id())
	world = get_world_3d()
	MinigameManager.instance.gameplay_started.connect(Callable.create(self, "on_gameplay_started"))
	MinigameManager.instance.minigame_finished.connect(Callable.create(self, "on_minigame_finished"))

func _physics_process(_delta: float) -> void:
	if !NetworkManager.is_hosting_game: # Only host controls majin movement
		return
	
	if !is_active:
		return
	
	move_speed = normal_speed
	global_rotation = Vector3.UP * movement_angle
	global_position += global_basis.z * move_speed * get_physics_process_delta_time()
	
	process_walls()
	process_ground()

func process_walls() -> void:
	var start : Vector3 = global_position + Vector3.UP * COLLISION_RADIUS
	var end : Vector3 = start + global_basis.z * COLLISION_RADIUS
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
	var results : Dictionary = world.direct_space_state.intersect_ray(query)
	if !results.has("collider") || results["collider"] == null:
		return
	
	if (results["collider"] as Node).is_in_group("floor"):
		return
	
	if results["collider"] is CharacterBody3D:
		var physics_body : CharacterBody3D = results["collider"] as CharacterBody3D
		if !physics_body.velocity.is_zero_approx():
			# Don't change directions when colliding with moving players (allow them to crush us)
			return
	
	movement_angle += PI # Turn around

func process_ground() -> void:
	var start : Vector3 = global_position + Vector3.UP * GROUND_CHECK_OFFSET
	var end : Vector3 = global_position - Vector3.UP * GROUND_CHECK_OFFSET
	var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
	var results : Dictionary = world.direct_space_state.intersect_ray(query)
	if results.has("collider") && results["collider"] != null:
		if !(results["collider"] as Node).is_in_group("floor"):
			return
		global_position = results["position"] as Vector3

## Called when gameplay starts. Spawns the initial wave of majin.
func on_gameplay_started() -> void:
	if !NetworkManager.is_hosting_game:
		return
	rpc("request_spawn", get_initial_spawn_time(), get_spawn_rotation(), get_spawn_position(), false)

@rpc("any_peer", "call_local", "reliable")
func request_spawn(target_tick : float, angle : float, spawn_pos : Vector2, is_bonus : bool) -> void:
	var spawn_delay : float = target_tick - NetworkTimeSynchronizer.get_time()
	var spawn_callable : Callable = Callable.create(self, "spawn")
	spawn_callable = spawn_callable.bind(angle, spawn_pos, is_bonus)
	get_tree().create_timer(spawn_delay).timeout.connect(spawn_callable)
	print("Requesting spawn on %s" % multiplayer.get_unique_id())

## Actually spawns the majin.
func spawn(angle : float, spawn_pos : Vector2, is_bonus : bool) -> void:
	print("Spawning majin on %s" % multiplayer.get_unique_id())
	movement_angle = angle
	global_position = Vector3(spawn_pos.x, 0, spawn_pos.y)
	is_bonus_majin = is_bonus
	mesh.material_override = materials[0 if is_bonus_majin else 1]
	animation_player.play("spawn")
	is_active = true
	squish_player = -1 # Reset squish tracking

@rpc("any_peer", "call_local", "reliable")
func request_squish(player_index : int, network_time : float) -> void:
	if squish_player != -1: # Resolve network conflicts
		if network_time >= squish_time: # Already squished by someone
			return
		
		# Undo the incorrect score TODO: Abort score text
		MinigameManager.instance.request_score_change(squish_player, -get_score_amount())
	
	squish_player = player_index
	squish_time = network_time
	MinigameManager.instance.request_score_change(player_index, get_score_amount())
	# TODO Play score effect (don't forget to abort if there's a network conflict!)
	
	if is_active: # Handle visuals
		animation_player.play("squish")
		is_active = false
		
		if NetworkManager.is_hosting_game:
			rpc("request_spawn", get_spawn_time(), get_spawn_rotation(), get_spawn_position(), randf() > 0.8)

func on_minigame_finished() -> void:
	is_game_finished = true

func _on_body_entered(body : PhysicsBody3D) -> void:
	if is_game_finished:
		return
	
	if body is not CharacterBody3D:
		return
	
	var physics_body : CharacterBody3D = body as CharacterBody3D
	if physics_body.velocity.is_zero_approx():
		return
	
	# Risky dynamic programming, but idc
	var index : int = physics_body.get_parent().player_index
	rpc("request_squish", index, NetworkTimeSynchronizer.get_time())
