extends CanvasLayer

# ─────────────────────────────────────────────────
#  Node refs
# ─────────────────────────────────────────────────
@onready var root_panel: Control = $RootPanel
@onready var grid_root:  GridContainer = $RootPanel/InnerBorder/OM/VBox/GridCard/GridMargin/GridRoot

# ─────────────────────────────────────────────────
#  Config
# ─────────────────────────────────────────────────
const GRID_COLS     := 10
const GRID_ROWS     := 6
const MARGIN_TOP    := 16.0   # floating gap from top
const MARGIN_BOTTOM := 115.0  # leave clear room for skill bar + mana orb
const MARGIN_RIGHT  := 14.0   # right edge gap

# ─────────────────────────────────────────────────
#  State
# ─────────────────────────────────────────────────
var is_open:    bool  = false
var panel_w:    float = 0.0
var panel_h:    float = 0.0
var player_ref: Node  = null

# ─────────────────────────────────────────────────
#  Lifecycle
# ─────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var vp := get_viewport().get_visible_rect().size

	# ~44% of screen width, floating margins clearing HUD and mana orb
	panel_w = vp.x * 0.44 - MARGIN_RIGHT
	panel_h = vp.y - MARGIN_TOP - MARGIN_BOTTOM

	root_panel.size     = Vector2(panel_w, panel_h)
	root_panel.position = Vector2(vp.x, MARGIN_TOP)  # starts off-screen right
	root_panel.visible  = false

	_setup_grid()

# ─────────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────────
func toggle() -> void:
	if is_open:
		_close()
	else:
		_open()

# ─────────────────────────────────────────────────
#  Open / Close
# ─────────────────────────────────────────────────
func _open() -> void:
	if is_open: return
	is_open = true
	root_panel.visible = true
	Input.mouse_mode   = Input.MOUSE_MODE_VISIBLE

	var vp  := get_viewport().get_visible_rect().size
	var dst := vp.x - panel_w - MARGIN_RIGHT

	var tw := create_tween()
	tw.tween_property(root_panel, "position:x", dst, 0.30) \
	  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	if player_ref and player_ref.has_method("shift_camera_for_ui"):
		player_ref.shift_camera_for_ui(true)

func _close() -> void:
	if not is_open: return
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var vp := get_viewport().get_visible_rect().size

	var tw := create_tween()
	tw.tween_property(root_panel, "position:x", vp.x, 0.24) \
	  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		root_panel.visible = false
	)

	if player_ref and player_ref.has_method("shift_camera_for_ui"):
		player_ref.shift_camera_for_ui(false)

# ─────────────────────────────────────────────────
#  Input
# ─────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not is_open: return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────────
#  Grid — uses GridContainer, cells auto-layout
# ─────────────────────────────────────────────────
func _setup_grid() -> void:
	# Clear old cells
	for ch in grid_root.get_children():
		ch.queue_free()

	grid_root.columns = GRID_COLS

	# Compute cell pixel size to fill available width
	# panel_w minus: outer_border(8+3) + inner_border(3) + OM_margin(14*2) +
	#               equip_section_margin(10*2) + GridCard_margin(10*2) = ~82px per side → ~164 total
	var inner_w := panel_w - 164.0
	var gap      := 2
	var cell_sz  := int((inner_w - (GRID_COLS - 1) * gap) / GRID_COLS)
	cell_sz       = max(cell_sz, 36)

	grid_root.add_theme_constant_override("h_separation", gap)
	grid_root.add_theme_constant_override("v_separation", gap)

	for _i in range(GRID_COLS * GRID_ROWS):
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(cell_sz, cell_sz)

		var sb := StyleBoxFlat.new()
		sb.bg_color            = Color(0.060, 0.050, 0.035, 0.93)
		sb.border_width_left   = 1
		sb.border_width_top    = 1
		sb.border_width_right  = 1
		sb.border_width_bottom = 1
		sb.border_color        = Color(0.30, 0.22, 0.08, 0.90)
		sb.corner_radius_top_left     = 2
		sb.corner_radius_top_right    = 2
		sb.corner_radius_bottom_right = 2
		sb.corner_radius_bottom_left  = 2
		cell.add_theme_stylebox_override("panel", sb)
		grid_root.add_child(cell)
