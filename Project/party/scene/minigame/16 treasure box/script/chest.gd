class_name TreasureBoxChest extends RigidBody3D

@export var animator : AnimationPlayer
@export var debug_label : Label3D
var _original_parent : Node

## The bone attachment this chest is connected to.
var current_player : Node
var pickup_tick : float

var num_coins: int
var is_thrown : bool

func spawn() -> void:
	freeze = false
	_original_parent = get_parent()
	debug_label.text = str(num_coins)

func pickup(player : Node, attachment : Node, tick : float) -> void:
	if tick < pickup_tick: # Already picked up by a different player
		if is_instance_valid(current_player):
			current_player.cancel_pickup()
		return
	
	pickup_tick = tick
	freeze = true
	current_player = player
	animator.play("pickup")
	var original_pos : Vector3 = global_position
	reparent(attachment)
	set_multiplayer_authority(attachment.get_multiplayer_authority())
	set_deferred("global_position", original_pos)
	call_deferred("reset_physics_interpolation")

func drop(vel : Vector3 = Vector3.ZERO) -> void:
	freeze = false
	apply_central_impulse(vel)
	animator.play("drop")
	is_thrown = !vel.is_zero_approx()
	reparent(_original_parent)
	set_multiplayer_authority(_original_parent.get_multiplayer_authority())

func _on_body_entered(body : Node) -> void:
	if body is TreasureBoxChest:
		return
	
	if body.is_in_group("floor"):
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
