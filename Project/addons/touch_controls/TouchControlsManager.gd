extends CanvasLayer
## Main touch controls overlay manager for Android.
##
## Creates and manages virtual joystick + buttons that simulate
## the game's existing Input actions. Automatically hides when
## a physical controller/keyboard is detected.
##
## Features:
## - Virtual analog joystick (left side)
## - Configurable action buttons (right side)
## - Auto-detect mobile vs desktop
## - Auto-hide on gamepad connection
## - **Edit mode** (press ✎) — drag, resize, toggle visibility
## - **Save/load** custom layouts to user://touch_layout.cfg
## - **Disable** touch controls entirely
## - **Mobile performance** auto-tuning

class_name TouchControlsManager

signal touch_enabled_changed(enabled: bool)
signal layout_changed

# ─── Exported Settings ───────────────────────────────────────────────

## Enable touch controls (auto-detected on mobile, force for desktop testing)
@export var force_enabled: bool = false
## Automatically hide controls when a physical gamepad is connected
@export var auto_hide_on_controller: bool = true
## Show debug overlay for touch regions
@export var debug_mode: bool = false

# ─── Internal State ──────────────────────────────────────────────────

var is_visible_override: bool = true

# Backing field for the touch_enabled property (Godot 4 property syntax)
var _touch_enabled_backing: bool = true
var touch_enabled: bool = true:
	get:
		return _touch_enabled_backing
	set(value):
		if _touch_enabled_backing == value:
			return
		_touch_enabled_backing = value
		if _touch_enabled_backing:
			show_touch_controls()
		else:
			hide_touch_controls()
		touch_enabled_changed.emit(value)

var _physical_input_active: bool = false
var _initialized: bool = false

# References to control nodes
var _joystick: TouchVirtualJoystick
var _buttons: Array[VirtualButton] = []

# Editor reference
var _editor: TouchControlsEditor

# Performance manager
var _perf: MobilePerformanceManager

# Whether we loaded a custom layout
var _has_custom_layout: bool = false

# Button configuration: [action_name, label, toggle, pos_x_norm, pos_y_norm, size_norm]
const BUTTON_CONFIG := [
	# Right side — main action buttons (bottom to top)
	["button_jump",        "A",   false,  0.82, 0.85, 1.2],   # Jump (big)
	["button_action",      "B",   false,  0.72, 0.78, 0.9],   # Action
	["button_attack",      "X",   false,  0.88, 0.72, 0.9],   # Attack
	
	# Middle-right — special abilities
	["button_speedbreak",  "SB",  true,   0.78, 0.55, 0.7],   # Speed Break (toggle)
	["button_timebreak",   "TB",  true,   0.88, 0.45, 0.7],   # Time Break (toggle)
	["button_light_dash",  "LD",  false,  0.72, 0.35, 0.7],   # Light Dash
	["button_brake",       "BR",  false,  0.65, 0.65, 0.7],   # Brake
	
	# Top row — step/pause
	["button_step_left",   "◀",   false,  0.75, 0.12, 0.6],   # Step Left
	["button_step_right",  "▶",   false,  0.85, 0.12, 0.6],   # Step Right
]

func _ready() -> void:
	layer = 128  # Very high layer, above everything
	
	# Only enable on mobile or when forced
	if not force_enabled and not _is_mobile():
		visible = false
		set_process_input(false)
		return
	
	# Initialize performance manager on mobile
	if _is_mobile():
		_perf = MobilePerformanceManager.new()
		add_child(_perf)
		print("MobilePerformance: Auto-tuning started")
	
	# Load saved enabled state
	_load_enabled_state()
	
	# Wait one frame for the viewport to be ready
	await get_tree().process_frame
	
	# Check for saved layout first
	_has_custom_layout = _load_custom_layout_if_exists()
	
	_build_layout()
	_initialized = true
	
	# Listen for controller connections
	if auto_hide_on_controller:
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
		_check_physical_input()
	
	if not touch_enabled:
		visible = false

