extends CanvasLayer
class_name PauseMenu

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

@onready var overlay: Control = $Overlay
@onready var continue_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/ContinueButton
@onready var main_menu_button: Button = $Overlay/CenterContainer/Panel/Margin/VBox/MainMenuButton

var is_open := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	continue_button.pressed.connect(close_pause)
	main_menu_button.pressed.connect(return_to_main_menu)


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
