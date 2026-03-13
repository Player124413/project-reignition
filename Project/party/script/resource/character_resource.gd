## Represents a character in the party mode.
class_name PartyCharacterResource extends Resource

## Localization key for the character's name.
@export var character_name : String
## File path containing the model for party games.
@export_file("*.tscn") var model_file : String

## The index of the character on the character select screen.
@export_range(0, 7, 1, "or_greater") var character_select_index : int

## Portrait to use when unlocked.
@export var character_select_portrait : Texture2D
## Portrait to use when locked.
@export var locked_character_select_portrait : Texture2D
## Number of firesouls required in the main game to unlock this character.
@export var unlock_requirements : int
func is_unlocked() -> bool:
	# TODO Link to the main game's save data through the c# script
	return true


## TODO Add party-mode specific SFX libraries.
