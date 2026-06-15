### The player controller for the Treasure Box party game.
extends PartyGameCharacterMover

@export var timer : Control
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
	if state == STATE.SHAKING:
		request_shake_stop()
	super()

func on_minigame_finished() -> void:
	character_body.process_mode = Node.PROCESS_MODE_DISABLED
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
		if is_instance_valid(current_chest) && current_chest.current_player == self:
			state = STATE.HOLDING
		else:
			cancel_pickup()
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
			if is_multiplayer_authority() && is_cpu():
				cpu_shakes_left -= 1
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
	if !is_cpu():
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

#################
### CPU Logic ###
#################
var cpu_target_chest : TreasureBoxChest
var cpu_aggro_chest : TreasureBoxChest
var examined_chests : Array[TreasureBoxChest]
var estimated_coin_sizes : Dictionary
var cpu_shakes_left : int # How many times the CPU has shaken this chest.
var cpu_move_timer : float
var cpu_move_dir : Vector2
func calculate_cpu_input() -> Vector2:
	if is_instance_valid(current_chest):
		# Holding a chest
		if state == STATE.SHAKING && cpu_shakes_left < 0:
			request_shake_stop()
		elif state == STATE.HOLDING:
			if !examined_chests.has(current_chest):
				request_shake_start()
				cpu_move_timer = randf() * 0.05
				cpu_move_dir = Vector2.RIGHT.rotated(randf() * TAU)
			# Decide whether to throw or not
			elif is_cpu_satisfied():
				# Simply wander around
				if is_zero_approx(cpu_move_timer):
					cpu_move_timer = randf() * 0.1
					if randf() < 0.4:
						cpu_move_dir = Vector2.ZERO
					else:
						cpu_move_dir = Vector2.RIGHT.rotated(randf() * TAU)
				cpu_move_timer = move_toward(cpu_move_timer, 0, get_physics_process_delta_time())
				return cpu_move_dir
			else: # Still looking for chests
				if is_zero_approx(cpu_move_timer):
					request_throw()
				else:
					cpu_move_timer = move_toward(cpu_move_timer, 0, get_physics_process_delta_time())
					if is_instance_valid(cpu_aggro_chest) && is_instance_valid(cpu_aggro_chest.current_player):
						return cpu_chase_position(cpu_aggro_chest.global_position)
					return cpu_move_dir
		return Vector2.ZERO
	
	if !is_instance_valid(cpu_target_chest) || is_instance_valid(cpu_target_chest.current_player) || !cpu_target_chest.is_on_ground:
		cpu_target_chest = null
		if is_multiplayer_authority():
			rpc("update_target_chest", calculate_target_chest_index())
		return Vector2.ZERO
	
	if state == STATE.NONE && available_chest_indexes.size() != 0:
		request_pickup() # Try picking it up
		if is_instance_valid(cpu_aggro_chest):
			cpu_move_timer = randf() * 0.2
			cpu_move_dir = Vector2.RIGHT.rotated(randf() * TAU)
		return Vector2.ZERO
	
	if is_instance_valid(cpu_aggro_chest) && !is_instance_valid(cpu_aggro_chest.current_player):
		# Cpu's target chest is free; go pick it up
		return cpu_chase_position(cpu_aggro_chest.global_position)
	
	return cpu_chase_position(cpu_target_chest.global_position)

## Returns whether the cpu is satisfied with the chest they're currently holding.
func is_cpu_satisfied() -> bool:
	if is_instance_valid(cpu_aggro_chest):
		return false
	
	if is_cpu_panic_mode():
		# No time to find a better chest
		return true
	
	if estimated_coin_sizes[current_chest] > timer.current_time:
		return true
	
	return false

## Returns whether the cpu is done exploring and is now searching for its final chest.
func is_cpu_commit_mode() -> bool:
	return timer.current_time < 15

## Returns whether there's no time left and the cpu just needs to grab anything.
func is_cpu_panic_mode() -> bool:
	return timer.current_time < 5

@rpc("any_peer", "call_local", "reliable")
func update_target_chest(target_chest : int) -> void:
	cpu_target_chest = TreasureBoxChestSpawner.instance.get_chest(target_chest)

func cpu_record_new_chest(approximation : int) -> void:
	examined_chests.append(current_chest)
	estimated_coin_sizes[current_chest] = approximation

## Force cpus to forget chests.
func cpu_forget_old_chest() -> void:
	var diff : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.EXTREME && examined_chests.size() < 7:
		return
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.HARD && examined_chests.size() < 5:
		return
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL && examined_chests.size() < 3:
		return
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.EASY && examined_chests.size() < 2:
		return
	
	if diff <= PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		estimated_coin_sizes.erase(examined_chests[0])
		examined_chests.remove_at(0)
	else:
		# Good cpus forget the worst chest
		var worst : int = cpu_get_worst_chest()
		estimated_coin_sizes.erase(examined_chests[worst])
		examined_chests.remove_at(worst)

