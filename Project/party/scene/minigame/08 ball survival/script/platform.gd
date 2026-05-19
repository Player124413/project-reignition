class_name BallSurvivalPlatform extends Node3D

static var instance : BallSurvivalPlatform

@export var rollback_timer : RollbackTimer
@export var move_sfx : AudioStreamPlayer
@export var splash_sfx : AudioStreamPlayer
@export var splash_vfx : Array[GPUParticles3D]

var _is_gameplay_finished : bool
var players : Array[PartyGameCharacterMover]

const MAX_ROTATION : float = 10.0
const ROTATION_SPEED : float = 5.0

func _enter_tree() -> void:
	instance = self
	MinigameManager.instance.gameplay_started.connect(Callable(self, "activate"))
	MinigameManager.instance.gameplay_finished.connect(Callable(self, "on_gameplay_finished"))
	MinigameManager.instance.minigame_finished.connect(Callable(self, "deactivate"))
	deactivate()
	rollback_timer.register_target(self)

func on_gameplay_finished() -> void:
	_is_gameplay_finished = true

func activate() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	move_sfx.play()

func deactivate() -> void:
	move_sfx.stop()
	process_mode = Node.PROCESS_MODE_DISABLED
	rotation_degrees = Vector3.ZERO

func _physics_process(_delta : float) -> void:
	process_movement_tick()
	if NetworkManager.is_hosting_game:
		process_rollback()

#####################
### ROLLBACK CODE ###
#####################
const RB_ROT : int = 0
func on_rollback_applied(rb_params : Array) -> void:
	rotation_degrees = rb_params[RB_ROT]

func process_rollback() -> void:
	rollback_timer.set_param(RB_ROT, rotation_degrees)
	rollback_timer.process_rollback()

func process_movement_tick() -> void:
	var avg_pos : Vector3 = get_average_position()
	var target_rot : Vector3 = avg_pos.limit_length(MAX_ROTATION)
	target_rot = target_rot.rotated(Vector3.UP, PI * 0.5)
	rotation_degrees = rotation_degrees.move_toward(target_rot, ROTATION_SPEED * get_physics_process_delta_time())

func get_average_position() -> Vector3:
	var avg : Vector3 = Vector3.ZERO
	if players.size() == 0:
		return avg
	for player in players:
		avg += player.character_body.global_position
	avg /= players.size()
	avg.y = 0
	return avg

func register_player(mover : PartyGameCharacterMover) -> void:
	players.append(mover)

func _on_player_trigger_area_exited(area : Area3D) -> void:
	var player : Node3D = area.get_parent().get_parent()
	if player.is_multiplayer_authority():
		var index : int = players.find(player)
		if index != -1:
			players.remove_at(index)

func _on_fall_trigger_area_entered(area : Area3D) -> void:
	splash_sfx.play()
	if _is_gameplay_finished:
		return
	
	var player : Node3D = area.get_parent().get_parent()
	if player.is_multiplayer_authority():
		splash_vfx.get(player.player_index).global_position = player.character_body.global_position
		splash_vfx.get(player.player_index).call("RestartGroup")
		MinigameManager.instance.request_score_change(player.player_index, -1)
		MinigameManager.instance.register_completed_player()
