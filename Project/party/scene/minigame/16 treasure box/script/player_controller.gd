### The player controller for the Treasure Box party game.
extends PartyGameCharacterMover
@export var hand_attachment: BoneAttachment3D

## Array of all chests the player is currently in range of.
var available_chest_indexes : Array[int]
## The current chest the player is interacting with.
var current_chest : TreasureBoxChest

## The player's chest state.
var state : STATE = STATE.NONE
enum STATE {
	NONE,
	PICKING_UP,
	SHAKING,
	HOLDING,
	THROWING,
	DROPPING,
	DAMAGE,
	EMPTY
}

const CHEST_POSITION_SPEED : float = 20.0

func on_spawn_finished() -> void:
	super()
	MinigameManager.instance.players_completed.connect(Callable(self, "start_results"))
	hand_attachment.reparent(character_animator.skeleton)

func start_results() -> void:
	await get_tree().create_timer(0.5).timeout
	MinigameManager.instance.start_results_animation()

func on_gameplay_finished() -> void:
	super()
	if state == STATE.SHAKING:
		request_shake_stop()

func on_minigame_finished() -> void:
	if !is_instance_valid(current_chest):
		MinigameManager.instance.register_completed_player()
		return
	
	if !is_multiplayer_authority():
		return
	
	await get_tree().create_timer(0.1, false, true).timeout
	character_animator.call_deferred("play_animation", get_anim_prefix() + "lift-wait", true)
	current_chest.rotation = Vector3.ZERO # Reset chest rotation
	current_chest.start_results_shake()
	await get_tree().create_timer(0.2, false, true).timeout
	state = STATE.EMPTY
	character_animator.play_minigame_animation(get_anim_prefix() + "empty", 0.2, 1.5)
	_move_angle = 0
	character_body.rotation = Vector3.ZERO

func process_rotation(target_angle: float) -> void:
	if is_movement_disabled():
		return
	super(target_angle)

func process_speed() -> void:
	if is_movement_disabled():
		_move_speed = move_toward(_move_speed, 0, brake_friction * get_physics_process_delta_time())
		return
	super()

func process_animation() -> void:
	super()
	if is_instance_valid(current_chest): # Move to hands
		current_chest.position = current_chest.position.move_toward(Vector3.ZERO, CHEST_POSITION_SPEED * get_physics_process_delta_time())

func get_target_animation() -> StringName:
	if state == STATE.DAMAGE:
		return ""
	
	if state == STATE.NONE:
		return super()
	elif state == STATE.HOLDING:
		if _is_braking:
			return "lift-walk"
		return "lift-" + super()
	return ""

func process_movement_tick() -> void:
	process_invincibility()
	super ()

const ANIM_FINISH : int = 0
const ANIM_DROP : int = 1
const ANIM_THROW : int = 2
const ANIM_SHAKE : int = 3
const ANIM_EMPTY : int = 4
func process_animation_event(event: int) -> void:
	if event == ANIM_FINISH:
		state = STATE.HOLDING if is_instance_valid(current_chest) else STATE.NONE
		if _is_gameplay_finished:
			MinigameManager.instance.register_completed_player()
			character_animator.play_animation("%s/wait" % MinigameManager.COMMON_ANIMATION_LIBRARY_PREFIX, true, 0.1)
	elif event == ANIM_DROP:
		if is_instance_valid(current_chest):
			current_chest.drop()
			current_chest = null
	elif event == ANIM_THROW:
		if is_instance_valid(current_chest):
			current_chest.drop(character_body.global_basis.z * THROW_STRENGTH + Vector3.UP * THROW_HEIGHT)
			current_chest = null
	elif event == ANIM_SHAKE:
		if is_instance_valid(current_chest):
			current_chest.play_shake_sfx()
	elif event == ANIM_EMPTY:
		if is_instance_valid(current_chest) && is_multiplayer_authority():
			if current_chest.num_coins == 0:
				request_throw()
			else:
				empty_coin()
				await get_tree().create_timer(0.2).timeout
				MinigameManager.instance.request_score_change(player_index, 1)

