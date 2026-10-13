class_name MetaShopUI
extends Control

signal closed
signal run_started

const SLOTS := ["CHARACTERS", "HAIR", "OUTFIT", "EMBLEM", "PET", "TRAIL"]

var economy: EconomyManager
var platform_services: Node
var player_visual: PlayerVisual
var mode := "SHOP"
var active_tab := "CHARACTERS"
var preview_character_id := ""
var preview_item: Dictionary = {}
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
var double_treasure_button: Button
var pending_double_gold := 0

func setup(manager: EconomyManager, gameplay_visual: PlayerVisual, services: Node = null) -> void:
	economy = manager
	platform_services = services
	player_visual = gameplay_visual
	_build()
	economy.changed.connect(func(_snapshot): refresh())
	refresh()

func open_shop() -> void:
	mode = "SHOP"
	active_tab = "CHARACTERS"
	preview_character_id = ""
	preview_item = {}
	visible = true
	refresh()

func open_character_select() -> void:
	mode = "SELECT"
	active_gender = "MALE" if str(economy.shop.selected_character).begins_with("M") else "FEMALE"
	visible = true
	refresh()
	call_deferred("_focus_start_button")

func open_map() -> void:
	mode = "MAP"
	pending_double_gold = 0
	visible = true
	refresh()
	call_deferred("_focus_first_map_action")

func close() -> void:
	preview_character_id = ""
	preview_item = {}
	_apply_preview()
	visible = false
	closed.emit()

func _process(delta: float) -> void:
	if visible and preview != null:
		preview.preview_tick(delta)

