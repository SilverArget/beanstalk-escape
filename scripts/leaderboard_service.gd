class_name LeaderboardService
extends Node

const ONLINE_ENDPOINT := ""
const ONLINE_API_KEY := ""
const LEADERBOARD_ID := "best_score"

var local_adapter: LocalAdapter
var online_adapter: OnlineAdapter
var platform_adapter: PlatformAdapter
var bridge_node: Node = null

func configure(manager: SaveManager) -> void:
	local_adapter = LocalAdapter.new(manager)
	online_adapter = OnlineAdapter.new(self)
	platform_adapter = PlatformAdapter.new(self)

func submit_score(player: String, score: int, callback: Callable) -> void:
	player = player.strip_edges().left(48)
	score = maxi(score, 0)
	local_adapter.submit(player, score)
	match platform_adapter.board_type():
		"in_game":
			platform_adapter.fetch(10, callback, true, score)
			return
		"native", "native_popup":
			var result := local_adapter.fetch(10)
			result.source = "native"
			callback.call(result)
			platform_adapter.submit_native.call_deferred(score)
			return
	if online_adapter.enabled():
		online_adapter.submit(player, score, func(ok: bool):
			if ok:
				fetch_top(10, callback)
			else:
				callback.call(local_adapter.fetch(10))
		)
	else:
		callback.call(local_adapter.fetch(10))

func fetch_top(limit: int, callback: Callable) -> void:
	limit = clampi(limit, 0, 10)
	match platform_adapter.board_type():
		"in_game":
			platform_adapter.fetch(limit, callback)
			return
		"native", "native_popup":
			var result := local_adapter.fetch(limit)
			result.source = "native"
			callback.call(result)
			return
	if not online_adapter.enabled():
		callback.call(local_adapter.fetch(limit))
		return
	online_adapter.fetch(limit, func(ok: bool, entries: Array):
		if not ok:
			callback.call(local_adapter.fetch(limit))
			return
		entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.score) > int(b.score))
		var ranked: Array = []
		var player_rank := 0
		for entry: Dictionary in entries.slice(0, limit):
			var rank := ranked.size() + 1
			var is_player := player_rank == 0 and str(entry.name) == local_adapter.player_name and int(entry.score) == local_adapter.player_score
			if is_player:
				player_rank = rank
			ranked.append({"rank": rank, "name": str(entry.name), "score": int(entry.score), "is_player": is_player})
		callback.call({"ok": true, "entries": ranked, "player_rank": player_rank, "source": "online"})
	)

class LocalAdapter extends RefCounted:
	var manager: SaveManager
	var player_name := ""
	var player_score := -1
	var player_rank := 0

	func _init(save: SaveManager) -> void:
		manager = save
		if manager.profile.is_empty():
			manager.load_profile()

	func submit(player: String, score: int) -> void:
		# The death screen persists before submission; direct API callers persist here.
		var pending := manager.pending_run_score
		if pending.is_empty() or str(pending.name) != player or int(pending.score) != score:
			manager.record_run_score(player, score, str(manager.shop_snapshot().selected_character))
			pending = manager.pending_run_score
		player_name = player
		player_score = score
		player_rank = int(pending.rank)
		manager.pending_run_score = {}

	func fetch(limit: int) -> Dictionary:
		var ranked: Array = []
		var entries: Array = manager.profile.get("leaderboard_local", [])
		for entry: Dictionary in entries.slice(0, clampi(limit, 0, 10)):
			var rank := ranked.size() + 1
			ranked.append({"rank": rank, "name": str(entry.name), "score": int(entry.score),
				"is_player": rank == player_rank and str(entry.name) == player_name and int(entry.score) == player_score})
		return {"ok": true, "entries": ranked, "player_rank": player_rank, "source": "local"}

