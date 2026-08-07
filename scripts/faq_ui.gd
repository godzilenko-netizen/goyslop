extends CanvasLayer

## Справка и FAQ по всем реализованным системам игры.
## Открывается клавишей F1 или кнопкой из меню.

signal opened
signal closed

var is_open: bool = false
var _active_tab: String = "attributes"

@onready var _root_panel: Control = $RootPanel
@onready var _content_label: RichTextLabel = $RootPanel/InnerBorder/OM/VBox/ContentPanel/Margin/Scroll/ContentLabel

@onready var _tab_attributes: Button = $RootPanel/InnerBorder/OM/VBox/TabRow/TabAttributes
@onready var _tab_combat: Button = $RootPanel/InnerBorder/OM/VBox/TabRow/TabCombat
@onready var _tab_inventory: Button = $RootPanel/InnerBorder/OM/VBox/TabRow/TabInventory
@onready var _tab_items: Button = $RootPanel/InnerBorder/OM/VBox/TabRow/TabItems


func _ready() -> void:
	_root_panel.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Кнопка закрытия
	var close_btn := _root_panel.find_child("CloseBtn", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(close)
	var footer_close := _root_panel.find_child("FooterCloseBtn", true, false) as Button
	if footer_close:
		footer_close.pressed.connect(close)

	# Вкладки
	_tab_attributes.pressed.connect(func() -> void: select_tab("attributes"))
	_tab_combat.pressed.connect(func() -> void: select_tab("combat"))
	_tab_inventory.pressed.connect(func() -> void: select_tab("inventory"))
	_tab_items.pressed.connect(func() -> void: select_tab("items"))

	select_tab("attributes")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle()
			get_viewport().set_input_as_handled()
			return
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_root_panel.show()
	_position_panel()
	emit_signal("opened")


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root_panel.hide()
	emit_signal("closed")


func _position_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _root_panel.get_combined_minimum_size()
	var x := (viewport_size.x - panel_size.x) * 0.5
	var y := (viewport_size.y - panel_size.y) * 0.5
	_root_panel.position = Vector2(maxf(x, 10.0), maxf(y, 10.0))


func select_tab(tab_name: String) -> void:
	_active_tab = tab_name
	_update_tab_buttons()
	_update_tab_content()


func _update_tab_buttons() -> void:
	var active_color := Color(0.82, 0.64, 0.20, 1.0)
	var inactive_color := Color(0.48, 0.38, 0.20, 0.75)
	
	_tab_attributes.add_theme_color_override("font_color", active_color if _active_tab == "attributes" else inactive_color)
	_tab_combat.add_theme_color_override("font_color", active_color if _active_tab == "combat" else inactive_color)
	_tab_inventory.add_theme_color_override("font_color", active_color if _active_tab == "inventory" else inactive_color)
	_tab_items.add_theme_color_override("font_color", active_color if _active_tab == "items" else inactive_color)


func _update_tab_content() -> void:
	if not _content_label:
		return

	match _active_tab:
		"attributes":
			_content_label.text = _get_attributes_faq_text()
		"combat":
			_content_label.text = _get_combat_faq_text()
		"inventory":
			_content_label.text = _get_inventory_faq_text()
		"items":
			_content_label.text = _get_items_faq_text()


# ─── Тексты вкладок FAQ (BBCode) ──────────────────────────────────────────────

func _get_attributes_faq_text() -> String:
	return """[color=#d0a04b][b]— СИСТЕМА ХАРАКТЕРИСТИК И АТРИБУТОВ —[/b][/color]

[color=#94856f]Система основывается на трёх фундаментальных атрибутах. Каждая характеристика открывает экипировку, развивает ресурсы и увеличивает боевую эффективность персонажа.[/color]

[color=#d0a04b][b]1. СИЛА (Strength / STR)[/b][/color]
• [color=#72382e]+5 к максимальному запасу здоровья (Max HP)[/color] за 1 ед. Силы.
• [color=#72382e]+0.1 к регенерации здоровья/сек[/color] за 1 ед. Силы.
• Задаёт требования для ношения тяжелого оружия и тяжелых доспехов.
• Масштабирует урон тяжелого физического оружия.

[color=#d0a04b][b]2. ЛОВКОСТЬ (Dexterity / DEX)[/b][/color]
• [color=#82a438]+0.1% к шансу уклонения (Dodge Chance)[/color] за 1 ед. Ловкости.
• [color=#82a438]+0.1% к шансу критического удара[/color] за 1 ед. Ловкости.
• [color=#82a438]+1% к множителю критического урона[/color] (базово 150%) за 1 ед. Ловкости.
• Задаёт требования для легкой брони, луков, кинжалов, рапир.

[color=#d0a04b][b]3. ИНТЕЛЛЕКТ (Intelligence / INT)[/b][/color]
• [color=#386ba4]+3 к максимальному запасу маны (Max Mana)[/color] за 1 ед. Интеллекта.
• [color=#386ba4]+0.1 к регенерации маны/сек[/color] за 1 ед. Интеллекта.
• [color=#386ba4]+1% к множителю магического критического урона[/color] (базово 150%) за 1 ед. Интеллекта.
• Базовый шанс маг. крита = 0% (увеличивается заклинаниями и экипировкой).
• Задаёт требования для посохов, жезлов, мантий и артефактов.

[color=#d0a04b][b]4. БАЗОВЫЕ РЕСУРСЫ ПЕРСОНАЖА[/b][/color]
• [color=#d4c0a0]Базовое здоровье (Base HP):[/color] [b]50 HP[/b] (до бонусов атрибутов).
• [color=#d4c0a0]Базовая мана (Base Mana):[/color] [b]25 Mana[/b] (до бонусов атрибутов).
• Пример: При старт-статах 10 STR / 10 INT персонаж имеет [b]100 HP[/b] и [b]55 Mana[/b].

[color=#d0a04b][b]5. ТРЕБОВАНИЯ И МАСШТАБИРОВАНИЕ ЭКИПИРОВКИ[/b][/color]
• Предмет не может быть экипирован, если Сила, Ловкость или Интеллект ниже пороговых значений (req_str, req_dex, req_int).
• Мультипликатор урона: Multiplier = 1.0 + (s*STR + d*DEX + i*INT).
"""


func _get_combat_faq_text() -> String:
	return """[color=#d0a04b][b]— УПРАВЛЕНИЕ И БОЕВАЯ СИСТЕМА —[/b][/color]

[color=#d0a04b][b]1. КЛАВИШИ УПРАВЛЕНИЯ[/b][/color]
• [color=#d4c0a0]WASD / Стрелки[/color] — Перемещение персонажа по миру.
• [color=#d4c0a0]Left Shift[/color] — Спринт (ускорение бега).
• [color=#d4c0a0]ЛКМ (Левая кнопка)[/color] — Базовая атака ближнего боя / оружия (Урон от ЛКМ).
• [color=#d4c0a0]Быстрая панель 1..7[/color] — Активация боевых навыков (1 — Огненный шар, 2 — Ледяная стрела и др.).
• [color=#d4c0a0]Z[/color] — Использование зелья Здоровья.
• [color=#d4c0a0]X[/color] — Использование зелья Маны.
• [color=#d4c0a0]E / F[/color] — Взаимодействие с объектами (сундуки, диалоги).
• [color=#d4c0a0]I / B[/color] — Открыть или закрыть Инвентарь.
• [color=#d4c0a0]C[/color] — Открыть или закрыть Окно характеристик персонажа.
• [color=#d4c0a0]F1[/color] — Открыть или закрыть настоящую Справку (FAQ).
• [color=#d4c0a0]Esc[/color] — Меню паузы / Закрытие открытых окон.

[color=#d0a04b][b]2. ЗАЩИТНЫЕ МЕХАНИКИ[/b][/color]
• [color=#d4c0a0]Броня (Armor):[/color] Поглощает часть входящего физического урона. Каждая 1 единица брони на предмете даёт ровно 0.1 итоговой брони.
• [color=#d4c0a0]Уклонение (Dodge Chance):[/color] Процентный шанс полностью избегать урона от физических атак.
• [color=#d4c0a0]Сопротивления (Resistances):[/color] Защита от Огня, Холода, Молнии и Физического урона.
"""


func _get_inventory_faq_text() -> String:
	return """[color=#d0a04b][b]— ИНВЕНТАРЬ И ФЛАКОНЫ —[/b][/color]

[color=#d0a04b][b]1. СЕТОЧНЫЙ ИНВЕНТАРЬ[/b][/color]
• Выполнен в стиле классических ARPG с ячейками под предметы разных размеров (1x1, 2x3).
• Поддерживает Drag & Drop предмета мышью в слоты экипировки или сетку.

[color=#d0a04b][b]2. СЛОТЫ ЭКИПИРОВКИ[/b][/color]
• [color=#d4c0a0]Шлем, Нагрудник, Перчатки, Сапоги[/color] — броня и защитные параметры.
• [color=#d4c0a0]Оружие и Щит[/color] — активное боевое вооружение.
• [color=#d4c0a0]Кольца и Амулет[/color] — ювелирные украшения с бонусами характеристик.

[color=#d0a04b][b]3. НАПОЛНЯЕМЫЕ ФЛАКОНЫ (Refillable Flasks)[/b][/color]
• Флакон Здоровья (клавиша [b]Z[/b]) и Флакон Маны (клавиша [b]X[/b]).
• Автоматически перезаряжаются со временем и при убийстве монстров.
"""


func _get_items_faq_text() -> String:
	return """[color=#d0a04b][b]— ПРЕДМЕТЫ И МИРОВОЙ ЛУТ —[/b][/color]

[color=#d0a04b][b]КОНЦЕПЦИЯ СИСТЕМЫ ПРЕДМЕТОВ[/b][/color]
[color=#94856f]Планируется глубокая ролевая система предметов, вдохновлённая моделью [b]Path of Exile 2 (PoE 2)[/b].[/color]

• [color=#d4c0a0]Систематизация эффектов:[/color] Броня на экипировке систематизирована. 1 единица брони на предмете (например, Нагрудник = 1) даёт ровно 0.1 итоговой брони персонажа.
• [color=#d4c0a0]Разнообразие редкостей:[/color] В будущем предметы будут делиться на Обычные, Магические, Редкие и Уникальные с разнообразными свойствами и модификаторами (аффиксами).
• [color=#d4c0a0]Различные способы получения:[/color] Выпадение из поверженных монстров, разграбление сундуков, крафт и награды.
• [color=#d4c0a0]Подбор предметов:[/color] Выпадающий лут отображается в 3D мире и подбирается кликом мыши.
"""

