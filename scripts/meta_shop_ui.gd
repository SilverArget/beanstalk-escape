class_name MetaShopUI
extends Control

signal closed
signal run_started

const SLOTS := ["CHARACTERS", "HAT", "FACE", "TRAIL", "OUTFIT"]

var economy: EconomyManager
var player_visual: PlayerVisual
var mode := "SHOP"
var active_tab := "CHARACTERS"
var active_gender := "MALE"
var panel: Panel
var title_label: Label
var tabs: HBoxContainer
var grid: GridContainer
var scroll: ScrollContainer
var preview_host: Control
var preview: PlayerVisual
var footer: HBoxContainer
var gold_label: Label
var start_button: Button

func setup(manager: EconomyManager, gameplay_visual: PlayerVisual) -> void:
	economy = manager
	player_visual = gameplay_visual
	_build()
	economy.changed.connect(func(_snapshot): refresh())
	refresh()

func open_shop() -> void:
	mode = "SHOP"
	active_tab = "CHARACTERS"
	visible = true
	refresh()

func open_character_select() -> void:
	mode = "SELECT"
	active_gender = "MALE" if str(economy.shop.selected_character).begins_with("M") else "FEMALE"
	visible = true
	refresh()

func close() -> void:
	visible = false
	closed.emit()

func _process(delta: float) -> void:
	if visible and preview != null:
		preview.preview_tick(delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(panel):
		_layout()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	panel.add_child(title_label)
	tabs = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(tabs)
	preview_host = Control.new()
	preview_host.clip_contents = true
	panel.add_child(preview_host)
	preview = PlayerVisual.new()
	preview.name = "LivePreview"
	preview.scale = Vector2.ONE * 1.65
	preview_host.add_child(preview)
	scroll = ScrollContainer.new()
	panel.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(footer)
	gold_label = Label.new()
	gold_label.custom_minimum_size = Vector2(190, 40)
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(gold_label)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(130, 40)
	back.pressed.connect(close)
	footer.add_child(back)
	start_button = Button.new()
	start_button.text = "START"
	start_button.custom_minimum_size = Vector2(150, 40)
	start_button.pressed.connect(_start_run)
	footer.add_child(start_button)
	_layout()

func _layout() -> void:
	var width := maxf(size.x, 320.0)
	var height := maxf(size.y, 320.0)
	title_label.position = Vector2(12, 8)
	title_label.size = Vector2(width - 24, 36)
	tabs.position = Vector2(8, 48)
	tabs.size = Vector2(width - 16, 38)
	var footer_y := height - 48.0
	footer.position = Vector2(8, footer_y)
	footer.size = Vector2(width - 16, 42)
	var preview_width := clampf(width * 0.27, 190.0, 260.0)
	preview_host.position = Vector2(8, 92)
	preview_host.size = Vector2(preview_width, maxf(footer_y - 98.0, 120.0))
	preview.position = Vector2(preview_width * 0.5, preview_host.size.y * 0.52)
	scroll.position = Vector2(preview_width + 16, 92)
	scroll.size = Vector2(width - preview_width - 24, maxf(footer_y - 98.0, 120.0))
	grid.columns = 3 if scroll.size.x >= 450.0 else 2

func refresh() -> void:
	if economy == null:
		return
	title_label.text = "CHARACTER SELECT" if mode == "SELECT" else "SHOP"
	gold_label.text = "GOLD %d  ·  LV %d" % [economy.gold, economy.level]
	start_button.visible = mode == "SELECT"
	_rebuild_tabs()
	_rebuild_cards()
	_apply_preview()

func _rebuild_tabs() -> void:
	for child in tabs.get_children(): child.queue_free()
	if mode == "SELECT":
		for gender in ["MALE", "FEMALE"]:
			var button := Button.new()
			button.text = gender
			button.toggle_mode = true
			button.button_pressed = active_gender == gender
			button.custom_minimum_size = Vector2(140, 36)
			button.pressed.connect(func(): active_gender = gender; refresh())
			tabs.add_child(button)
	else:
		for slot in SLOTS:
			var button := Button.new()
			button.text = slot
			button.toggle_mode = true
			button.button_pressed = active_tab == slot
			button.custom_minimum_size = Vector2(118, 36)
			button.pressed.connect(func(): active_tab = slot; refresh())
			tabs.add_child(button)

func _rebuild_cards() -> void:
	for child in grid.get_children(): child.queue_free()
	if mode == "SELECT" or active_tab == "CHARACTERS":
		for character_id in economy.character_catalog():
			var data: Dictionary = economy.character_catalog()[character_id]
			if mode == "SELECT" and str(data.gender) != active_gender:
				continue
			grid.add_child(_character_card(character_id, data))
	else:
		for item in economy.cosmetic_catalog(active_tab):
			grid.add_child(_cosmetic_card(item))

func _base_card(title: String, subtitle: String) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(142, 174)
	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.y = 38
	card.add_child(name_label)
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	card.add_child(sub)
	return card

func _character_card(character_id: String, data: Dictionary) -> Control:
	var card := _base_card("%s · %s" % [character_id, data.name], "LV %d · %d GOLD" % [int(data.level), int(data.price)])
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(90, 78)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://assets/art/character_frames/%s/hang.png" % character_id.to_lower()
	if ResourceLoader.exists(path): portrait.texture = load(path)
	card.add_child(portrait)
	var button := Button.new()
	button.custom_minimum_size.y = 36
	var owned: bool = economy.shop.owned.has(character_id)
	var reason := economy.locked_reason(character_id)
	if owned and economy.character_available(character_id):
		button.text = "SELECTED" if str(economy.shop.selected_character) == character_id else "SELECT"
		button.disabled = str(economy.shop.selected_character) == character_id
		button.pressed.connect(func(): economy.select_character(character_id); refresh())
	elif reason.is_empty():
		button.text = "BUY · %d" % int(data.price)
		button.pressed.connect(func(): economy.buy(character_id); refresh())
	else:
		button.text = reason
		button.disabled = true
	card.add_child(button)
	card.mouse_entered.connect(func(): _preview_character(character_id))
	button.focus_entered.connect(func(): _preview_character(character_id))
	return card

func _cosmetic_card(item: Dictionary) -> Control:
	var source := str(item.get("source", ""))
	var subtitle := source if not source.is_empty() else "%s · LV %d" % [item.rarity, int(item.level)]
	var card := _base_card(str(item.name), subtitle)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(90, 78)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load("res://assets/art/cosmetics/%s" % item.image)
	card.add_child(icon)
	var button := Button.new()
	button.custom_minimum_size.y = 36
	var item_id := str(item.id)
	var owned: bool = economy.shop.owned.has(item_id)
	var reason := economy.locked_reason(item_id)
	if owned:
		var equipped: bool = str(economy.shop.equipped.get(item.slot, "")) == item_id
		button.text = "UNEQUIP" if equipped else "EQUIP"
		button.pressed.connect(func(): economy.equip(item_id); refresh())
	elif reason.is_empty():
		button.text = "BUY · %d" % int(item.price)
		button.pressed.connect(func(): economy.buy(item_id); refresh())
	else:
		button.text = reason
		button.disabled = true
	card.add_child(button)
	card.mouse_entered.connect(func(): _preview_item(item))
	button.focus_entered.connect(func(): _preview_item(item))
	return card

func _preview_character(character_id: String) -> void:
	if economy.character_available(character_id): preview.set_skin(character_id)

func _preview_item(item: Dictionary) -> void:
	preview.set_cosmetics(economy.shop.equipped, economy.cosmetic_catalog())
	preview.preview_cosmetic(item)

func _apply_preview() -> void:
	preview.set_skin(str(economy.shop.selected_character))
	preview.set_cosmetics(economy.shop.equipped, economy.cosmetic_catalog())
	if player_visual != null:
		player_visual.set_skin(str(economy.shop.selected_character))
		player_visual.set_cosmetics(economy.shop.equipped, economy.cosmetic_catalog())

func _start_run() -> void:
	_apply_preview()
	visible = false
	run_started.emit()
