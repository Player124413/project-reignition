### Interface for handling animations of a party character.
class_name CharacterAnimator extends Node3D

@export var animator : AnimationPlayer

# TODO Add support for more complex character animations

## Plays a specific animation on the animator.
func play_animation(anim : StringName) -> void:
	animator.play(anim)
