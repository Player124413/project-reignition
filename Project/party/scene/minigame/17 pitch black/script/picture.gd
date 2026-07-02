class_name Picture extends Node3D

@export var animator: AnimationPlayer
@export var picture_animator: AnimationPlayer
@export var correction_circle: MeshInstance3D
@export var collision_shape: CollisionShape3D
var _character: CHARACTER
var wrong: bool = false

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

func _ready() -> void:
	correction_circle.visible = false

@rpc("any_peer", "call_local", "reliable")
func set_correct_picture(chara: CHARACTER) -> void:
	picture_animator.play(str(CHARACTER.keys()[chara]).to_lower() + "_correct")
	_character = chara
	wrong = false

@rpc("any_peer", "call_local", "reliable")
func set_incorrect_picture(num: int, chara: CHARACTER) -> void:
	picture_animator.play(str(CHARACTER.keys()[chara]).to_lower() + "_" + str(num))
	_character = chara
	wrong = true
	collision_shape.set_deferred("disabled", false)

## How long should the correction circle be up until it plays the correction sequence
const TIME_UNTIL_ANIMATION: float = 2
## Used when selecting the incorrect picture
func play_correction_sequence() -> void:
	correction_circle.visible = true
	await get_tree().create_timer(TIME_UNTIL_ANIMATION).timeout
	correction_circle.visible = false
	await get_tree().create_timer(0.2).timeout
	animator.play("spin_ftbtf")
	#await get_tree().create_timer(3).timeout
