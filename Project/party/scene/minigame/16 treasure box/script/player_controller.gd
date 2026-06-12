### The player controller for the Treasure Box party game.
extends PartyGameCharacterMover
@export var hand_attachment: BoneAttachment3D

var current_chest: TreasureChest
var can_grab: bool
var is_grabbing: bool
var _state: STATE
enum STATE {
	IDLE,
	HOLD,
	THROW,
	SHAKE,
	DAMAGE,
	INVINCIBLE
}

const CHEST_POSITION_SPEED : float = 20.0

func on_spawn_finished() -> void:
	super ()
	hand_attachment.reparent(character_animator.skeleton)
	_state = STATE.IDLE

func on_minigame_finished() -> void:
	super ()

func process_rotation(target_angle: float) -> void:
	if is_valid_move_state():
		super (target_angle)

func process_speed() -> void:
	if _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		super ()
		return
	
	_move_speed = move_toward(_move_speed, 0, brake_friction * get_physics_process_delta_time())

func process_animation() -> void:
	if _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		super ()
	
	if _state == STATE.HOLD && is_instance_valid(current_chest): # Move to hands
		current_chest.position = current_chest.position.move_toward(Vector3.ZERO, CHEST_POSITION_SPEED * get_physics_process_delta_time())

func process_movement_tick() -> void:
	process_invincibility()
	
	if _state == STATE.INVINCIBLE && !is_invincible():
		_state = STATE.IDLE
	super ()

const ANIM_PICKUP_START: int = 0
const ANIM_PICKUP_FINISH: int = 1
const ANIM_THROW_START: int = 2
const ANIM_THROW_FINISH: int = 3
const ANIM_SHAKE_START: int = 4
const ANIM_SHAKE_FINISH: int = 5
const ANIM_DAMAGE_START: int = 6
const ANIM_INVINCIBILITY_START: int = 7

func process_animation_event(event: int) -> void:
	if event == ANIM_PICKUP_START:
		is_grabbing = true
	elif event == ANIM_PICKUP_FINISH:
		_state = STATE.HOLD
	elif event == ANIM_THROW_FINISH:
		_state = STATE.IDLE
	elif event == ANIM_THROW_START:
		_state = STATE.THROW
	elif event == ANIM_DAMAGE_START:
		_state = STATE.DAMAGE
	elif event == ANIM_INVINCIBILITY_START:
		_state = STATE.INVINCIBLE
		request_invincibility(1)

func process_inputs() -> void:
	if !is_cpu() && _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			if can_grab:
				start_pickup(NetworkTimeSynchronizer.get_time())
	super ()

func start_pickup(tick: float):
	_state = STATE.HOLD
	var target_anim: StringName = get_anim_prefix() + "lift"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 1, 0, tick)
	var original_position : Vector3 = current_chest.rigidbody.global_position
	current_chest.rigidbody.position = Vector3.ZERO # Reset positions
	current_chest.rigidbody.freeze = true
	current_chest.rigidbody.reset_physics_interpolation()
	current_chest.reparent(hand_attachment)
	current_chest.global_position = original_position
	current_chest.reset_physics_interpolation()
	print("grabbing " + str(current_chest))

@rpc("any_peer", "call_local", "reliable")
func request_damage() -> void:
	if !is_multiplayer_authority():
		return
	if _state == STATE.DAMAGE || is_invincible():
		return
	take_damage(NetworkTimeSynchronizer.get_time())

func take_damage(tick: float) -> void:
	var target_anim: StringName = get_anim_prefix() + "damage"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 1, 0, tick)
	_state = STATE.DAMAGE

func _on_grab_area_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemy"):
		print("Can grab chest!")
		var node = area
		while (node is not TreasureChest):
			node = node.get_parent()
		current_chest = node
		can_grab = true

func _on_grab_area_area_exited(area: Area3D) -> void:
	if area.is_in_group("enemy"):
		print("Out of chest range")
		can_grab = false
	
func is_valid_move_state() -> bool:
	match _state:
		STATE.IDLE:
			return true
		STATE.INVINCIBLE:
			return true
		STATE.HOLD:
			return true
	return false