class OnlineAdapter extends RefCounted:
	var host: Node
	var requests_started := 0

	func _init(owner_node: Node) -> void:
		host = owner_node

	func enabled() -> bool:
		return not ONLINE_ENDPOINT.is_empty() and not ONLINE_API_KEY.is_empty()

	func submit(player: String, score: int, callback: Callable) -> void:
		_request(ONLINE_ENDPOINT, HTTPClient.METHOD_POST,
			JSON.stringify({"name": player, "score": score, "game": "beanstalk_escape"}),
			func(ok: bool, _body: Variant): callback.call(ok))

	func fetch(limit: int, callback: Callable) -> void:
		var separator := "&" if "?" in ONLINE_ENDPOINT else "?"
		_request(ONLINE_ENDPOINT + separator + "limit=%d" % limit, HTTPClient.METHOD_GET, "",
			func(ok: bool, body: Variant):
				var entries: Array = []
				if not ok or body is not Dictionary or body.get("entries") is not Array:
					callback.call(false, entries)
					return
				for entry in body.entries:
					if entry is not Dictionary or not entry.has("name") or not entry.has("score") or not (entry.score is int or entry.score is float):
						callback.call(false, [])
						return
					entries.append({"name": str(entry.name).strip_edges().left(48), "score": maxi(int(entry.score), 0)})
				callback.call(true, entries)
		)

	func _request(url: String, method: HTTPClient.Method, body: String, callback: Callable) -> void:
		if not enabled():
			callback.call(false, null)
			return
		var request := HTTPRequest.new()
		request.timeout = 4.0
		request.body_size_limit = 262144
		host.add_child(request)
		request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray):
			request.queue_free()
			callback.call(result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, JSON.parse_string(bytes.get_string_from_utf8()))
		, CONNECT_ONE_SHOT)
		requests_started += 1
		var error := request.request(url, PackedStringArray([
			"Authorization: Bearer " + ONLINE_API_KEY, "Content-Type: application/json",
		]), method, body)
		if error != OK:
			request.queue_free()
			callback.call(false, null)

