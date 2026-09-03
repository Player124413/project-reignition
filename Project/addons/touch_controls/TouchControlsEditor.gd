extends CanvasLayer
## Touch controls layout editor.
##
## Press the ✎ button in-game to enter edit mode, where you can:
## - Drag buttons anywhere on screen
## - Resize buttons with a pinch/drag handle
## - Toggle visibility of individual buttons
## - Save/Load custom layouts
## - Disable touch controls entirely
##
## Layouts are saved to user://touch_layout.cfg

class_name TouchControlsEditor

signal editor_closed(layout_changed: bool)

enum DragMode { NONE, MOVE, RESIZE }

var _is_active: bool = false
var _selected_element: int = -1
var _drag_mode: DragMode = DragMode.NONE
var _drag_offset: Vector2 = Vector2.ZERO
var _original_size: Vector2 = Vector2.ZERO
var _layout_changed: bool = false
var _touch_index: int = -1
var _viewport_size: Vector2

var _elements: Array[TouchEditElement] = []
var _manager: TouchControlsManager

# Visibility toggles: key = action_name, value = visible
var _element_visibility: Dictionary = {}

# Panel references
var _edit_panel: Control
var _save_btn: Button
var _reset_btn: Button
var _disable_btn: Button
var _close_btn: Button

# Resize handle size
const RESIZE_HANDLE_SIZE: float = 30.0
const MIN_ELEMENT_SIZE: float = 30.0

# ─── Element Data ────────────────────────────────────────────────────

class TouchEditElement:
	var action_name: String
	var label: String
	var control: Control        # The actual button/joystick control
	var orig_pos_norm: Vector2  # Original normalized position (0-1)
	var orig_scale: float       # Original scale factor
	var is_visible: bool = true
	var is_joystick: bool = false

func _ready() -> void:
	layer = 129  # Above TouchControlsManager
	visible = false
	process_mode = PROCESS_MODE_WHEN_PAUSED

func enter_edit_mode(manager: TouchControlsManager) -> void:
	_manager = manager
	_is_active = true
	_layout_changed = false
	_viewport_size = get_viewport().get_visible_rect().size
	visible = true
	
	_build_editor_overlay()
	_collect_elements()
	_load_layout()
	_show_toolbar()

func exit_edit_mode(save: bool = true) -> void:
	if save and _layout_changed:
		_save_layout()
	
	_is_active = false
	visible = false
	_cleanup()
	editor_closed.emit(_layout_changed)

func _collect_elements() -> void:
	_elements.clear()
	
	# Collect joystick
	if _manager._joystick:
		var je := TouchEditElement.new()
		je.action_name = "joystick"
		je.label = "🕹"
		je.control = _manager._joystick
		je.orig_pos_norm = Vector2(0.08, 0.62)
		je.orig_scale = 1.0
		je.is_joystick = true
		je.is_visible = _element_visibility.get("joystick", true)
		_elements.append(je)
	
	# Collect all buttons
	for btn in _manager._buttons:
		var be := TouchEditElement.new()
		be.action_name = btn.action_name
		be.label = btn.button_label
		be.control = btn
		be.orig_scale = btn.button_scale
		# Calculate original normalized position
		if _viewport_size.x > 0 and _viewport_size.y > 0:
			be.orig_pos_norm = Vector2(
				(btn.position.x + btn.size.x * 0.5) / _viewport_size.x,
				(btn.position.y + btn.size.y * 0.5) / _viewport_size.y
			)
		be.is_visible = _element_visibility.get(btn.action_name, true)
		_elements.append(be)
	
	_update_element_visibility()

func _build_editor_overlay() -> void:
	_edit_panel = Panel.new()
	_edit_panel.name = "EditPanel"
	_edit_panel.size = Vector2(_viewport_size.x, _viewport_size.y)
	_edit_panel.position = Vector2.ZERO
	_edit_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.0)
	_edit_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(_edit_panel)

