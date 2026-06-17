extends PartyGameCharacterSpawner

@export var spotlight: CSGCylinder3D
@export var hand_attachment: BoneAttachment3D
@export var lookat: LookAtModifier3D
@export var lamp: Node3D

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

	lookat.reparent(character_animator.skeleton)
	lookat.target_node = lookat.get_path_to(spotlight)

func _physics_process(delta: float) -> void:
	lamp.look_at(spotlight.position)