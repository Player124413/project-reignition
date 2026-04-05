### Interface for handling animations of a party character.
class_name CharacterAnimator extends Node3D

signal animation_event(info : int)

@export var skeleton : Skeleton3D
@export var animator : AnimationPlayer

## Emitted after the select animation finishes. Emitted from aniamtion.
@warning_ignore("unused_signal")
signal select_finished

# TODO Add support for more complex character animations

## Emits a signal from an animation. Use this to send data to the generic minigame controller.
func emit_animation_event(info : int) -> void:
	emit_signal("animation_event", info)

## Plays a specific animation on the animator.
func play_animation(anim : StringName) -> void:
	if animator == null || !animator.has_animation(anim):
		return
	animator.play(anim)
	animator.seek(0.0, true)

## Plays a specific mini-game animation on the animator.
func play_minigame_animation(anim : StringName, blend : float = 0.0, speed : float = 1.0) -> void:
	if animator == null || !animator.has_animation(anim):
		return
	
	if anim == animator.assigned_animation:
		animator.seek(0.0, true)
	animator.play("%s" % anim, blend, speed)

func queue_minigame_animation(anim : StringName) -> void:
	animator.queue("%s" % anim)

## Loads a given animation library to the animator.
func load_animation_library(library_name : String, library : AnimationLibrary) -> void:
	animator.add_animation_library(library_name, library);
