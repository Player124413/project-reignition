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
	HOLDING,
	THROWING,
	DROPPING,
	DAMAGE
}

const CHEST_POSITION_SPEED : float = 20.0

func on_spawn_finished() -> void:
	super ()
	hand_attachment.reparent(character_animator.skeleton)

func on_minigame_finished() -> void:
	super ()

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
func process_animation_event(event: int) -> void:
	if event == ANIM_FINISH:
		state = STATE.HOLDING if is_instance_valid(current_chest) else STATE.NONE
	elif event == ANIM_DROP:
		if is_instance_valid(current_chest):
			current_chest.drop()
			current_chest = null
	elif event == ANIM_THROW:
		current_chest.drop(character_body.global_basis.z * THROW_STRENGTH + Vector3.UP * THROW_HEIGHT)
		current_chest = null

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
	character_animator.play_minigame_animation(target_anim, 0, 1.5, 0, tick)
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

func request_damage() -> void:
	if is_invincible() || !is_multiplayer_authority():
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