const COIN_EMPTY_VELOCITY : float = 10.0
@rpc("any_peer", "call_local", "reliable")
func empty_coin() -> void:
	current_chest.play_shake_sfx()
	current_chest.num_coins -= 1
	var coin : Node3D = TreasureBoxChestSpawner.instance.get_coin()
	coin.visible = true
	coin.process_mode = Node.PROCESS_MODE_INHERIT
	var rb : RigidBody3D = coin.get_child(0) as RigidBody3D
	rb.global_position = current_chest.coin_spawn_pos.global_position
	rb.global_position += (1.0 - randf() * 2.0) * Vector3.RIGHT * 2.0
	rb.rotation = Vector3((1.0 - randf() * 2.0), (1.0 - randf() * 2.0), (1.0 - randf() * 2.0)) * PI * 0.4
	rb.reset_physics_interpolation()
	rb.apply_central_impulse(global_basis.z * COIN_EMPTY_VELOCITY)
	await get_tree().create_timer(0.2).timeout
	coin.get_child(1).play_in_group()

func process_inputs() -> void:
	if is_cpu(): # TODO Process this later.
		return
	
	if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
		if state == STATE.NONE && available_chest_indexes.size() != 0:
			request_pickup()
		elif state == STATE.HOLDING && is_instance_valid(current_chest):
			if is_zero_approx(_move_speed):
				request_drop()
			else:
				request_throw()
	elif is_instance_valid(current_chest):
		var is_shake_held : bool = Input.is_action_pressed("button_secondary%s" % get_input_suffix())
		if state == STATE.HOLDING && is_shake_held:
			request_shake_start()
		elif state == STATE.SHAKING && !is_shake_held:
			request_shake_stop()
	super ()

## Finds the closest chest and tries to pick it up.
func request_pickup() -> void:
	var chest_index : int = -1
	var closest_distance : float = INF
	for index in available_chest_indexes:
		var chest : TreasureBoxChest  = TreasureBoxChestSpawner.instance.get_chest(index)
		var dst : float = character_body.global_position.distance_to(chest.global_position)
		if dst < closest_distance:
			chest_index = index
			closest_distance = dst
	state = STATE.PICKING_UP
	rpc("pickup_chest", chest_index, NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func pickup_chest(chest_index : int, tick : float) -> void:
	state = STATE.PICKING_UP
	var target_anim: StringName = get_anim_prefix() + "lift"
	character_animator.play_minigame_animation(target_anim, 0, 1., 0, tick)
	current_chest = TreasureBoxChestSpawner.instance.get_chest(chest_index)
	current_chest.pickup(self, hand_attachment, tick) # Attempt to pickup the chest
	print("grabbing " + str(current_chest))

## Called to cancel a pick-up attempt.
func cancel_pickup() -> void:
	current_chest = null
	state = STATE.NONE

func request_drop() -> void:
	state = STATE.DROPPING
	rpc("drop", NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func drop(tick : float) -> void:
	state = STATE.DROPPING
	character_animator.play_minigame_animation(get_anim_prefix() + "put", 0, 1.5, 0, tick)

const THROW_STRENGTH : float  = 80.0
const THROW_HEIGHT : float = 5.0
func request_throw() -> void:
	rpc("throw", NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func throw(tick : float) -> void:
	state = STATE.THROWING
	character_animator.play_minigame_animation(get_anim_prefix() + "throw", 0, 2, 0, tick)

func request_shake_start() -> void:
	state = STATE.SHAKING
	rpc("shake_start", NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func shake_start(tick : float) -> void:
	state = STATE.SHAKING
	character_animator.play_minigame_animation(get_anim_prefix() + "shake", 0.2, 1, 0, tick)

func request_shake_stop() -> void:
	state = STATE.HOLDING
	rpc("shake_stop")

@rpc("any_peer", "call_local", "reliable")
func shake_stop() -> void:
	state = STATE.HOLDING

func request_damage() -> void:
	if is_invincible() || !is_multiplayer_authority() || _is_gameplay_finished:
		return
	
	rpc("take_damage", NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func take_damage(tick : float) -> void:
	state = STATE.DAMAGE
	character_animator.play_minigame_animation(get_anim_prefix() + "damage", 0, 1, 0, tick)
	request_invincibility(2 - (NetworkTimeSynchronizer.get_time() - tick))

func is_movement_disabled() -> bool:
	if state == STATE.NONE || state == STATE.HOLDING:
		return false
	return true

func _on_grab_area_area_entered(area: Area3D) -> void:
	var chest : Node = area.get_parent_node_3d()
	if chest is not TreasureBoxChest:
		return
	available_chest_indexes.append(TreasureBoxChestSpawner.instance.get_chest_index(chest))

func _on_grab_area_area_exited(area: Area3D) -> void:
	var chest : Node = area.get_parent_node_3d()
	if chest is not TreasureBoxChest:
		return
	var index : int = available_chest_indexes.find(TreasureBoxChestSpawner.instance.get_chest_index(chest))
	available_chest_indexes.remove_at(index)
