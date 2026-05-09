### Represents a selectable minigame in the World Library.
class_name WLMinigameOption extends Control

@export var title_label : Label
var resource : MinigameResource


func change_resource(res : MinigameResource) -> void:
	resource = res
	title_label.text = res.localization_key
