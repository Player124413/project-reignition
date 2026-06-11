class_name Chest extends Node

@export var num_coins: int
@export var animator: AnimationPlayer
@export var rigidbody: RigidBody3D
@export var smoke: GPUParticles3D


func _on_rigid_body_3d_body_entered(body: Node) -> void:
	if body.is_in_group("floor"):
		animator.play("hit_floor")
		smoke.emitting = true
		
	pass # Replace with function body.
