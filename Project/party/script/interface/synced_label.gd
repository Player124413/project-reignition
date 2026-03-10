### Syncs a label and its child labels. Used for certain fonts in Party Mode.
@tool
class_name SyncedLabel extends Label

var _child_labels : Array[Label]

@export_tool_button("Sync Label Values")
var sync_action = sync_editor_labels

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	# Populate child array
	_child_labels.clear()
	rec_get_child_labels(self)

## Sync function for the editor.
func sync_editor_labels() -> void:
	_child_labels.clear()
	rec_get_child_labels(self)
	set_synced_text(text)

## Populates child_labels recursively.
func rec_get_child_labels(parent : Node) -> void:
	for child : Node in parent.get_children():
		if child is Label:
			_child_labels.append(child)
		rec_get_child_labels(child)

## Syncs the text values and alignments of all child labels.
func set_synced_text(new_text : String) -> void:
	text = new_text
	for child : Label in _child_labels:
		child.text = new_text
		child.horizontal_alignment = horizontal_alignment
		child.vertical_alignment = vertical_alignment