func _show_toolbar() -> void:
	var tb := ColorRect.new()
	tb.name = "Toolbar"
	tb.size = Vector2(_viewport_size.x, _viewport_size.y * 0.07)
	tb.position = Vector2(0, 0)
	tb.color = Color(0, 0, 0, 0.7)
	tb.mouse_filter = Control.MOUSE_FILTER_PASS
	_edit_panel.add_child(tb)
	
	var title := Label.new()
	title.text = "✎ EDIT TOUCH LAYOUT"
	title.position = Vector2(_viewport_size.x * 0.02, _viewport_size.y * 0.01)
	title.size = Vector2(300, tb.size.y)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	title.add_theme_font_size_override("font_size", 18)
	tb.add_child(title)
	
	var btn_w := _viewport_size.x * 0.12
	var btn_h := tb.size.y * 0.65
	var btn_y := tb.size.y * 0.15
	var x := _viewport_size.x * 0.25
	
	for cfg in [
		["💾 SAVE", Color(0.15, 0.6, 0.2)],
		["↺ RESET", Color(0.6, 0.4, 0.1)],
		["⛔ DISABLE", Color(0.7, 0.15, 0.15)],
		["✕ CLOSE", Color(0.3, 0.3, 0.3)],
	]:
		var b := Button.new()
		b.text = cfg[0]
		b.position = Vector2(x, btn_y)
		b.size = Vector2(btn_w, btn_h)
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		b.add_theme_font_size_override("font_size", 14)
		
		var bbg := StyleBoxFlat.new()
		bbg.bg_color = cfg[1]
		bbg.corner_radius_top_left = 6
		bbg.corner_radius_top_right = 6
		bbg.corner_radius_bottom_left = 6
		bbg.corner_radius_bottom_right = 6
		b.add_theme_stylebox_override("normal", bbg)
		b.add_theme_stylebox_override("hover", bbg)
		b.add_theme_stylebox_override("pressed", bbg)
		
		match cfg[0]:
			"💾 SAVE":
				_save_btn = b
				b.pressed.connect(_on_save)
			"↺ RESET":
				_reset_btn = b
				b.pressed.connect(_on_reset)
			"⛔ DISABLE":
				_disable_btn = b
				b.pressed.connect(_on_disable)
			"✕ CLOSE":
				_close_btn = b
				b.pressed.connect(_on_close)
		
		x += btn_w + 8
		tb.add_child(b)

func _on_save() -> void:
	_save_layout()
	_layout_changed = false
	# Flash feedback
	_save_btn.modulate = Color(1, 1, 0, 1)
	await get_tree().create_timer(0.3).timeout
	_save_btn.modulate = Color(1, 1, 1, 1)

func _on_reset() -> void:
	_reset_layout()
	_collect_elements()
	_layout_changed = true

func _on_disable() -> void:
	exit_edit_mode(false)
	_manager.hide_touch_controls()
	_manager.set_touch_enabled(false)

func _on_close() -> void:
	exit_edit_mode(true)

func _save_layout() -> void:
	var cfg := ConfigFile.new()
	
	cfg.set_value("general", "touch_enabled", _manager.touch_enabled)
	cfg.set_value("general", "version", 2)
	
	for el in _elements:
		var section := el.action_name
		cfg.set_value(section, "type", "joystick" if el.is_joystick else "button")
		cfg.set_value(section, "label", el.label)
		cfg.set_value(section, "visible", el.is_visible)
		
		# Save as normalized position (0-1 range)
		var c := el.control
		var cx: float = (c.position.x + c.size.x * 0.5) / _viewport_size.x
		var cy: float = (c.position.y + c.size.y * 0.5) / _viewport_size.y
		cfg.set_value(section, "pos_x", clampf(cx, 0.01, 0.99))
		cfg.set_value(section, "pos_y", clampf(cy, 0.01, 0.99))
		
		# Save size as fraction of screen height
		var sz_norm: float = c.size.y / _viewport_size.y
		cfg.set_value(section, "size_norm", clampf(sz_norm, 0.02, 0.5))
	
	cfg.save("user://touch_layout.cfg")

func _load_layout() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://touch_layout.cfg") != OK:
		return
	
	_element_visibility.clear()
	for el in _elements:
		var section := el.action_name
		if not cfg.has_section(section):
			_element_visibility[section] = true
			continue
		
		_element_visibility[section] = cfg.get_value(section, "visible", true)
		
		var nx := cfg.get_value(section, "pos_x", el.orig_pos_norm.x)
		var ny := cfg.get_value(section, "pos_y", el.orig_pos_norm.y)
		var sz := cfg.get_value(section, "size_norm", el.control.size.y / _viewport_size.y)
		
		var c := el.control
		var elem_size := maxf(_viewport_size.y * sz, MIN_ELEMENT_SIZE)
		c.size = Vector2(elem_size, elem_size)
		c.position = Vector2(_viewport_size.x * nx - elem_size * 0.5, _viewport_size.y * ny - elem_size * 0.5)
		
		# Update internal size for joystick
		if el.is_joystick:
			var js := c as TouchVirtualJoystick
			if js:
				js.max_radius = elem_size * 0.45
				js._generate_textures()
		
		# Update button visual size
		if not el.is_joystick and c is VirtualButton:
			_for_each_child(c, func(child):
				if child is NinePatchRect:
					child.custom_minimum_size = c.size
					child.size = c.size
				if child is Label:
					child.size = c.size
			)
	
	_update_element_visibility()

