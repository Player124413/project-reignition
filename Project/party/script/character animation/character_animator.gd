### Interface for handling animations of a party character.
class_name CharacterAnimator extends Node3D

@export var animator : AnimationPlayer

## Emitted after the select animation finishes. Emitted from aniamtion.
@warning_ignore("unused_signal")
signal select_finished

# TODO Add support for more complex character animations

## Plays a specific animation on the animator.
func play_animation(anim : StringName) -> void:
	if animator == null || !animator.has_animation(anim):
		return
	animator.play(anim)
	animator.seek(0.0, true)

## Loads a given animation library to the animator.
func load_animation_library(library_name : String, library : AnimationLibrary) -> void:
	animator.add_animation_library(library_name, library);
