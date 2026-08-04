extends Control

@onready var main_buttons_container: Control = $MainButtons
@onready var new_game_panel: Panel = $NewGamePanel
@onready var settings_panel: Panel = $SettingsPanel

@onready var save_name_line_edit: LineEdit = $NewGamePanel/VBoxContainer/SaveNameLineEdit
@onready var resolution_option_button: OptionButton = $SettingsPanel/VBoxContainer/ResolutionOptionButton
@onready var fullscreen_check_box: CheckBox = $SettingsPanel/VBoxContainer/FullscreenCheckBox

func _ready() -> void:
	new_game_panel.visible = false
	settings_panel.visible = false
	main_buttons_container.visible = true
	
	# Инициализация списка разрешений
	resolution_option_button.clear()
	resolution_option_button.add_item("1920x1080")
	resolution_option_button.add_item("1280x720")
	resolution_option_button.add_item("640x360")
	resolution_option_button.select(0)
	
	fullscreen_check_box.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)

# --- Кнопки главного меню ---

func _on_new_game_button_pressed() -> void:
	main_buttons_container.visible = false
	new_game_panel.visible = true
	save_name_line_edit.grab_focus()

func _on_settings_button_pressed() -> void:
	main_buttons_container.visible = false
	settings_panel.visible = true

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# --- Окно создания сохранения ---

func _on_start_game_button_pressed() -> void:
	Global.set_save_name(save_name_line_edit.text)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_cancel_new_game_button_pressed() -> void:
	new_game_panel.visible = false
	main_buttons_container.visible = true

# --- Панель настроек ---

func _on_resolution_option_button_item_selected(index: int) -> void:
	Global.apply_resolution(index)

func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	Global.set_fullscreen(toggled_on)

func _on_settings_back_button_pressed() -> void:
	settings_panel.visible = false
	main_buttons_container.visible = true
