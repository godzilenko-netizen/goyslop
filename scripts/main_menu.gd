extends Control

const GothicUI = preload("res://scripts/ui/gothic_ui.gd")
const GOTHIC_THEME = preload("res://themes/diablo2_theme.tres")
const MENU_BACKDROP = preload("res://assets/ui/main_menu_backdrop.png")

@onready var main_buttons_container: Control = $MainButtons
@onready var new_game_panel: Panel = $NewGamePanel
@onready var settings_panel: Panel = $SettingsPanel

@onready var save_name_line_edit: LineEdit = $NewGamePanel/VBoxContainer/SaveNameLineEdit
@onready var resolution_option_button: OptionButton = $SettingsPanel/VBoxContainer/ResolutionOptionButton
@onready var fullscreen_check_box: CheckBox = $SettingsPanel/VBoxContainer/FullscreenCheckBox

func _ready() -> void:
	_apply_gothic_menu_style()
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


func _apply_gothic_menu_style() -> void:
	theme = GOTHIC_THEME
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := get_node_or_null("BackgroundArt") as TextureRect
	if not background:
		background = TextureRect.new()
		background.name = "BackgroundArt"
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.texture = MENU_BACKDROP
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background)
		move_child(background, 0)
	var vignette := $ColorRect as ColorRect
	vignette.color = Color(0.015, 0.009, 0.008, 0.34)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := $TitleLabel as Label
	title.offset_left = -310.0
	title.offset_top = 62.0
	title.offset_right = 310.0
	title.offset_bottom = 126.0
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", GothicUI.BRASS_LIGHT)
	title.add_theme_color_override("font_outline_color", GothicUI.INK)
	title.add_theme_constant_override("outline_size", 7)
	var subtitle := get_node_or_null("Subtitle") as Label
	if not subtitle:
		subtitle = Label.new()
		subtitle.name = "Subtitle"
		subtitle.text = "ТЁМНАЯ РЕТРО ACTION-RPG"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.anchor_left = 0.5
		subtitle.anchor_right = 0.5
		subtitle.offset_left = -260.0
		subtitle.offset_top = 126.0
		subtitle.offset_right = 260.0
		subtitle.offset_bottom = 154.0
		subtitle.add_theme_font_size_override("font_size", 12)
		subtitle.add_theme_color_override("font_color", GothicUI.BONE_MUTED)
		subtitle.add_theme_color_override("font_outline_color", GothicUI.INK)
		subtitle.add_theme_constant_override("outline_size", 4)
		add_child(subtitle)

	main_buttons_container.offset_left = -180.0
	main_buttons_container.offset_top = -108.0
	main_buttons_container.offset_right = 180.0
	main_buttons_container.offset_bottom = 132.0
	_add_menu_panel(main_buttons_container)
	var main_vbox := main_buttons_container.get_node("VBoxContainer") as VBoxContainer
	main_vbox.offset_left = 26.0
	main_vbox.offset_top = 30.0
	main_vbox.offset_right = -26.0
	main_vbox.offset_bottom = -30.0
	main_vbox.add_theme_constant_override("separation", 10)
	for button in main_vbox.get_children():
		if button is Button:
			button.custom_minimum_size = Vector2(button.custom_minimum_size.x, 48.0)

	_style_dialog_panel(new_game_panel, Vector2(500.0, 250.0))
	_style_dialog_panel(settings_panel, Vector2(500.0, 310.0))


func _add_menu_panel(control: Control) -> void:
	var panel := control.get_node_or_null("GothicPanel") as Panel
	if panel:
		return
	panel = Panel.new()
	panel.name = "GothicPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.025, 0.016, 0.013, 0.93), GothicUI.BRASS_DARK, 3, 0, 16))
	control.add_child(panel)
	control.move_child(panel, 0)


func _style_dialog_panel(panel: Panel, dimensions: Vector2) -> void:
	panel.offset_left = -dimensions.x * 0.5
	panel.offset_top = -dimensions.y * 0.5
	panel.offset_right = dimensions.x * 0.5
	panel.offset_bottom = dimensions.y * 0.5
	panel.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.025, 0.016, 0.013, 0.98), GothicUI.BRASS_DARK, 3, 0, 18))
	var content := panel.get_node("VBoxContainer") as VBoxContainer
	content.offset_left = 34.0
	content.offset_top = 30.0
	content.offset_right = -34.0
	content.offset_bottom = -30.0

# --- Кнопки главного меню ---

func _on_new_game_button_pressed() -> void:
	main_buttons_container.visible = false
	new_game_panel.visible = true
	save_name_line_edit.grab_focus()

const FAQ_SCENE = preload("res://scenes/faq_ui.tscn")
var _faq_instance: CanvasLayer = null

func _on_settings_button_pressed() -> void:
	main_buttons_container.visible = false
	settings_panel.visible = true

func _on_faq_button_pressed() -> void:
	if not _faq_instance:
		_faq_instance = FAQ_SCENE.instantiate() as CanvasLayer
		add_child(_faq_instance)
	if _faq_instance.has_method("open"):
		_faq_instance.call("open")

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
