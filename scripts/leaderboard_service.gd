class_name LeaderboardService
extends Node

const ONLINE_ENDPOINT := ""
const ONLINE_API_KEY := ""
# Optional existing platform board ID; never creates a board.
const PLATFORM_LEADERBOARD_ID := ""

var local_adapter: LocalAdapter
var online_adapter: OnlineAdapter
var platform_adapter: PlatformAdapter

func configure(manager: SaveManager) -> void:
	local_adapter = LocalAdapter.new(manager)
	online_adapter = OnlineAdapter.new(self)
	platform_adapter = PlatformAdapter.new(self)

func submit_score(player: String, score: int, callback: Callable) -> void:
	player = player.strip_edges().left(48)
	score = maxi(score, 0)
	local_adapter.submit(player, score)
	platform_adapter.submit(score)
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
	var host: Node

	func _init(owner_node: Node) -> void:
		host = owner_node

	func submit(score: int) -> void:
		if PLATFORM_LEADERBOARD_ID.is_empty() or not OS.has_feature("web"):
			return
		var bridge := host.get_node_or_null("/root/Bridge")
		if bridge == null:
			return
		var board: Variant = bridge.get("leaderboards")
		if board != null and str(board.get("type")) != "not_available" and board.has_method("set_score"):
			board.call("set_score", PLATFORM_LEADERBOARD_ID, score)