func _input(event: InputEvent) -> void:
	if not visible or mode != "SELECT" or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("move_left"):
		_cycle_character(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_cycle_character(1)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(panel):
		_layout()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color("102d27")
	backdrop.border_color = Color("d0a83c")
	backdrop.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", backdrop)
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
	preview.scale = Vector2.ONE * 1.45
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
	double_treasure_button = Button.new()
	double_treasure_button.text = "DOUBLE TREASURE (AD)"
	double_treasure_button.custom_minimum_size = Vector2(210, 40)
	double_treasure_button.pressed.connect(_double_treasure)
	footer.add_child(double_treasure_button)
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
	preview.position = Vector2(preview_width * 0.262, preview_host.size.y * 0.48)
	var map_mode := mode == "MAP"
	preview_host.visible = not map_mode
	scroll.position = Vector2(8, 56) if map_mode else Vector2(preview_width + 16, 92)
	scroll.size = Vector2(width - 16 if map_mode else width - preview_width - 24, maxf(footer_y - scroll.position.y - 6.0, 120.0))
	grid.columns = (6 if scroll.size.x >= 720.0 else 3) if map_mode else (3 if scroll.size.x >= 450.0 else 2)
	tabs.size = Vector2(width - 16, 38)

func refresh() -> void:
	if economy == null:
		return
	title_label.text = "STAGE MAP" if mode == "MAP" else ("CHARACTER SELECT" if mode == "SELECT" else "SHOP")
	gold_label.text = "GOLD %d  ·  LV %d" % [economy.gold, economy.level]
	start_button.visible = mode == "SELECT"
	double_treasure_button.visible = mode == "MAP" and pending_double_gold > 0 and platform_services != null and platform_services.is_rewarded_supported()
	if double_treasure_button.visible:
		double_treasure_button.text = "DOUBLE +%d (AD)" % pending_double_gold
	_rebuild_tabs()
	_rebuild_cards()
	_apply_preview()
	_layout()

func _focus_start_button() -> void:
	if visible and mode == "SELECT" and start_button.visible and not start_button.disabled:
		start_button.grab_focus()

func _cycle_character(direction: int) -> void:
	var candidates: Array[String] = []
	for character_id_value in economy.character_catalog():
		var character_id := str(character_id_value)
		var data: Dictionary = economy.character_catalog()[character_id]
		if str(data.gender) == active_gender and economy.character_available(character_id):
			candidates.append(character_id)
	if candidates.is_empty():
		return
	var current := candidates.find(str(economy.shop.selected_character))
	var next_index := posmod((0 if current < 0 else current) + direction, candidates.size())
	economy.select_character(candidates[next_index])
	refresh()
	call_deferred("_focus_start_button")

func _rebuild_tabs() -> void:
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	tabs.visible = mode != "MAP"
	if mode == "MAP":
		return
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
			button.custom_minimum_size = Vector2(92, 36)
			button.add_theme_font_size_override("font_size", 12)
			button.pressed.connect(func(): active_tab = slot; refresh())
			tabs.add_child(button)

func _rebuild_cards() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	if mode == "MAP":
		for stage_number in range(1, 31):
			grid.add_child(_map_node_card(stage_number))
	elif mode == "SELECT":
		for character_id in economy.character_catalog():
			var data: Dictionary = economy.character_catalog()[character_id]
			if mode == "SELECT" and str(data.gender) != active_gender:
				continue
			grid.add_child(_character_card(character_id, data))
	else:
		if active_tab == "CHARACTERS":
			for character_id in economy.character_catalog():
				grid.add_child(_character_card(character_id, economy.character_catalog()[character_id]))
		else:
			var items := economy.cosmetic_catalog(active_tab)
			if items.is_empty() and active_tab == "PET":
				var coming := Label.new()
				coming.text = "COMING SOON"
				coming.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				coming.custom_minimum_size = Vector2(320, 120)
				grid.add_child(coming)
			for item in items:
				grid.add_child(_cosmetic_card(item))

func _map_node_card(stage_number: int) -> Control:
	var progression := economy.progression_snapshot()
	var completed: Array = progression.completed_stages
	var skipped: Array = progression.skipped_stages
	var claimed: Array = progression.treasures_claimed
	var is_summit := stage_number % 5 == 0
	var status := "COMPLETED" if completed.has(stage_number) else ("SKIPPED" if skipped.has(stage_number) else "LOCKED")
	if status == "LOCKED" and (stage_number == 1 or completed.has(stage_number - 1)):
		status = "OPEN"
	var card := _base_card("%s %02d" % ["TREASURE" if is_summit else "STAGE", stage_number], status)
	card.custom_minimum_size = Vector2(120, 108)
	var body := _card_body(card)
	var button := Button.new()
	button.custom_minimum_size.y = 34
	if is_summit and claimed.has(stage_number):
		button.text = "CLAIMED"
		button.disabled = true
	elif is_summit and completed.has(stage_number):
		button.text = "CLAIM"
		button.pressed.connect(_claim_treasure.bind(stage_number))
	else:
		button.text = status
		button.disabled = true
	body.add_child(button)
	return card

func _claim_treasure(stage_number: int) -> void:
	var reward := economy.claim_map_treasure(stage_number)
	if reward.is_empty():
		return
	pending_double_gold = int(reward.get("amount", 0)) if str(reward.get("type", "")) == "gold" else 0
	refresh()

func _double_treasure() -> void:
	if pending_double_gold <= 0 or platform_services == null:
		return
	var reward := pending_double_gold
	pending_double_gold = 0
	platform_services.show_rewarded("double_treasure", func(): economy.grant_gold(reward); refresh())
	refresh()

func _focus_first_map_action() -> void:
	if not visible or mode != "MAP":
		return
	for card in grid.get_children():
		for node in card.find_children("*", "Button", true, false):
			var button := node as Button
			if not button.disabled:
				button.grab_focus()
				return

func _base_card(title: String, subtitle: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(168, 220)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("183c32")
	card_style.border_color = Color("cda944")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 8.0
	card_style.content_margin_right = 8.0
	card_style.content_margin_top = 6.0
	card_style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", card_style)
	var body := VBoxContainer.new()
	card.add_child(body)
	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	name_label.max_lines_visible = 2
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.custom_minimum_size.y = 40
	body.add_child(name_label)
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(sub)
	return card

func _card_body(card: PanelContainer) -> VBoxContainer:
	return card.get_child(0) as VBoxContainer

func _character_card(character_id: String, data: Dictionary) -> Control:
	var card := _base_card("%s · %s" % [character_id, data.name], "LV %d · %d GOLD" % [int(data.level), int(data.price)])
	var body := _card_body(card)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(112, 104)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://assets/art/character_frames/%s/front.png" % character_id.to_lower()
	if ResourceLoader.exists(path): portrait.texture = load(path)
	body.add_child(portrait)
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
	body.add_child(button)
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_preview_character(character_id))
	button.focus_entered.connect(func(): _preview_character(character_id))
	return card

func _cosmetic_card(item: Dictionary) -> Control:
	var source := str(item.get("source", ""))
	var is_pet := str(item.get("slot", "")) == "PET"
	var is_trail := str(item.get("slot", "")) == "TRAIL"
	var subtitle := "%s\nLV %d · %d GOLD" % [str(item.get("effect_name", "")), int(item.level), int(item.price)] if is_pet or is_trail else (source if not source.is_empty() else "%s · LV %d" % [item.rarity, int(item.level)])
	if is_trail and not source.is_empty():
		subtitle += "\n%s" % source
	var card := _base_card(str(item.name), subtitle)
	var body := _card_body(card)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(112, 88 if is_pet else 104)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if is_pet:
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var art_folder := "pets" if str(item.get("slot", "")) == "PET" else "cosmetics"
	icon.texture = load("res://assets/art/%s/%s" % [art_folder, item.image])
	body.add_child(icon)
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
	body.add_child(button)
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_preview_item(item))
	button.focus_entered.connect(func(): _preview_item(item))
	return card

func _preview_character(character_id: String) -> void:
	preview_character_id = character_id
	preview_item = {}
	_apply_preview()

func _preview_item(item: Dictionary) -> void:
	preview_item = item.duplicate(true)
	_apply_preview()

func _apply_preview() -> void:
	preview.set_skin(preview_character_id if not preview_character_id.is_empty() else str(economy.shop.selected_character))
	preview.set_cosmetics(economy.shop.equipped, economy.cosmetic_catalog())
	if not preview_item.is_empty():
		preview.preview_cosmetic(preview_item)
	preview.show_front_preview()
	if player_visual != null:
		player_visual.set_skin(str(economy.shop.selected_character))
		player_visual.set_cosmetics(economy.shop.equipped, economy.cosmetic_catalog())

func _start_run() -> void:
	_apply_preview()
	visible = false
	run_started.emit()
