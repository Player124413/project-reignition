extends Node3D

@export var animator: AnimationPlayer
@export var picture_animator: AnimationPlayer
var wrong: bool
var _character: CHARACTER

enum CHARACTER {
	AMY,
	BLAZE,
	CREAM,
	KNUCKLES,
	SHADOW,
	SILVER,
	SONIC,
	TAILS,
	DEMO
}

func set_correct_picture() -> void:
	picture_animator.play(str(_character).to_lower() + "_correct")