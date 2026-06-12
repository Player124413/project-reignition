class_name TreasureChest extends Node3D

@export var num_coins: int = 0
@export var animator: AnimationPlayer
@export var rigidbody: RigidBody3D
@export var smoke: GPUParticles3D
@export var debug_label: Label3D

func _on_rigid_body_3d_body_entered(body: Node) -> void:
	if body.is_in_group("floor"):
		debug_label.text = str(num_coins)
		animator.play("hit_floor")
		smoke.emitting = true
		
	pass # Replace with function body.
