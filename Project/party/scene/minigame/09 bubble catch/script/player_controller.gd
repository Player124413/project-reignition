extends PartyGameCharacterMover

@export var hand_attachment : BoneAttachment3D

func on_spawn_finished() -> void:
	super()
	hand_attachment.reparent(character_animator.skeleton)

func on_minigame_finished() -> void:
	super()
	hand_attachment.visible = false


func get_target_animation() -> StringName:
	var base : StringName = super()
	if base == "run":
		return "walk"
	return base
