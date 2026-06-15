class_name TreasureBoxChest extends RigidBody3D

@export var animator : AnimationPlayer
@export var debug_label : Label3D
@export var throw_sfx : GroupSfxPlayer
@export var shake_sfx : GroupSfxPlayer
@export var coin_sfx : Array[AudioStreamPlayer3D]
@export var coin_spawn_pos : Node3D
var _original_parent : Node

## The bone attachment this chest is connected to.
var current_player : Node
var pickup_tick : float = -1

var num_coins: int
var is_thrown : bool
var is_on_ground : bool

func spawn() -> void:
	freeze = false
	_original_parent = get_parent()
	debug_label.text = str(num_coins)

func despawn() -> void:
	if !is_instance_valid(current_player):
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED

func play_shake_sfx() -> void:
	shake_sfx.play_in_group()
	var volume_interval : float = (TreasureBoxChestSpawner.instance.HIGHEST_COIN_COUNT as float) / coin_sfx.size()
	var coin_ratio : float = num_coins / (TreasureBoxChestSpawner.instance.HIGHEST_COIN_COUNT as float)
	var coin_sfx_range : int = ceil(lerp(0, coin_sfx.size(), coin_ratio))
	for i in coin_sfx_range:
		coin_sfx[i].volume_linear = 1.0
		if i != 0 && num_coins != TreasureBoxChestSpawner.instance.HIGHEST_COIN_COUNT && i == coin_sfx_range - 1:
			coin_sfx[i].volume_linear = (fmod(num_coins, volume_interval) * 0.5) / (volume_interval as float)
		coin_sfx[i].play()

func pickup(player : Node, attachment : Node, tick : float) -> void:
	if pickup_tick > 0 && tick > pickup_tick && is_instance_valid(current_player): # Already picked up by a different player
		return
	
	pickup_tick = tick
	freeze = true
	current_player = player
	animator.play("pickup")
	var original_pos : Vector3 = global_position
	is_on_ground = false
	print("picked up " + str(num_coins))
	reparent(attachment)
	set_multiplayer_authority(attachment.get_multiplayer_authority())
	set_deferred("global_position", original_pos)
	call_deferred("reset_physics_interpolation")

func drop(vel : Vector3 = Vector3.ZERO) -> void:
	freeze = false
	call_deferred("apply_central_impulse", vel)
	animator.play("drop")
	is_thrown = !vel.is_zero_approx()
	if is_thrown:
		throw_sfx.play_in_group()
	else:
		current_player = null
	
	print("dropped " + str(num_coins))
	reparent(_original_parent)
	set_multiplayer_authority(_original_parent.get_multiplayer_authority())

func start_results_shake() -> void:
	animator.play("open")

func _on_body_entered(body : Node) -> void:
	if body is TreasureBoxChest:
		current_player = null
		return
	
	if body.is_in_group("floor"):
		is_on_ground = true
		animator.play("hit-floor")
		is_thrown = false
		current_player = null
		for exception in get_collision_exceptions():
			remove_collision_exception_with(exception)
		return
	
	if !is_thrown || !is_multiplayer_authority():
		return
	
	var player : Node = body.get_parent()
	if player != current_player && player.has_method("request_damage"):
		player.request_damage()
		add_collision_exception_with(body)