func _reset_layout() -> void:
	# Delete saved layout
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("touch_layout.cfg"):
		dir.remove("touch_layout.cfg")
	
	# Rebuild from Manager's original config
	_manager._rebuild_layout()
	_collect_elements()
	
	for el in _elements:
		el.is_visible = true
		_element_visibility[el.action_name] = true
	
	_update_element_visibility()

func _update_element_visibility() -> void:
	for el in _elements:
		el.control.visible = el.is_visible

func _input(event: InputEvent) -> void:
	if not _is_active:
		return
	
	# Keyboard shortcuts
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_on_close()
				get_viewport().set_input_as_handled()
		if event.keycode == KEY_S and event.ctrl_pressed:
			_on_save()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and event.ctrl_pressed:
			_on_reset()
			get_viewport().set_input_as_handled()
	
	# Touch/Drag handling
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_process_edit_touch(event)

func _process_edit_touch(event: InputEvent) -> void:
	var pos: Vector2
	var is_press: bool
	var touch_idx: int
	
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		pos = te.position
		is_press = te.pressed
		touch_idx = te.index
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		pos = de.position
		touch_idx = de.index
		is_press = true
	else:
		return
	
	# Don't process touches on the toolbar area
	var toolbar_h := _viewport_size.y * 0.07
	if pos.y < toolbar_h and is_press:
		# If we just pressed on toolbar area and something was selected, deselect
		if is_press and _selected_element >= 0:
			_deselect_element()
		return
	
	if is_press and touch_idx == _touch_index:
		# Continue dragging/resizing
		if _selected_element >= 0 and _selected_element < _elements.size():
			_drag_element(_selected_element, pos)
		get_viewport().set_input_as_handled()
		return
	
	if is_press:
		# Find which element was touched
		var idx := _find_element_at(pos)
		if idx >= 0:
			_selected_element = idx
			_touch_index = touch_idx
			_drag_mode = DragMode.MOVE
			_drag_offset = pos - _elements[idx].control.position
			_highlight_element(idx, true)
			get_viewport().set_input_as_handled()
		else:
			_deselect_element()
	elif not is_press and touch_idx == _touch_index:
		_touch_index = -1
		_drag_mode = DragMode.NONE
		if _selected_element >= 0:
			_layout_changed = true

func _find_element_at(pos: Vector2) -> int:
	# Check in reverse order (top elements first)
	for i in range(_elements.size() - 1, -1, -1):
		var el := _elements[i]
		if not el.is_visible:
			continue
		var c := el.control
		var rect := Rect2(c.position, c.size)
		# Expand hit area for easier touch
		rect = rect.grow(10.0)
		if rect.has_point(pos):
			return i
	return -1

func _drag_element(index: int, pos: Vector2) -> void:
	var el := _elements[index]
	var c := el.control
	
	match _drag_mode:
		DragMode.MOVE:
			var new_pos := pos - c.size * 0.5
			# Clamp to screen
			new_pos.x = clampf(new_pos.x, 0, _viewport_size.x - c.size.x)
			new_pos.y = clampf(new_pos.y, _viewport_size.y * 0.07, _viewport_size.y - c.size.y)
			c.position = new_pos
			_layout_changed = true

func _deselect_element() -> void:
	if _selected_element >= 0:
		_highlight_element(_selected_element, false)
	_selected_element = -1
	_drag_mode = DragMode.NONE

func _highlight_element(index: int, highlight: bool) -> void:
	if index < 0 or index >= _elements.size():
		return
	
	var el := _elements[index]
	var c := el.control
	
	if highlight:
		# Add selection border
		var border := ColorRect.new()
		border.name = "EditBorder"
		border.size = c.size + Vector2(6, 6)
		border.position = Vector2(-3, -3)
		border.color = Color(0.2, 0.8, 1.0, 0.6)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(border)
		
		# Add info label
		var info := Label.new()
		info.name = "EditInfo"
		info.text = el.action_name + " | " + str(int(c.size.x)) + "x" + str(int(c.size.y))
		info.position = Vector2(0, -22)
		info.size = Vector2(200, 20)
		info.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 0.9))
		info.add_theme_font_size_override("font_size", 12)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(info)
	else:
		# Remove selection visuals
		_for_each_child(c, func(child):
			if child.name == "EditBorder" or child.name == "EditInfo":
				child.queue_free()
		)

func _for_each_child(node: Node, callback: Callable) -> void:
	for i in node.get_child_count():
		callback.call(node.get_child(i))

func _cleanup() -> void:
	_selected_element = -1
	_drag_mode = DragMode.NONE
	_touch_index = -1
	_elements.clear()
	
	if _edit_panel:
		_edit_panel.queue_free()
		_edit_panel = null

func is_editing() -> bool:
	return _is_active