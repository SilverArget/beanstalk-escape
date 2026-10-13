extends Node

signal platform_pause_changed(paused: bool)
signal platform_audio_changed(enabled: bool)
signal ownership_changed(remove_ads: bool)

const REWARDED_PLACEMENTS := [
	"continue_in_stage", "double_stage_reward", "double_treasure",
	"get_more_gold", "skip_stage",
]
const REMOVE_ADS_ID := "remove_ads"
const STORAGE_KEY := "beanstalk_escape_profile_v1"

var language := "en"
var remove_ads_owned := false
var _pending_reward: Callable
var _pending_placement := ""
var _fake_ads := false
var _fake_ad_active := false
var _fake_ad_remaining := 0.0
var _fake_ad_layer: CanvasLayer
var _fake_ad_label: Label
var _game_ready_sent := false

func _ready() -> void:
	_fake_ads = _should_use_fake_rewarded()
	if not _bridge_ready():
		return
	language = str(Bridge.platform.language)
	Bridge.platform.pause_state_changed.connect(_on_pause_state_changed)
	Bridge.platform.audio_state_changed.connect(_on_audio_state_changed)
	Bridge.advertisement.rewarded_state_changed.connect(_on_rewarded_state_changed)
	Bridge.advertisement.set_minimum_delay_between_interstitial(90)
	if Bridge.payments.is_supported:
		Bridge.payments.get_purchases(_on_purchases_loaded)
	call_deferred("_send_game_ready")

func _process(delta: float) -> void:
	if not _game_ready_sent:
		_send_game_ready()
	if _fake_ad_active:
		_fake_ad_remaining = maxf(_fake_ad_remaining - delta, 0.0)
		if _fake_ad_label != null:
			_fake_ad_label.text = "AD\n%d" % maxi(int(ceil(_fake_ad_remaining)), 0)
		if _fake_ad_remaining <= 0.0:
			_finish_fake_ad(true)

func is_rewarded_supported() -> bool:
	return true

func is_payments_supported() -> bool:
	return _bridge_ready() and bool(Bridge.payments.is_supported)

func is_platform_audio_enabled() -> bool:
	return not _bridge_ready() or bool(Bridge.platform.is_audio_enabled)

func show_rewarded(placement: String, on_rewarded: Callable) -> bool:
	if placement not in REWARDED_PLACEMENTS or not is_rewarded_supported() or _pending_reward.is_valid():
		return false
	_pending_placement = placement
	_pending_reward = on_rewarded
	_fake_ads = _should_use_fake_rewarded()
	if _fake_ads:
		_start_fake_ad()
		return true
	Bridge.advertisement.show_rewarded(placement)
	return true

func fake_ad_snapshot() -> Dictionary:
	return {"active": _fake_ad_active, "remaining": _fake_ad_remaining}

func _start_fake_ad() -> void:
	_ensure_fake_ad_ui()
	_fake_ad_active = true
	_fake_ad_remaining = 3.0
	_fake_ad_layer.visible = true
	_fake_ad_label.text = "AD\n3"
	platform_pause_changed.emit(true)

func _finish_fake_ad(rewarded: bool) -> void:
	if not _fake_ad_active:
		return
	_fake_ad_active = false
	_fake_ad_remaining = 0.0
	if _fake_ad_layer != null:
		_fake_ad_layer.visible = false
	platform_pause_changed.emit(false)
	var reward := _pending_reward
	_pending_reward = Callable()
	_pending_placement = ""
	if rewarded and reward.is_valid():
		reward.call()

func _ensure_fake_ad_ui() -> void:
	if _fake_ad_layer != null:
		return
	_fake_ad_layer = CanvasLayer.new()
	_fake_ad_layer.name = "FakeRewardedAd"
	_fake_ad_layer.layer = 1000
	add_child(_fake_ad_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fake_ad_layer.add_child(shade)
	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-110.0, -80.0)
	card.size = Vector2(220.0, 160.0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	shade.add_child(card)
	_fake_ad_label = Label.new()
	_fake_ad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fake_ad_label.add_theme_font_size_override("font_size", 42)
	card.add_child(_fake_ad_label)
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(220.0, 52.0)
	close.pressed.connect(func(): _finish_fake_ad(false))
	card.add_child(close)

func show_interstitial(placement: String) -> bool:
	if remove_ads_owned or _fake_ads or not _bridge_ready() or not Bridge.advertisement.is_interstitial_supported:
		return false
	Bridge.advertisement.show_interstitial(placement)
	return true

func purchase_remove_ads() -> void:
	if is_payments_supported() and not remove_ads_owned:
		Bridge.payments.purchase(REMOVE_ADS_ID, null, _on_remove_ads_purchased)

func storage_get(callback: Callable) -> void:
	if OS.has_feature("web") and _bridge_ready():
		Bridge.storage.get(STORAGE_KEY, callback, true)
	else:
		callback.call(false, null)

func storage_set(value: Dictionary, callback := Callable()) -> void:
	if OS.has_feature("web") and _bridge_ready():
		Bridge.storage.set(STORAGE_KEY, value, callback)
	elif callback.is_valid():
		callback.call(false)

func _send_game_ready() -> void:
	if _game_ready_sent or not _bridge_ready():
		return
	_game_ready_sent = true
	Bridge.platform.send_message(Bridge.PlatformMessage.GAME_READY)

func _on_rewarded_state_changed(ad_state: String) -> void:
	if ad_state == Bridge.RewardedState.REWARDED and _pending_reward.is_valid():
		var reward := _pending_reward
		_pending_reward = Callable()
		_pending_placement = ""
		reward.call()
	elif ad_state == Bridge.RewardedState.FAILED or ad_state == Bridge.RewardedState.CLOSED:
		_pending_reward = Callable()
		_pending_placement = ""

func _on_pause_state_changed(value: Variant) -> void:
	platform_pause_changed.emit(bool(value))

func _on_audio_state_changed(value: Variant) -> void:
	platform_audio_changed.emit(bool(value))

func _on_purchases_loaded(success: bool, purchases: Array) -> void:
	if not success:
		return
	for purchase in purchases:
		if purchase is Dictionary and str(purchase.get("id", "")) == REMOVE_ADS_ID:
			_set_remove_ads_owned(true)
			return

func _on_remove_ads_purchased(success: bool, details: Variant) -> void:
	if success and details is Dictionary and str(details.get("id", REMOVE_ADS_ID)) == REMOVE_ADS_ID:
		_set_remove_ads_owned(true)

func _set_remove_ads_owned(value: bool) -> void:
	remove_ads_owned = value
	ownership_changed.emit(value)

func _bridge_ready() -> bool:
	return get_node_or_null("/root/Bridge") != null and Bridge.platform != null

func _should_use_fake_rewarded() -> bool:
	if not OS.has_feature("web") or _url_fragment_has("fakeads") or _url_fragment_has("debug"):
		return true
	return not _bridge_ready() or not bool(Bridge.advertisement.is_rewarded_supported)

func _url_fragment_has(flag: String) -> bool:
	if not OS.has_feature("web"):
		return false
	var fragment := str(JavaScriptBridge.eval("window.location.hash", true)).trim_prefix("#")
	return flag in fragment.split("&")
