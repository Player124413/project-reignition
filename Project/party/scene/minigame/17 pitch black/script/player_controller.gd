extends PartyGameCharacterSpawner

@export var picture_manager: PictureManager
@export var spotlight: CSGCylinder3D
@export var hand_attachment: BoneAttachment3D
@export var lookat: LookAtModifier3D
@export var lamp: Node3D
@export var collision: Area3D

var _state: STATE
enum STATE {
	IDLE,
	BUSY
}

func on_spawn_finished() -> void:
	super ()
	print("Attaching lantern to hand")
	hand_attachment.reparent(character_animator.skeleton)
	character_animator.play_animation("%s/light-wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)
	set_physics_process(true)

	lookat.reparent(character_animator.skeleton)
	lookat.target_node = lookat.get_path_to(spotlight)

func _physics_process(delta: float) -> void:
	lamp.look_at(spotlight.position)
	collision.global_position = spotlight.get_child(0).mesh.get_aabb().get_center()

func set_state(state: STATE):
	_state = state

func start_miss() -> void:
	character_animator.play_animation("%s/miss" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)

func start_success() -> void:
	return