func calculate_target_chest_index() -> int:
	var diff : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.EASY:
		# Easy cpus just choose chests randomly, regardless of distance
		return randi_range(0, TreasureBoxChestSpawner.instance.chests.size() - 1)
	else:
		if diff == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL && is_cpu_panic_mode():
			return cpu_get_closest_chest()
		
		if is_cpu_commit_mode(): # Time to commit to a chest
			if is_instance_valid(cpu_aggro_chest) && !is_instance_valid(cpu_aggro_chest.current_player) && cpu_aggro_chest.is_on_ground:
				var index : int = TreasureBoxChestSpawner.instance.get_chest_index(cpu_aggro_chest)
				cpu_aggro_chest = null
				return index
			return cpu_get_best_chest(diff >= PlayerData.CPU_DIFFICULTY_ENUM.HARD)
		
		var new_chests : Array[int]
		for i in TreasureBoxChestSpawner.instance.chests.size():
			var new_chest : TreasureBoxChest = TreasureBoxChestSpawner.instance.get_chest(i)
			if examined_chests.has(new_chest): # Already examined this chest
				continue
			if is_instance_valid(new_chest.current_player) || !new_chest.is_on_ground: # Can't pick this chest up...
				continue
			new_chests.append(i)
		if new_chests.size() == 0: # Shouldn't happen, but you never know...
			return cpu_get_best_chest(diff >= PlayerData.CPU_DIFFICULTY_ENUM.HARD)
		
		return new_chests[randi_range(0, new_chests.size() - 1)]

func cpu_get_closest_chest() -> int:
	# Just grab the closest chest we have
	var closest_dst : float = INF
	var closest_index : int = -1
	for i in TreasureBoxChestSpawner.instance.chests.size():
		var chest : TreasureBoxChest = TreasureBoxChestSpawner.instance.get_chest(i)
		if is_instance_valid(chest.current_player):
			continue
		var dst : float = chest.global_position.distance_squared_to(character_body.global_position)
		if dst < closest_dst:
			closest_dst = dst
			closest_index = i
	return closest_index

## Gets the best chest this cpu knows based on its memory.
func cpu_get_best_chest(allow_aggro : bool) -> int:
	var highest : int = 0
	var best_chest : TreasureBoxChest
	var true_highest : int = 0
	var true_best : TreasureBoxChest
	
	for chest in examined_chests:
		if allow_aggro && estimated_coin_sizes[chest] > true_highest:
			true_best = chest
			true_highest = estimated_coin_sizes[chest]
		
		if is_instance_valid(chest.current_player) || !chest.is_on_ground:
			continue
		
		if estimated_coin_sizes[chest] > highest:
			highest = estimated_coin_sizes[chest]
			best_chest = chest
	
	if allow_aggro && best_chest != true_best:
		cpu_aggro_chest = true_best # Store the true best chest as the one we're going for next
	if best_chest == null:
		return cpu_get_closest_chest()
	
	return TreasureBoxChestSpawner.instance.get_chest_index(best_chest)

## Gets the worst chest this cpu knows based on its memory.
func cpu_get_worst_chest() -> int:
	var lowest : int = 100
	var worst_chest : TreasureBoxChest = null
	for chest in examined_chests:
		if estimated_coin_sizes[chest] < lowest:
			lowest = estimated_coin_sizes[chest]
			worst_chest = chest
	return examined_chests.find(worst_chest)

func calculate_cpu_approximation() -> int:
	var approximation : int = current_chest.num_coins
	return approximation
	var diff : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.EASY:
		approximation += randi_range(-10, 10)
	elif diff == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		approximation += randi_range(-6, 6)
	elif diff == PlayerData.CPU_DIFFICULTY_ENUM.HARD:
		approximation += randi_range(-3, 3)
	return max(approximation, 0)

func calculate_cpu_shake_count() -> int:
	var diff : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.EASY:
		return randi_range(4, 8)
	elif diff == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		return randi_range(2, 4)
	elif diff == PlayerData.CPU_DIFFICULTY_ENUM.HARD:
		return randi_range(1, 2)
	else:
		return 1

## Registers a chest as "examined," along with the amount of coins this CPU thinks are in it.
@rpc("any_peer", "call_local", "reliable")
func finish_examining_chest(approximation : int) -> void:
	state = STATE.HOLDING
	if is_multiplayer_authority() && is_cpu():
		cpu_forget_old_chest()
		cpu_record_new_chest(approximation)

## Finds the closest chest and tries to pick it up.
func request_pickup() -> void:
	var chest_index : int = -1
	var closest_distance : float = INF
	for index in available_chest_indexes:
		var chest : TreasureBoxChest = TreasureBoxChestSpawner.instance.get_chest(index)
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
	character_animator.play_minigame_animation(target_anim, 0, 1.4, 0, tick)
	current_chest = TreasureBoxChestSpawner.instance.get_chest(chest_index)
	current_chest.pickup(self, hand_attachment, tick) # Attempt to pickup the chest

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
const THROW_HEIGHT : float = 2.0
func request_throw() -> void:
	rpc("throw", NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func throw(tick : float) -> void:
	state = STATE.THROWING
	character_animator.play_minigame_animation(get_anim_prefix() + "throw", 0, 2, 0, tick)

func request_shake_start() -> void:
	state = STATE.SHAKING
	rpc("shake_start", NetworkTimeSynchronizer.get_time())
	if is_cpu() && is_multiplayer_authority():
		cpu_shakes_left = calculate_cpu_shake_count()

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
	if is_cpu() && is_multiplayer_authority():
		rpc("finish_examining_chest", calculate_cpu_approximation())

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
