extends Control

const GAME_RELATIVE_PATH := "../Game/CityRun.exe"
var status_label: Label
var play_button: Button

func _ready() -> void:
	_build_ui()
	_check_game()

func _style_panel(panel: PanelContainer, color: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#090d16")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 24)
	root.add_theme_constant_override("margin_left", 38)
	root.add_theme_constant_override("margin_right", 38)
	root.add_theme_constant_override("margin_top", 30)
	root.add_theme_constant_override("margin_bottom", 30)
	add_child(root)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 18)
	root.add_child(left)
	var brand := Label.new()
	brand.text = "CITY RUN"
	brand.add_theme_font_size_override("font_size", 42)
	brand.add_theme_color_override("font_color", Color("#f4f6fb"))
	left.add_child(brand)
	var edition := Label.new()
	edition.text = "PC DEMO  /  BUILD 0.2"
	edition.add_theme_font_size_override("font_size", 13)
	edition.add_theme_color_override("font_color", Color("#e34a55"))
	left.add_child(edition)
	var hero := PanelContainer.new()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(hero, Color("#121a29"), Color("#29374b"))
	left.add_child(hero)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	hero.add_child(col)
	var tag := Label.new()
	tag.text = "OPEN-WORLD CITY DEMO"
	tag.add_theme_color_override("font_color", Color("#ff626b"))
	col.add_child(tag)
	var title := Label.new()
	title.text = "ТВОЙ ГОРОД.\nТВОИ ПРАВИЛА."
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(title)
	var desc := Label.new()
	desc.text = "Исследуй улицы, садись за руль и выполни первую доставку. Ранняя демо-версия City Run."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color("#b4c0d2"))
	col.add_child(desc)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	col.add_child(status_label)
	play_button = Button.new()
	play_button.text = "▶   ИГРАТЬ"
	play_button.custom_minimum_size = Vector2(0, 58)
	play_button.add_theme_font_size_override("font_size", 18)
	play_button.pressed.connect(_launch_game)
	col.add_child(play_button)
	var right := PanelContainer.new()
	right.custom_minimum_size.x = 300
	_style_panel(right, Color("#101725"), Color("#263449"))
	root.add_child(right)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 14)
	right.add_child(info)
	for line in ["СОСТАВ ДЕМО", "3D-город и улицы", "Управляемый автомобиль", "Дорожный трафик", "Миссия с посылкой", "", "УПРАВЛЕНИЕ", "WASD — движение", "Мышь — обзор", "E — взаимодействие", "Esc — курсор"]:
		var label := Label.new()
		label.text = line
		label.add_theme_color_override("font_color", Color("#f05a65") if line in ["СОСТАВ ДЕМО", "УПРАВЛЕНИЕ"] else Color("#cbd5e1"))
		info.add_child(label)

func _game_path() -> String:
	return ProjectSettings.globalize_path("res://") + GAME_RELATIVE_PATH

func _check_game() -> void:
	var exists := FileAccess.file_exists(_game_path())
	play_button.disabled = not exists
	status_label.text = "ИГРА НАЙДЕНА · ГОТОВА К ЗАПУСКУ" if exists else "ФАЙЛ ИГРЫ НЕ НАЙДЕН · ПРОВЕРЬТЕ ПАПКУ Game"
	status_label.add_theme_color_override("font_color", Color("#62d99b") if exists else Color("#ffb45b"))

func _launch_game() -> void:
	var path := _game_path()
	if not FileAccess.file_exists(path):
		_check_game()
		return
	var result := OS.create_process(path, [])
	if result == -1:
		status_label.text = "НЕ УДАЛОСЬ ЗАПУСТИТЬ ИГРУ"
	else:
		status_label.text = "CITY RUN ЗАПУЩЕНА"