func _is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")

func _load_enabled_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://touch_toggle.cfg") == OK:
		touch_enabled = cfg.get_value("general", "enabled", true)
	else:
		touch_enabled = true

func _save_enabled_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "enabled", touch_enabled)
	cfg.save("user://touch_toggle.cfg")

func _load_custom_layout_if_exists() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load("user://touch_layout.cfg") == OK

func _build_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1920, 1080)
	
	# ─── Create Joystick (Left Side) ──────────────────────────────
	var joystick_scene := preload("res://addons/touch_controls/VirtualJoystick.tscn")
	if joystick_scene:
		_joystick = joystick_scene.instantiate()
		add_child(_joystick)
	else:
		_joystick = TouchVirtualJoystick.new()
		add_child(_joystick)
	
	var joystick_size := viewport_size.y * 0.22  # 22% of screen height
	_joystick.max_radius = joystick_size * 0.45
	_joystick.custom_minimum_size = Vector2(joystick_size, joystick_size)
	_joystick.size = Vector2(joystick_size, joystick_size)
	_joystick.position = Vector2(viewport_size.x * 0.08 - joystick_size * 0.5, viewport_size.y * 0.62 - joystick_size * 0.5)
	
	# ─── Create Buttons ───────────────────────────────────────────
	_buttons.clear()
	var btn_size := viewport_size.y * 0.085  # Base button size
	
	for cfg in BUTTON_CONFIG:
		var btn := VirtualButton.new()
		btn.action_name = cfg[0]
		btn.button_label = cfg[1]
		btn.toggle_mode = cfg[2]
		btn.button_scale = cfg[5]
		
		# Build the button's visual tree
		var bg := NinePatchRect.new()
		bg.name = "Background"
		bg.custom_minimum_size = Vector2(btn_size, btn_size) * cfg[5]
		bg.color = Color(1, 1, 1, 0.25)
		bg.size = bg.custom_minimum_size
		bg.position = Vector2.ZERO
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.2)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = Color(1, 1, 1, 0.4)
		bg.set("theme_override_styles/panel", style)
		btn.add_child(bg)
		
		var lbl := Label.new()
		lbl.name = "Label"
		lbl.text = cfg[1]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = bg.custom_minimum_size
		lbl.position = Vector2.ZERO
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		lbl.add_theme_font_size_override("font_size", int(18 * cfg[5]))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		btn.add_child(lbl)
		
		btn.custom_minimum_size = bg.custom_minimum_size
		btn.size = bg.custom_minimum_size
		var bx: float = viewport_size.x * float(cfg[3]) - btn.size.x * 0.5
		var by: float = viewport_size.y * float(cfg[4]) - btn.size.y * 0.5
		btn.position = Vector2(bx, by)
		
		add_child(btn)
		_buttons.append(btn)
	
	# ─── Pause / Menu Button (Top-Left) ───────────────────────────
	_add_pause_button(viewport_size)
	
	# ─── Edit Button (Top-Right corner) ───────────────────────────
	_add_edit_button(viewport_size)
	
	# ─── Apply custom layout if it exists ─────────────────────────
	if _has_custom_layout:
		_apply_custom_layout()
	
	# ─── Debug overlay ────────────────────────────────────────────
	if debug_mode:
		var debug_lbl := Label.new()
		debug_lbl.name = "DebugLabel"
		debug_lbl.text = "Touch Controls Active"
		debug_lbl.position = Vector2(viewport_size.x * 0.35, viewport_size.y * 0.01)
		debug_lbl.add_theme_color_override("font_color", Color(0, 1, 0, 1))
		debug_lbl.add_theme_font_size_override("font_size", 14)
		add_child(debug_lbl)