class PlatformAdapter extends RefCounted:
	var host: LeaderboardService
	var native_request: Dictionary = {}

	func _init(owner_node: Node) -> void:
		host = owner_node

	func _property(value: Variant, key: String) -> Variant:
		if value is Dictionary:
			return value.get(key)
		if value is Object and is_instance_valid(value):
			for item: Dictionary in value.get_property_list():
				if str(item.name) == key:
					return value.get(key)
		return null

	func _bridge() -> Node:
		if is_instance_valid(host.bridge_node):
			return host.bridge_node
		if OS.has_feature("web"):
			return host.get_node_or_null("/root/Bridge")
		return null

	func _board() -> Variant:
		var board: Variant = _property(_bridge(), "leaderboards")
		# Avoid invoking the JS-backed type getter before bridge initialization.
		if board is Object and is_instance_valid(board):
			for item: Dictionary in board.get_property_list():
				if str(item.name) == "_js_leaderboards" and board.get("_js_leaderboards") == null:
					return null
			return board
		return null

	func board_type() -> String:
		var kind := str(_property(_board(), "type"))
		return kind if kind in ["in_game", "native", "native_popup"] else "not_available"

	func _request() -> Dictionary:
		var timer := Timer.new()
		timer.one_shot = true
		timer.ignore_time_scale = true
		timer.process_mode = Node.PROCESS_MODE_ALWAYS
		host.add_child(timer)
		timer.start(3.0)
		return {"done": false, "timer": timer, "callbacks": []}

	func _finish(state: Dictionary) -> bool:
		if state.done:
			return false
		state.done = true
		state.timer.stop()
		state.timer.queue_free()
		# The SDK keeps these slots occupied forever when a promise never settles.
		# Release only callbacks owned by this request, never another caller's.
		for pending: Dictionary in state.callbacks:
			if _property(pending.board, pending.key) == pending.callback:
				pending.board.set(pending.key, null)
		state.callbacks.clear()
		return true

	func _call_board(state: Dictionary, board: Object, method: String, args: Array, callback: Callable) -> void:
		state.callbacks.append({"board": board, "key": "_" + method + "_callback", "callback": callback})
		board.callv(method, args + [callback])

	func fetch(limit: int, callback: Callable, submit_first: bool = false, score: int = 0) -> void:
		var fallback := host.local_adapter.fetch(limit)
		var board: Variant = _board()
		if board == null or not board.has_method("get_entries") or (submit_first and not board.has_method("set_score")):
			callback.call(fallback)
			return
		var state := _request()
		var player: Variant = _property(_bridge(), "player")
		# The player's JS-backed id getter has the same initialization guard.
		if player is Object:
			for item: Dictionary in player.get_property_list():
				if str(item.name) == "_js_player" and player.get("_js_player") == null:
					player = null
					break
		var identity := {"id": _property(player, "id"), "name": host.local_adapter.player_name,
			"score": host.local_adapter.player_score}
		state.timer.timeout.connect(func():
			if _finish(state):
				callback.call(fallback)
		, CONNECT_ONE_SHOT)
		if submit_first:
			_call_board(state, board, "set_score", [LEADERBOARD_ID, score], func(ok: bool):
				if state.done:
					return
				if not ok:
					if _finish(state):
						callback.call(fallback)
				else:
					# SDK clears the set-score slot after returning from this callback.
					_get_entries.call_deferred(state, board, limit, identity, fallback, callback)
			)
		else:
			_get_entries(state, board, limit, identity, fallback, callback)

	func _get_entries(state: Dictionary, board: Object, limit: int, identity: Dictionary, fallback: Dictionary, callback: Callable) -> void:
		if state.done:
			return
		if not is_instance_valid(board):
			if _finish(state):
				callback.call(fallback)
			return
		_call_board(state, board, "get_entries", [LEADERBOARD_ID], func(ok: bool, entries: Variant):
			if state.done:
				return
			var result := _ranked(entries, limit, identity) if ok else {}
			if _finish(state):
				callback.call(fallback if result.is_empty() else result)
		)

	func _ranked(entries: Variant, limit: int, identity: Dictionary) -> Dictionary:
		if entries is not Array or entries.is_empty():
			return {}
		var sorted: Array = []
		for entry: Variant in entries:
			if entry is not Dictionary or entry.get("name") is not String or str(entry.name).strip_edges().is_empty():
				return {}
			var score: Variant = entry.get("score")
			if not (score is int or score is float) or not is_finite(float(score)) or float(score) < 0:
				return {}
			sorted.append(entry)
		sorted.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.score) > int(b.score))
		var ranked: Array = []
		var player_rank := 0
		for entry: Dictionary in sorted.slice(0, limit):
			var rank := ranked.size() + 1
			var entry_id: Variant = entry.get("id")
			var has_ids := identity.id != null and not str(identity.id).is_empty() and entry_id != null and not str(entry_id).is_empty()
			var matches: bool = str(entry_id) == str(identity.id) if has_ids else (str(entry.name) == identity.name and int(entry.score) == identity.score)
			var is_player: bool = player_rank == 0 and matches
			if is_player:
				player_rank = rank
			ranked.append({"rank": rank, "name": str(entry.name), "score": int(entry.score), "is_player": is_player})
		return {"ok": true, "entries": ranked, "player_rank": player_rank, "source": "platform"}

	func submit_native(score: int) -> void:
		if not native_request.is_empty() and not native_request.done:
			return
		var board: Variant = _board()
		if board == null or not board.has_method("show_native_popup"):
			return
		var state := _request()
		native_request = state
		state.timer.timeout.connect(func(): _finish(state), CONNECT_ONE_SHOT)
		if board.has_method("set_score"):
			_call_board(state, board, "set_score", [LEADERBOARD_ID, score], func(_ok: bool):
				_show_popup.call_deferred(state, board)
			)
		else:
			_show_popup.call_deferred(state, board)

	func _show_popup(state: Dictionary, board: Object) -> void:
		if state.done:
			return
		if not is_instance_valid(board):
			_finish(state)
			return
		_call_board(state, board, "show_native_popup", [LEADERBOARD_ID], func(_ok: bool): _finish(state))
