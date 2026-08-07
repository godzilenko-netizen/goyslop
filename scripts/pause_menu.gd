extends CanvasLayer
class_name PauseMenu

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GothicUI = preload("res://scripts/ui/gothic_ui.gd")
const GOTHIC_THEME = preload("res://themes/diablo2_theme.tres")

const FAQ_SCENE = preload("res://scenes/faq_ui.tscn")

@onready var overlay: Control = $Overlay
@onready var continue_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/ContinueButton
@onready var faq_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/FaqButton
@onready var main_menu_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/MainMenuButton

var is_open := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _faq_instance: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_gothic_pause_style()
	overlay.visible = false
	continue_button.pressed.connect(close_pause)
	if faq_button:
		faq_button.pressed.connect(_open_faq)
	main_menu_button.pressed.connect(return_to_main_menu)


func _open_faq() -> void:
	if not _faq_instance:
		_faq_instance = FAQ_SCENE.instantiate() as CanvasLayer
		add_child(_faq_instance)
	if _faq_instance.has_method("open"):
		_faq_instance.call("open")


func _apply_gothic_pause_style() -> void:
	overlay.theme = GOTHIC_THEME
	var backdrop := $Overlay/Backdrop as ColorRect
	backdrop.color = Color(0.012, 0.008, 0.007, 0.78)
	var panel := $Overlay/CenterContainer/Panel as PanelContainer
	panel.custom_minimum_size = Vector2(430, 320)
	panel.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.025, 0.016, 0.013, 0.985), GothicUI.BRASS_DARK, 3, 0, 20))
	var margin := $Overlay/CenterContainer/Panel/Margin as MarginContainer
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_bottom", 34)
	var title := $Overlay/CenterContainer/Panel/Margin/VBox/Title as Label
	title.add_theme_color_override("font_color", GothicUI.BRASS_LIGHT)
	title.add_theme_color_override("font_outline_color", GothicUI.INK)
	title.add_theme_constant_override("outline_size", 5)
	var hint := $Overlay/CenterContainer/Panel/Margin/VBox/Hint as Label
	hint.add_theme_color_override("font_color", GothicUI.BONE_MUTED)
	for button in [continue_button, faq_button, main_menu_button]:
		if button:
			button.custom_minimum_size = Vector2(button.custom_minimum_size.x, 48.0)
			button.remove_theme_stylebox_override("normal")



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if is_open:
		close_pause()
	else:
		open_pause()


func open_pause() -> void:
	if is_open:
		return
	is_open = true
	_previous_mouse_mode = Input.mouse_mode
	overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	continue_button.grab_focus()


func close_pause() -> void:
	if not is_open:
		return
	get_tree().paused = false
	is_open = false
	overlay.visible = false
	Input.mouse_mode = _previous_mouse_mode


func return_to_main_menu() -> void:
	get_tree().paused = false
	is_open = false
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("Failed to return to main menu: %s" % error_string(error))