func _add_pause_button(viewport_size: Vector2) -> void:
	var pause_btn := VirtualButton.new()
	pause_btn.action_name = "sys_pause"
	pause_btn.button_label = "≡"
	pause_btn.toggle_mode = false
	pause_btn.idle_alpha = 0.25
	pause_btn.pressed_alpha = 0.7
	
	var pause_bg := NinePatchRect.new()
	pause_bg.name = "Background"
	var p_size := viewport_size.y * 0.055
	pause_bg.custom_minimum_size = Vector2(p_size, p_size)
	pause_bg.color = Color(1, 1, 1, 0.2)
	pause_bg.size = pause_bg.custom_minimum_size
	pause_bg.position = Vector2.ZERO
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(1, 1, 1, 0.15)
	pstyle.corner_radius_top_left = 10
	pstyle.corner_radius_top_right = 10
	pstyle.corner_radius_bottom_left = 10
	pstyle.corner_radius_bottom_right = 10
	pstyle.border_width_top = 2
	pstyle.border_width_bottom = 2
	pstyle.border_width_left = 2
	pstyle.border_width_right = 2
	pstyle.border_color = Color(1, 1, 1, 0.3)
	pause_bg.set("theme_override_styles/panel", pstyle)
	pause_btn.add_child(pause_bg)
	
	var pause_lbl := Label.new()
	pause_lbl.name = "Label"
	pause_lbl.text = "≡"
	pause_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_lbl.size = pause_bg.custom_minimum_size
	pause_lbl.position = Vector2.ZERO
	pause_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	pause_lbl.add_theme_font_size_override("font_size", 24)
	pause_btn.add_child(pause_lbl)
	
	pause_btn.custom_minimum_size = pause_bg.custom_minimum_size
	pause_btn.size = pause_bg.custom_minimum_size
	pause_btn.position = Vector2(viewport_size.x * 0.02, viewport_size.y * 0.02)
	add_child(pause_btn)
	_buttons.append(pause_btn)

func _add_edit_button(viewport_size: Vector2) -> void:
	var edit_btn := VirtualButton.new()
	edit_btn.action_name = "edit_touch"
	edit_btn.button_label = "✎"
	edit_btn.toggle_mode = false
	edit_btn.idle_alpha = 0.25
	edit_btn.pressed_alpha = 0.7
	
	var ebg := NinePatchRect.new()
	ebg.name = "Background"
	var e_size := viewport_size.y * 0.05
	ebg.custom_minimum_size = Vector2(e_size, e_size)
	ebg.color = Color(1, 1, 1, 0.2)
	ebg.size = ebg.custom_minimum_size
	ebg.position = Vector2.ZERO
	var estyle := StyleBoxFlat.new()
	estyle.bg_color = Color(0.2, 0.5, 0.7, 0.3)
	estyle.corner_radius_top_left = 8
	estyle.corner_radius_top_right = 8
	estyle.corner_radius_bottom_left = 8
	estyle.corner_radius_bottom_right = 8
	estyle.border_width_top = 2
	estyle.border_width_bottom = 2
	estyle.border_width_left = 2
	estyle.border_width_right = 2
	estyle.border_color = Color(0.3, 0.7, 1.0, 0.5)
	ebg.set("theme_override_styles/panel", estyle)
	edit_btn.add_child(ebg)
	
	var elbl := Label.new()
	elbl.name = "Label"
	elbl.text = "✎"
	elbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elbl.size = ebg.custom_minimum_size
	elbl.position = Vector2.ZERO
	elbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 0.9))
	elbl.add_theme_font_size_override("font_size", 22)
	edit_btn.add_child(elbl)
	
	edit_btn.custom_minimum_size = ebg.custom_minimum_size
	edit_btn.size = ebg.custom_minimum_size
	edit_btn.position = Vector2(viewport_size.x * 0.97 - e_size, viewport_size.y * 0.02)
	add_child(edit_btn)
	_buttons.append(edit_btn)
	
	# Override input handling for edit button
	edit_btn.set_script(_create_edit_button_script())

