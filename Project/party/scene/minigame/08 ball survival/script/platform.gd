extends Node3D

const MAX_ROTATION : float = 8.0

func _on_fall_trigger_area_entered(area: Area3D) -> void:
	var player : Node3D = area.get_parent().get_parent()
	if player.is_multiplayer_authority():
		MinigameManager.instance.request_score_change(player.player_index, -1)
		MinigameManager.instance.register_completed_player()
	
