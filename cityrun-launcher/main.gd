extends Control

const GAME_RELATIVE_PATH := "../Game/CityRun.exe"
const DEFAULT_LICENSE_API := "https://YOUR-DOMAIN"
const LICENSE_FILE := "user://cityrun_license.cfg"
const MACHINE_FILE := "user://cityrun_machine.id"

var status_label: Label
var play_button: Button
var key_input: LineEdit
var api_input: LineEdit
var request_node: HTTPRequest
var request_mode := "activate"
var pending_key := ""
var machine_id := ""
var request_in_progress := false

func _ready() -> void:
	_build_ui()
	request_node = HTTPRequest.new()
	request_node.timeout = 15.0
	request_node.request_completed.connect(_on_license_response)
	add_child(request_node)
	machine_id = _load_machine_id()
	_load_saved_license()
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
	edition.text = "PC DEMO  /  BUILD 0.3"
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
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	col.add_child(status_label)
	play_button = Button.new()
	play_button.text = "▶   ИГРАТЬ"
	play_button.custom_minimum_size = Vector2(0, 58)
	play_button.add_theme_font_size_override("font_size", 18)
	play_button.disabled = true
	play_button.pressed.connect(_launch_game)
	col.add_child(play_button)
	var right := PanelContainer.new()
	right.custom_minimum_size.x = 330
	_style_panel(right, Color("#101725"), Color("#263449"))
	root.add_child(right)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	right.add_child(info)
	for line in ["СОСТАВ ДЕМО", "3D-город и улицы", "Управляемый автомобиль", "Дорожный трафик", "Миссия с посылкой", "", "АКТИВАЦИЯ КЛЮЧА"]:
		var label := Label.new()
		label.text = line
		label.add_theme_color_override("font_color", Color("#f05a65") if line in ["СОСТАВ ДЕМО", "АКТИВАЦИЯ КЛЮЧА"] else Color("#cbd5e1"))
		info.add_child(label)
	key_input = LineEdit.new()
	key_input.placeholder_text = "CITY-XXXXXX-..."
	key_input.clear_button_enabled = true
	info.add_child(key_input)
	api_input = LineEdit.new()
	api_input.placeholder_text = "https://адрес-сервера"
	api_input.text = DEFAULT_LICENSE_API
	api_input.clear_button_enabled = true
	info.add_child(api_input)
	var activate_button := Button.new()
	activate_button.text = "АКТИВИРОВАТЬ КЛЮЧ"
	activate_button.custom_minimum_size.y = 46
	activate_button.pressed.connect(_activate_license)
	info.add_child(activate_button)
	var help := Label.new()
	help.text = "WASD — движение\nМышь — обзор\nE — взаимодействие\nEsc — курсор"
	help.add_theme_color_override("font_color", Color("#aab7c9"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(help)

func _game_path() -> String:
	return OS.get_executable_path().get_base_dir().path_join(GAME_RELATIVE_PATH).simplify_path()

func _load_machine_id() -> String:
	if FileAccess.file_exists(MACHINE_FILE):
		var file := FileAccess.open(MACHINE_FILE, FileAccess.READ)
		if file:
			var saved := file.get_as_text().strip_edges()
			if saved.length() >= 16:
				return saved
	var generated := Crypto.new().generate_random_bytes(24).hex_encode()
	var output := FileAccess.open(MACHINE_FILE, FileAccess.WRITE)
	if output:
		output.store_string(generated)
	return generated

func _load_saved_license() -> void:
	if not FileAccess.file_exists(LICENSE_FILE):
		return
	var config := ConfigFile.new()
	if config.load(LICENSE_FILE) == OK:
		key_input.text = str(config.get_value("license", "key", ""))
		api_input.text = str(config.get_value("license", "api", DEFAULT_LICENSE_API))

func _save_license(key: String, api: String) -> void:
	var config := ConfigFile.new()
	config.set_value("license", "key", key)
	config.set_value("license", "api", api)
	config.save(LICENSE_FILE)

func _check_game() -> void:
	var exists := FileAccess.file_exists(_game_path())
	if not exists:
		status_label.text = "ФАЙЛ ИГРЫ НЕ НАЙДЕН · ПРОВЕРЬТЕ ПАПКУ Game"
		status_label.add_theme_color_override("font_color", Color("#ffb45b"))
		return
	status_label.text = "ИГРА НАЙДЕНА · ВВЕДИТЕ И АКТИВИРУЙТЕ КЛЮЧ"
	status_label.add_theme_color_override("font_color", Color("#ffb45b"))

func _activate_license() -> void:
	pending_key = key_input.text.strip_edges().to_upper()
	_request_license(false)

func _launch_game() -> void:
	pending_key = key_input.text.strip_edges().to_upper()
	_request_license(true)

func _request_license(launch_after: bool) -> void:
	var api := api_input.text.strip_edges().trim_suffix("/")
	if not api.begins_with("https://") or api.contains("YOUR-DOMAIN"):
		_set_status("УКАЖИТЕ РАБОЧИЙ HTTPS-АДРЕС СЕРВЕРА ЛИЦЕНЗИЙ", false)
		return
	if pending_key.is_empty():
		_set_status("ВВЕДИТЕ КЛЮЧ CITY RUN", false)
		return
	if request_in_progress:
		_set_status("ПОДОЖДИТЕ: ПРОВЕРКА УЖЕ ВЫПОЛНЯЕТСЯ", false)
		return
	request_in_progress = true
	request_mode = "launch" if launch_after else "activate"
	play_button.disabled = true
	_set_status("ПРОВЕРЯЕМ ЛИЦЕНЗИЮ…", true)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload := {"key": pending_key, "machineId": machine_id}
	var error := request_node.request(api + "/api/activate", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		_set_status("НЕ УДАЛОСЬ ПОДКЛЮЧИТЬСЯ К СЕРВЕРУ (" + str(error) + ")", false)

func _on_license_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request_in_progress = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_status("НЕТ СВЯЗИ С СЕРВЕРОМ ЛИЦЕНЗИЙ. ПРОВЕРЬТЕ ИНТЕРНЕТ.", false)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if response_code != 200 or typeof(data) != TYPE_DICTIONARY or not bool(data.get("valid", false)):
		var message := "КЛЮЧ НЕ ПРОШЁЛ ПРОВЕРКУ"
		if typeof(data) == TYPE_DICTIONARY:
			message = str(data.get("error", message)).to_upper()
		_set_status(message, false)
		return
	_save_license(pending_key, api_input.text.strip_edges().trim_suffix("/"))
	if request_mode == "launch":
		_start_game()
	else:
		_set_status("ЛИЦЕНЗИЯ АКТИВИРОВАНА · МОЖНО ИГРАТЬ", true)
		play_button.disabled = not FileAccess.file_exists(_game_path())

func _start_game() -> void:
	var path := _game_path()
	if not FileAccess.file_exists(path):
		_set_status("CITYRUN.EXE НЕ НАЙДЕН В ПАПКЕ Game", false)
		return
	var result := OS.create_process(path, [])
	if result == -1:
		_set_status("НЕ УДАЛОСЬ ЗАПУСТИТЬ ИГРУ", false)
	else:
		_set_status("CITY RUN ЗАПУЩЕНА", true)

func _set_status(message: String, success: bool) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("#62d99b") if success else Color("#ffb45b"))
	if not success:
		play_button.disabled = true
