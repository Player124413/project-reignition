@tool
extends Node

@export var texture_path : LineEdit
@export var material_path : LineEdit
@export var file_dialog : FileDialog
@export var skip_custom_shaders : CheckButton
@export var use_vertex_colors : CheckButton
@export var reset_albedo_colors : CheckButton

var file_dialog_target : EDIT_ENUM
enum EDIT_ENUM {
	TEXTURE,
	MATERIAL
}

func link_materials() -> void:
	var material_directory : DirAccess = DirAccess.open(material_path.text)
	if material_directory == null:
		printerr("Couldn't open material directory. Error code: " + str(DirAccess.get_open_error()))
		return
	
	var material_files : PackedStringArray = material_directory.get_files()
	for file_name : String in material_files:
		print("Processing %s" % file_name)
		if !file_name.ends_with(".tres"): # Not a text-editable material
			continue
		
		var material_path : String = material_path.text + file_name
		var material = ResourceLoader.load(material_path)
		if material is not Material or material is ShaderMaterial and skip_custom_shaders.button_pressed:
			print("Skipping %s" % file_name)
			continue
		
		# Open the file for editing
		var material_file : FileAccess = FileAccess.open(material_path, FileAccess.READ_WRITE)
		var material_lines : PackedStringArray = material_file.get_as_text().split('\n')
		
		var texture_path : String = texture_path.text + get_texture_name(file_name)
		if FileAccess.file_exists(texture_path):
			# Link the texture
			var line : int = find_line_index("albedo_texture", material_lines, 0)
			if line != -1:
				material_lines.remove_at(line)
			
			line = 2
			material_lines.insert(line, "")
			var id : String = generate_id(material_lines)
			material_lines.set(line, generate_resource_line(texture_path, id))
			line = find_line_index("[resource]", material_lines, 0) + 1
			material_lines.insert(line, 'albedo_texture = ExtResource("%s")' % id)
			print("Set albedo of %s to %s" % [file_name, texture_path])
		else:
			print("WARNING: texture not found for " + file_name)
			print(get_texture_name(file_name))
		
		if use_vertex_colors.button_pressed:
			var line : int = find_line_index("vertex_color_use_as_albedo", material_lines, 0)
			if line == -1:
				line = find_line_index("[resource]", material_lines, 0) + 1
			material_lines.set(line, "vertex_color_use_as_albedo = true")
		
		if reset_albedo_colors.button_pressed:
			var line : int = find_line_index("albedo_color = Color", material_lines, 0)
			if line != -1:
				material_lines.remove_at(line)
		
		write_file(material_file, material_lines)
		material_file.close()

func get_texture_name(file_name : String) -> String:
	file_name = file_name.replace(".tres", "")
	file_name = file_name.to_lower()
	file_name = file_name.replacen("transparent", "")
	file_name = file_name.strip_edges()
	return file_name + ".png"

## Load and resave a material to force-clean unused external resources
func clean_external_resources(file : String) -> void:
	var material : Material = ResourceLoader.load(file)
	ResourceSaver.save(material, file)

func generate_resource_line(texture_path : String, id : String) -> String:
	var uid : String = ResourceUID.path_to_uid(texture_path)
	if uid.begins_with("uid://"):
		uid = 'uid="%s"' % uid
	else:
		uid = ""
	return '[ext_resource type="Texture2D" %s path="%s" id="%s"]' % [uid, texture_path, id]

## Generates a random, unused id
func generate_id(lines : PackedStringArray) -> String:
	var test_id = "mat_importer_"
	var id_number : int = 1
	while find_line_index('id="%s%s"' % [test_id, id_number], lines, 0) != -1:
		id_number += 1
	return test_id + str(id_number)

## Finds the line index of a given string in the file
func find_line_index(target : String, lines : PackedStringArray, start_index : int) -> int:
	var count : int = 0
	for line in lines:
		if line.contains(target):
			return count
		count += 1
	return -1

## Writes an array of strings to a file.
func write_file(file : FileAccess, lines : PackedStringArray) -> void:
		file.resize(0)
		for line : String in lines:
			file.store_string(line + '\n')
		file.resize(file.get_length() - 1) # Remove last line break

func _on_link_button_pressed() -> void:
	link_materials()

func _on_material_button_pressed() -> void:
	file_dialog_target = EDIT_ENUM.MATERIAL
	file_dialog.current_dir = material_path.text
	file_dialog.show()

func _on_texture_button_pressed() -> void:
	file_dialog_target = EDIT_ENUM.TEXTURE
	file_dialog.current_dir = texture_path.text
	file_dialog.show()

func _on_file_dialog_dir_selected(dir: String) -> void:
	if !dir.ends_with("/"):
		dir += "/"
	
	if file_dialog_target == EDIT_ENUM.TEXTURE:
		texture_path.text = dir
		if material_path.text.is_empty():
			material_path.text = texture_path.text
	else:
		material_path.text = dir
		if texture_path.text.is_empty():
			texture_path.text = material_path.text

func _on_clean_button_pressed() -> void:
	var material_directory : DirAccess = DirAccess.open(material_path.text)
	if material_directory == null:
		printerr("Couldn't open material directory. Error code: " + str(DirAccess.get_open_error()))
		return
	
	var material_files : PackedStringArray = material_directory.get_files()
	for file_name : String in material_files:
		if !file_name.ends_with(".tres"): # Not a text-editable material
			continue
		
		var material_path : String = material_path.text + file_name
		var material = ResourceLoader.load(material_path)
		if material is not Material or material is ShaderMaterial and skip_custom_shaders.button_pressed:
			continue
		clean_external_resources(material_path)
