### Score Counter for Party Games. 
class_name ScoreCounter extends TextureRect

@export var name_label : SyncedLabel
@export var score_label : SyncedLabel
@export var character_texture_rect : TextureRect
var _player_index : int = -1

func _ready() -> void:
	visible = false;
	MinigameManager.instance.gameplay_started.connect(Callable.create(self, "on_gameplay_started"))

func on_score_updated(player_index : int, score : int) -> void:
	if player_index == _player_index:
		score_label.set_synced_text("%02d" % score)

## Sets the player index and links the on_score_updated signal.
func set_player_index(player_index : int) -> void:
	_player_index = player_index
	var character_data : PartyCharacterResource = PartyManager.get_player_data(player_index).character_data
	character_texture_rect.texture = character_data.score_portrait
	name_label.set_synced_text(character_data.character_name)
	MinigameManager.instance.on_score_updated.connect(Callable(self, "on_score_updated"))

func on_gameplay_started() -> void:
	visible = true