func _create_edit_button_script() -> Script:
	var s := GDScript.new()
	s.source_code = """
extends preload("res://addons/touch_controls/VirtualButton.gd")

func _process_touch_event(event):
	super(event)
	if is_pressed and action_name == "edit_touch":
		# Open editor
		var manager = get_parent()
		if manager.has_method("open_editor"):
			manager.open_editor()
"""
	return s

func open_editor() -> void:
	if _editor and _editor.is_editing():
		return
	
	_editor = TouchControlsEditor.new()
	add_child(_editor)
	_editor.editor_closed.connect(_on_editor_closed)
	
	# Hide regular controls during edit (they're still visible but with overlay)
	_editor.enter_edit_mode(self)

func _on_editor_closed(changed: bool) -> void:
	if _editor:
		_editor.queue_free()
		_editor = null
	
	if changed:
		layout_changed.emit()

func _apply_custom_layout() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://touch_layout.cfg") != OK:
		return
	
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	
	# Apply to joystick
	if _joystick and cfg.has_section("joystick"):
		var nx := cfg.get_value("joystick", "pos_x", 0.08)
		var ny := cfg.get_value("joystick", "pos_y", 0.62)
		var sz := cfg.get_value("joystick", "size_norm", 0.22)
		var elem_size: float = viewport_size.y * sz
		_joystick.size = Vector2(elem_size, elem_size)
		_joystick.position = Vector2(viewport_size.x * nx - elem_size * 0.5, viewport_size.y * ny - elem_size * 0.5)
		_joystick.max_radius = elem_size * 0.45
		_joystick._generate_textures()
	
	# Apply to buttons
	for btn in _buttons:
		var section := btn.action_name
		if not cfg.has_section(section):
			continue
		
		var visible_val := cfg.get_value(section, "visible", true)
		btn.visible = visible_val
		
		var nx := cfg.get_value(section, "pos_x", 0.5)
		var ny := cfg.get_value(section, "pos_y", 0.5)
		var sz := cfg.get_value(section, "size_norm", 0.085)
		var elem_size := maxf(viewport_size.y * sz, 30.0)
		
		btn.size = Vector2(elem_size, elem_size)
		btn.position = Vector2(viewport_size.x * nx - elem_size * 0.5, viewport_size.y * ny - elem_size * 0.5)
		
		# Update children visuals
		for i in btn.get_child_count():
			var child := btn.get_child(i)
			if child is NinePatchRect:
				child.custom_minimum_size = btn.size
				child.size = btn.size
			if child is Label:
				child.size = btn.size

func _rebuild_layout() -> void:
	# Clear all existing controls
	if _joystick:
		_joystick.queue_free()
		_joystick = null
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()
	
	# Rebuild
	_build_layout()

func _check_physical_input() -> void:
	for i in range(Input.get_connected_joypads().size()):
		_physical_input_active = true
		_update_visibility()
		return
	
	_physical_input_active = false
	_update_visibility()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_physical_input_active = connected
	_update_visibility()

func _update_visibility() -> void:
	if not touch_enabled:
		visible = false
		return
	
	if not is_visible_override:
		visible = false
		return
	
	if auto_hide_on_controller and _physical_input_active:
		visible = false
		_force_release_all()
	else:
		visible = true

func _force_release_all() -> void:
	if _joystick:
		_joystick.force_release()
	for btn in _buttons:
		btn.force_release()

## Show touch controls (overrides auto-hide)
func show_touch_controls() -> void:
	touch_enabled = true
	is_visible_override = true
	_update_visibility()

## Hide touch controls programmatically
func hide_touch_controls() -> void:
	is_visible_override = false
	_force_release_all()
	visible = false

## Enable/disable touch controls entirely (saves to disk)
func set_touch_enabled(enabled: bool) -> void:
	self.touch_enabled = enabled
	_save_enabled_state()

## Toggle touch on/off
func toggle_touch_enabled() -> void:
	set_touch_enabled(not touch_enabled)

func is_touch_active() -> bool:
	return visible and _initialized and touch_enabled

func get_performance_manager() -> MobilePerformanceManager:
	return _perf