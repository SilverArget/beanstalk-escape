extends Node2D

const STALK_TEXTURE := preload("res://assets/art/world/v2/stalk_tile.png")
# Share the exact surface through the narrowing Stage 3 join.
const BRANCH_DETAILS_TEXTURE := preload("res://assets/art/world/v2/leaves_atlas.png")
const FOLIAGE_TEXTURE := BRANCH_DETAILS_TEXTURE
const COLLAR_TEXTURE := preload("res://assets/art/world/v2/fork_collar.png")
const SKY_TOP := Color("43b8ef")
const SKY_BOTTOM := Color("86dafa")
const MODULE_HEIGHT := 256.0
const MAX_TEXTURE_ELEMENT := 54.0
const GRIP_DETAIL_SIZE := 12.0
const MAX_LEAF_SIZE := 72.0
const VISUAL_OUTLINE_WIDTH := 4.0
const STEM_GROWTH_SPACING := 90.0
const BRANCH_GROWTH_SPACING := 220.0
const GROWTH_OVERLAP := 8.0
const STEM_GROWTH_CELLS := [0, 3, 1, 2, 4, 0]
const SURFACE_TILE_HEIGHT := 256.0
const BRANCH_DETAIL_GRID := Vector2(3.0, 2.0)
const FOLIAGE_CELL := Vector2(256.0, 256.0)
const SURFACE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform float sunset_mix : hint_range(0.0, 1.0) = 0.0;
varying float edge_alpha;
varying float surface_face;
void vertex() {
    edge_alpha = COLOR.a;
    // Only ribbon vertices carry this tag; foliage and collars keep their paint.
    surface_face = 1.0 - COLOR.r;
}
void fragment() {
    // Out-of-range U is reserved for the fixed-pixel mesh contour.
    vec4 pigment = (UV.x < 0.0 || UV.x > 1.0)
        ? vec4(0.062745, 0.141176, 0.058824, 1.0)
        : texture(TEXTURE, UV);
    if (surface_face > 0.5 && UV.x >= 0.0 && UV.x <= 1.0) {
        float rim = 1.0 - smoothstep(0.10, 0.15, UV.x);
        float shadow = smoothstep(0.80, 0.88, UV.x);
        vec3 rim_color = mix(vec3(0.72, 0.96, 0.15), vec3(0.91, 0.92, 0.22), sunset_mix);
        pigment.rgb = mix(pigment.rgb, rim_color, rim * 0.72);
        pigment.rgb = mix(pigment.rgb, vec3(0.025, 0.15, 0.035), shadow * 0.70);
    }
    COLOR = vec4(pigment.rgb, pigment.a * edge_alpha);
}
"""
const BRANCH_NODE_SPACING := [173.0, 211.0, 187.0]
const STAGE_3_ENTRY_HEIGHT := 350.0
const SIDE_VINE_MIN_ENTRY_DEPTH := 360.0
const SIDE_VINE_ENTRY_DEPTH_PER_X := 1.9
const SIDE_VINE_OFFSCREEN_X := 560.0
const SURFACE_CACHE_SCROLL_PX := 192.0
const SURFACE_CACHE_MARGIN_PX := 384.0
const SKY_VISUAL := preload("res://scripts/world_sky_visual.gd")

@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager

var branch_graph := BranchGraph.new()
var redraw_count := 0
var branch_point_count := 0
var qa_storm_background := false
var qa_support_mask := false
var qa_support_mask_include_outline := false
var qa_sky_only := false
var cached_camera_top := INF
var sky_visual: Node2D
var surface_material: ShaderMaterial
var draw_mesh_cache: Array[ArrayMesh] = []
var detail_vertices := PackedVector2Array()
var detail_uvs := PackedVector2Array()
var detail_indices := PackedInt32Array()

func _ready() -> void:
	var surface_shader := Shader.new()
	surface_shader.code = SURFACE_SHADER
	surface_material = ShaderMaterial.new()
	surface_material.shader = surface_shader
	material = surface_material
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sky_visual = SKY_VISUAL.new()
	sky_visual.name = "Sky"
	sky_visual.z_index = -100
	sky_visual.setup(player, stages)
	add_child(sky_visual)
	cached_camera_top = _camera_top()
	queue_redraw()
	set_process(true)

func _process(_delta: float) -> void:
	if player != null and stages != null:
		var sunset: float = sky_visual.sunset_mix_at(stages.stage_for_y(player.global_position.y), stages.progress_in_stage(player.global_position.y))
		surface_material.set_shader_parameter("sunset_mix", sunset)
	var current_camera_top := _camera_top()
	if absf(current_camera_top - cached_camera_top) >= SURFACE_CACHE_SCROLL_PX:
		cached_camera_top = current_camera_top
		queue_redraw()

func _camera_top() -> float:
	var result := player.global_position.y - ScaleLock.CHARACTER_REFERENCE_Y if player != null else -270.0
	if player != null:
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			result = camera.get_screen_center_position().y - get_viewport_rect().size.y * 0.5
	return result

func _draw() -> void:
	redraw_count += 1
	# Canvas draw commands retain mesh RIDs, not the local Resource references.
	# Keep each rebuilt mesh alive until the next surface-cache redraw.
	draw_mesh_cache.clear()
	detail_vertices.clear()
	detail_uvs.clear()
	detail_indices.clear()
	branch_point_count = 0
	var camera_top := cached_camera_top if not is_inf(cached_camera_top) else _camera_top()
	if qa_sky_only:
		return
	_draw_trunk(camera_top)
	if not qa_support_mask:
		_draw_trunk_features(camera_top)
	_draw_stage_branches(camera_top)
	_flush_branch_details()

func _draw_sky(_camera_top: float) -> void:
	if sky_visual != null:
		sky_visual.queue_redraw()

func _draw_far_vines(_camera_top: float) -> void:
	if sky_visual != null:
		sky_visual.queue_redraw()

func _draw_foreground_foliage(camera_top: float) -> void:
	pass

func _draw_trunk(camera_top: float) -> void:
	# World-Y phase continues through the narrowing middle vine into Stage 3.
	var transition_top_y := _stage_3_bottom_y() - STAGE_3_ENTRY_HEIGHT
	var visible_top := maxf(transition_top_y, camera_top - 64.0 - SURFACE_CACHE_MARGIN_PX)
	var visible_bottom := minf(740.0, camera_top + 620.0 + SURFACE_CACHE_MARGIN_PX)
	if visible_bottom <= visible_top:
		return
	var centers := PackedVector2Array()
	var y := visible_bottom
	while y > visible_top:
		centers.append(Vector2(_main_stem_center_x(y), y))
		y = maxf((ceil(y / 12.0) - 1.0) * 12.0, visible_top)
	if centers.is_empty() or centers[centers.size() - 1].y != visible_top:
		centers.append(Vector2(_main_stem_center_x(visible_top), visible_top))
	_draw_textured_ribbon(centers, _trunk_widths(centers))
	if not qa_support_mask:
		_draw_stem_growth(visible_top, visible_bottom)

func _trunk_widths(points: PackedVector2Array) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	for point in points:
		var width := _main_stem_width(point.y)
		# Match the branch's actual painted width at the join, without changing
		# the authored main-stem width or any support calculation.
		var join_y := _stage_3_bottom_y() - STAGE_3_ENTRY_HEIGHT
		var join_mix := 1.0 - smoothstep(join_y, join_y + 96.0, point.y)
		width += (_branch_painted_width(1, point.y) - ScaleLock.BRANCH_WIDTH) * join_mix
		widths.append(width)
	return widths

func _draw_stem_growth(top_y: float, bottom_y: float) -> void:
	var spacing := STEM_GROWTH_SPACING
	var node := int(floor(top_y / spacing)) - 1
	while float(node) * spacing <= bottom_y:
		var y := float(node) * spacing
		if y >= top_y:
			var side := -1.0 if posmod(node, 2) == 0 else 1.0
			var width := _trunk_widths(PackedVector2Array([Vector2(0.0, y)]))[0]
			var root := Vector2(_main_stem_center_x(y) + side * (width * 0.5 - GROWTH_OVERLAP), y)
			_draw_attached_growth(STEM_GROWTH_CELLS[posmod(node, STEM_GROWTH_CELLS.size())], root, side, 72.0)
		node += 1

func _main_stem_center_x(world_y: float) -> float:
	var stage_3_bottom := _stage_3_bottom_y()
	if world_y >= stage_3_bottom:
		return _trunk_center_x(world_y)
	var t := clampf((stage_3_bottom - world_y) / STAGE_3_ENTRY_HEIGHT, 0.0, 1.0)
	var smooth := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	return lerpf(_trunk_center_x(stage_3_bottom), _branch_visual_x(1, stage_3_bottom - STAGE_3_ENTRY_HEIGHT), smooth)

func _main_stem_width(world_y: float) -> float:
	var stage_3_bottom := _stage_3_bottom_y()
	if world_y >= stage_3_bottom:
		return _trunk_half_width(world_y) * 2.0
	var t := clampf((stage_3_bottom - world_y) / STAGE_3_ENTRY_HEIGHT, 0.0, 1.0)
	var smooth := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	return lerpf(_trunk_half_width(stage_3_bottom) * 2.0, ScaleLock.BRANCH_WIDTH, smooth)

func _trunk_center_x(world_y: float) -> float:
	return sin(world_y * TAU / 560.0) * 10.0 + sin(world_y * TAU / 910.0 + 0.7) * 4.0

func _trunk_half_width(world_y: float) -> float:
	return 90.0 + sin(world_y * TAU / 470.0) * 7.0 + sin(world_y * TAU / 150.0) * 3.0

func _draw_stage_branches(camera_top: float) -> void:
	var visible_bottom := camera_top + 556.0 + 160.0 + SURFACE_CACHE_MARGIN_PX
	var visible_top := camera_top - 160.0 - SURFACE_CACHE_MARGIN_PX
	for route in 3:
		# Union touching support intervals before clipping or building geometry.
		# A stage/support boundary is not a botanical endpoint.
		var spans: Array[Vector3] = []
		for stage_number in range(3, Balance.STAGE_COUNT + 1):
			var bottom := stages.stage_bottom_y(stage_number)
			var length := stages.stage_length(stage_number)
			for segment: Array in stages.support_segments(stage_number, route):
				spans.append(Vector3(bottom - float(segment[0]) * length, bottom - float(segment[1]) * length, stage_number))
		spans.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x > b.x)
		var joined: Array[Vector3] = []
		for span in spans:
			if not joined.is_empty() and span.x >= joined[joined.size() - 1].y - 0.01:
				joined[joined.size() - 1].y = minf(joined[joined.size() - 1].y, span.y)
			else:
				joined.append(span)
		for span in joined:
			var start_y := minf(span.x, visible_bottom)
			var end_y := maxf(span.y, visible_top)
			if start_y <= end_y:
				continue
			var stage_number := int(span.z)
			var bottom := stages.stage_bottom_y(stage_number)
			var length := stages.stage_length(stage_number)
			_draw_branch_segment(stage_number, route, (bottom - start_y) / length, (bottom - end_y) / length, is_equal_approx(start_y, span.x), is_equal_approx(end_y, span.y))

func _draw_branch_segment(stage_number: int, route: int, start_progress: float, end_progress: float, show_start_tip := true, show_end_tip := true) -> void:
	var stage_bottom := stages.stage_bottom_y(stage_number)
	var stage_length := stages.stage_length(stage_number)
	# A real interval endpoint remains an endpoint even at progress zero.
	# Cache cuts are outside the view and never get a botanical cap.
	var cap_start := show_start_tip
	if stage_number == 3 and route == 1 and start_progress <= STAGE_3_ENTRY_HEIGHT / stage_length:
		start_progress = STAGE_3_ENTRY_HEIGHT / stage_length
		cap_start = false
	if end_progress <= start_progress:
		return
	var start_y := stage_bottom - start_progress * stage_length
	var end_y := stage_bottom - end_progress * stage_length
	var points := PackedVector2Array()
	if stage_number == 3 and route != 1 and start_progress <= 0.0:
		points = _side_vine_entry_points(route, stage_bottom)
		cap_start = false
	elif cap_start and not qa_support_mask:
		points = _restart_vine_entry_points(route, start_y)
	else:
		points.append(Vector2(_branch_visual_x(route, start_y), start_y))
	var cursor_y := start_y
	while cursor_y > end_y:
		cursor_y = maxf((ceilf(cursor_y / 12.0) - 1.0) * 12.0, end_y)
		points.append(Vector2(_branch_visual_x(route, cursor_y), cursor_y))
	if points.size() < 2:
		return
	branch_point_count += points.size()
	_draw_branch_ribbon(points, route, cap_start, show_end_tip)
	_draw_branch_details(stage_number, route, start_y, end_y)

func _restart_vine_entry_points(route: int, start_y: float) -> PackedVector2Array:
	# A returning support is a separate vine: outer routes curl in from beyond
	# the screen edge, while the middle route emerges from behind the right vine.
	# This is decorative lead-in only and never changes support/collision data.
	var target_x := _branch_visual_x(route, start_y)
	var source_x := SIDE_VINE_OFFSCREEN_X
	if route == 0:
		source_x = -SIDE_VINE_OFFSCREEN_X
	elif route == 1:
		source_x = _branch_visual_x(2, start_y)
	return _smooth_vertical_entry_points(source_x, target_x, start_y)

func _side_vine_entry_points(route: int, stage_bottom: float) -> PackedVector2Array:
	var side := -1.0 if route == 0 else 1.0
	return _smooth_vertical_entry_points(side * SIDE_VINE_OFFSCREEN_X, _branch_visual_x(route, stage_bottom), stage_bottom)

func _smooth_vertical_entry_points(source_x: float, target_x: float, target_y: float) -> PackedVector2Array:
	# Cubic Hermite path with vertical tangents at both ends. Scaling the rise
	# with horizontal travel keeps the steepest tangent under 40 degrees and
	# the tightest radius above roughly 120 px, without a horizontal shelf.
	var points := PackedVector2Array()
	var travel_x := absf(target_x - source_x)
	var depth := maxf(SIDE_VINE_MIN_ENTRY_DEPTH, travel_x * SIDE_VINE_ENTRY_DEPTH_PER_X)
	var steps := maxi(30, int(ceil(depth / 12.0)))
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var smooth := t * t * (3.0 - 2.0 * t)
		points.append(Vector2(lerpf(source_x, target_x, smooth), lerpf(target_y + depth, target_y, t)))
	return points

func _branch_visual_x(route: int, world_y: float) -> float:
	return float(Balance.ROUTE_X[route]) + ScaleLock.vine_visual_offset(route, world_y)

func _draw_branch_ribbon(points: PackedVector2Array, route: int, cap_start: bool, cap_end: bool) -> void:
	var widths := PackedFloat32Array()
	for point in points:
		widths.append(_branch_painted_width(route, point.y))
	# Taper the retained ribbon itself. Painting a taper over a full-width ribbon
	# leaves the old square silhouette visible underneath.
	if cap_start:
		_taper_branch_endpoint(points, widths, true)
	if cap_end:
		_taper_branch_endpoint(points, widths, false)
	_draw_textured_ribbon(points, widths)
	if cap_start and not qa_support_mask:
		_draw_branch_tip_detail(points[0], (points[0] - points[1]).normalized(), route, true)
	if cap_end and not qa_support_mask:
		_draw_branch_tip_detail(points[points.size() - 1], (points[points.size() - 1] - points[points.size() - 2]).normalized(), route, false)

func _branch_painted_width(route: int, world_y: float) -> float:
	var spacing: float = BRANCH_NODE_SPACING[route]
	var node_phase := fposmod(-world_y + float(route) * 47.0, spacing)
	var node_distance := minf(node_phase, spacing - node_phase)
	var node_weight := 0.5 + 0.5 * cos(clampf(node_distance / 30.0, 0.0, 1.0) * PI)
	var breathing := sin((-world_y + float(route) * 67.0) * TAU / 390.0) * 4.5
	return clampf(45.0 + breathing + node_weight * 5.5, 36.0, 56.0)

func _taper_branch_endpoint(points: PackedVector2Array, widths: PackedFloat32Array, at_start: bool) -> void:
	var endpoint_index := 0 if at_start else points.size() - 1
	var distance := 0.0
	for offset in range(mini(6, points.size())):
		var index := offset if at_start else points.size() - 1 - offset
		if offset > 0:
			var previous := index - 1 if at_start else index + 1
			distance += points[index].distance_to(points[previous])
		var t := clampf(distance / 42.0, 0.0, 1.0)
		var smooth := t * t * (3.0 - 2.0 * t)
		widths[index] = lerpf(2.0, widths[index], smooth)
	widths[endpoint_index] = 2.0

func _draw_branch_tip_detail(_base: Vector2, _direction: Vector2, _route: int, _is_restart: bool) -> void:
	# The tapered ribbon owns its tip; no floating curl in the jump corridor.
	pass

func _draw_branch_details(_stage_number: int, route: int, start_y: float, end_y: float) -> void:
	if qa_support_mask:
		return
	# Absolute phase/noise: clipping or a new stage never moves a node.
	var spacing := BRANCH_GROWTH_SPACING
	var phase := float(route) * 71.0
	var node := int(ceil((end_y - phase) / spacing))
	while float(node) * spacing + phase < start_y:
		var y := float(node) * spacing + phase
		var outside := -1.0 if route == 0 else 1.0
		if route == 1:
			outside = -1.0 if posmod(node, 2) == 0 else 1.0
		var root := Vector2(_branch_visual_x(route, y) + outside * (_branch_painted_width(route, y) * 0.5 - GROWTH_OVERLAP), y)
		_draw_attached_growth(posmod(node + route, 5), root, outside, 72.0)
		node += 1

func _draw_attached_growth(cell: int, root: Vector2, side: float, size: float) -> void:
	# Atlas roots are at left-center; mirror for the left side of a support.
	var extent := minf(size, MAX_LEAF_SIZE)
	var center := root + Vector2(side * extent * 0.5, 0.0)
	_draw_branch_detail_sprite(cell, center, Vector2.ONE * extent, 0.0, side < 0.0)

func _detail_noise(stage_number: int, route: int, node_index: int, channel: int) -> float:
	var seed := float(stage_number * 97 + route * 193 + node_index * 53 + channel * 29)
	return fposmod(sin(seed * 0.731) * 43758.5453, 1.0)

func _draw_branch_detail_sprite(cell: int, center: Vector2, size: Vector2, rotation: float, flip_x: bool) -> void:
	var column := cell % int(BRANCH_DETAIL_GRID.x)
	var row := floori(float(cell) / BRANCH_DETAIL_GRID.x)
	var uv_min := Vector2(float(column), float(row)) / BRANCH_DETAIL_GRID
	var uv_max := Vector2(float(column + 1), float(row + 1)) / BRANCH_DETAIL_GRID
	var basis := Transform2D(rotation, center)
	var base := detail_vertices.size()
	detail_vertices.append(basis * Vector2(-size.x * 0.5, -size.y * 0.5))
	detail_vertices.append(basis * Vector2(size.x * 0.5, -size.y * 0.5))
	detail_vertices.append(basis * Vector2(size.x * 0.5, size.y * 0.5))
	detail_vertices.append(basis * Vector2(-size.x * 0.5, size.y * 0.5))
	var left_u := uv_max.x if flip_x else uv_min.x
	var right_u := uv_min.x if flip_x else uv_max.x
	detail_uvs.append(Vector2(left_u, uv_min.y))
	detail_uvs.append(Vector2(right_u, uv_min.y))
	detail_uvs.append(Vector2(right_u, uv_max.y))
	detail_uvs.append(Vector2(left_u, uv_max.y))
	detail_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

func _flush_branch_details() -> void:
	if detail_vertices.is_empty():
		return
	var mesh := _build_ribbon_mesh(detail_vertices, detail_uvs, detail_indices)
	draw_mesh(mesh, BRANCH_DETAILS_TEXTURE)

func _draw_textured_ribbon(points: PackedVector2Array, widths: PackedFloat32Array) -> void:
	if points.size() < 2:
		return
	if qa_support_mask:
		var mask_width := VISUAL_OUTLINE_WIDTH if qa_support_mask_include_outline else 0.0
		var mask := _ribbon_geometry(points, widths, mask_width)
		var vertices := PackedVector2Array()
		var indices := PackedInt32Array()
		for index in points.size():
			vertices.append(mask.left[index])
			vertices.append(mask.right[index])
			if index > 0:
				var base := (index - 1) * 2
				indices.append_array(PackedInt32Array([base, base + 1, base + 3, base, base + 3, base + 2]))
		draw_mesh(_build_ribbon_mesh(vertices, PackedVector2Array(), indices), null, Transform2D.IDENTITY, Color.WHITE)
		return
	var strip := _ribbon_geometry(points, widths, 0.0)
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# One mesh includes the face and constant-pixel contours. Stage/cache
	# boundaries have no end caps; both sides of the Stage 3 join share UVs.
	for row in points.size():
		var left: Vector2 = strip.left[row]
		var right: Vector2 = strip.right[row]
		var normal := (right - left).normalized()
		var edge := VISUAL_OUTLINE_WIDTH
		var positions := [left - normal * (edge + 0.75), left - normal * edge, left, left, right, right, right + normal * edge, right + normal * (edge + 0.75)]
		var across := [-1.0, -1.0, -0.001, 0.0, 1.0, 1.001, 2.0, 2.0]
		for column in 8:
			vertices.append(positions[column])
			colors.append(Color(0.0, 1.0, 1.0, 0.0 if column == 0 or column == 7 else 1.0))
			uvs.append(Vector2(across[column], points[row].y / SURFACE_TILE_HEIGHT))
		if row > 0:
			for column in 7:
				var base := (row - 1) * 8 + column
				indices.append_array(PackedInt32Array([base, base + 1, base + 9, base, base + 9, base + 8]))
	# Close only true tapered tips, in the same mesh, never a stem/branch join.
	for row in [0, points.size() - 1]:
		if widths[row] > 2.01:
			continue
		var neighbor := 1 if row == 0 else points.size() - 2
		var direction := (points[row] - points[neighbor]).normalized()
		var normal: Vector2 = (strip.right[row] - strip.left[row]).normalized()
		var base := vertices.size()
		vertices.append(strip.left[row] - normal * VISUAL_OUTLINE_WIDTH)
		vertices.append(strip.right[row] + normal * VISUAL_OUTLINE_WIDTH)
		vertices.append(points[row] + direction * VISUAL_OUTLINE_WIDTH)
		for column in 3:
			uvs.append(Vector2(-1.0, 0.0))
			colors.append(Color.WHITE)
		indices.append_array(PackedInt32Array([base, base + 1, base + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh_cache.append(mesh)
	draw_mesh(mesh, STALK_TEXTURE)

func _build_ribbon_mesh(vertices: PackedVector2Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh_cache.append(mesh)
	return mesh

func _ribbon_geometry(points: PackedVector2Array, widths: PackedFloat32Array, extra_width: float) -> Dictionary:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var join_y := _stage_3_bottom_y() - STAGE_3_ENTRY_HEIGHT
	for index in points.size():
		var tangent: Vector2
		if index == 0:
			tangent = points[1] - points[0]
		elif index == points.size() - 1:
			tangent = points[index] - points[index - 1]
		else:
			tangent = points[index + 1] - points[index - 1]
		tangent = tangent.normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		# The authored transition has a vertical end tangent. Share its exact
		# cross-section on both meshes rather than leaving two angled end caps.
		if is_equal_approx(points[index].y, join_y) and is_equal_approx(points[index].x, _branch_visual_x(1, join_y)):
			normal = Vector2.RIGHT
		var half_width := widths[index] * 0.5 + extra_width
		left.append(points[index] - normal * half_width)
		right.append(points[index] + normal * half_width)
	return {"left": left, "right": right}

func _draw_trunk_features(camera_top: float) -> void:
	var y := _stage_3_bottom_y() - STAGE_3_ENTRY_HEIGHT * 0.5
	if y < camera_top - SURFACE_CACHE_MARGIN_PX or y > camera_top + 620.0 + SURFACE_CACHE_MARGIN_PX:
		return
	# Both ends of the sleeve overlap the already-painted narrowing stem.
	var size := Vector2(_main_stem_width(y) + 4.0, 68.0)
	draw_texture_rect(COLLAR_TEXTURE, Rect2(Vector2(_main_stem_center_x(y), y) - size * 0.5, size), false)

func _draw_foliage_sprite(cell: int, center: Vector2, size: Vector2, flip_x := false, modulate := Color.WHITE) -> void:
	if qa_support_mask:
		return
	var column := cell % 3
	var row := floori(float(cell) / 3.0)
	var source := Rect2(Vector2(float(column), float(row)) * FOLIAGE_CELL, FOLIAGE_CELL)
	var destination_size := Vector2(minf(size.x, MAX_LEAF_SIZE), minf(size.y, MAX_LEAF_SIZE))
	var destination := Rect2(center - destination_size * 0.5, destination_size)
	if flip_x:
		destination.position.x += destination.size.x
		destination.size.x *= -1.0
	draw_texture_rect_region(FOLIAGE_TEXTURE, destination, source, modulate)

func sky_color_at(normalized_y: float) -> Color:
	return SKY_TOP.lerp(SKY_BOTTOM, clampf(normalized_y, 0.0, 1.0))

func qa_branch_visual_deviation(route: int, world_y: float) -> float:
	return absf(_branch_visual_x(route, world_y) - float(Balance.ROUTE_X[route]))

func qa_point_inside_support(world_point: Vector2) -> bool:
	var stage_number := stages.stage_for_y(world_point.y)
	if stage_number <= 2:
		return absf(world_point.x - _trunk_center_x(world_point.y)) <= _trunk_half_width(world_point.y)
	var stage_bottom := stages.stage_bottom_y(stage_number)
	var stage_length := stages.stage_length(stage_number)
	var progress := (stage_bottom - world_point.y) / stage_length
	if stage_number == 3 and progress * stage_length <= STAGE_3_ENTRY_HEIGHT:
		if absf(world_point.x - _main_stem_center_x(world_point.y)) <= _main_stem_width(world_point.y) * 0.5:
			return true
	for route in 3:
		for segment: Array in stages.support_segments(stage_number, route):
			if progress >= float(segment[0]) and progress <= float(segment[1]) and absf(world_point.x - _branch_visual_x(route, world_point.y)) <= ScaleLock.BRANCH_WIDTH * 0.5:
				return true
	return false

func qa_visual_contract() -> Dictionary:
	return {
		"module_height_px": MODULE_HEIGHT,
		"trunk_nominal_width_px": ScaleLock.TRUNK_WIDTH,
		"trunk_render_width_range_px": [160.0, 200.0],
		"branch_width_px": [36.0, 56.0],
		"branch_centers_world_x": Balance.ROUTE_X.duplicate(),
		"texture_repeat_px": SURFACE_TILE_HEIGHT,
		"grip_detail_px": GRIP_DETAIL_SIZE,
		"max_leaf_px": MAX_LEAF_SIZE,
		"outline_px": VISUAL_OUTLINE_WIDTH,
		"surface_texture": "res://assets/art/world/v2/stalk_tile.png",
		"branch_surface_texture": "res://assets/art/world/v2/stalk_tile.png",
		"shoot_meshes_per_ribbon": 1,
		"branch_detail_atlas": "res://assets/art/world/v2/leaves_atlas.png",
		"branch_node_spacing_px": [BRANCH_GROWTH_SPACING, BRANCH_GROWTH_SPACING, BRANCH_GROWTH_SPACING],
		"stem_growth_spacing_px": STEM_GROWTH_SPACING,
		"growth_overlap_px": GROWTH_OVERLAP,
		"stage_3_layout": "continuous_middle_with_separate_side_vines",
		"split_union_count": 0,
		"transfer_bridge_count": 0,
		"side_vine_entry_world_y": _stage_3_bottom_y() + maxf(SIDE_VINE_MIN_ENTRY_DEPTH, absf(SIDE_VINE_OFFSCREEN_X - float(Balance.ROUTE_X[2])) * SIDE_VINE_ENTRY_DEPTH_PER_X),
		"side_vine_entry_world_x": [-SIDE_VINE_OFFSCREEN_X, SIDE_VINE_OFFSCREEN_X],
		"foliage_atlas": "res://assets/art/world/v2/leaves_atlas.png",
		"procedural_circle_cloud_count": 0,
		"flat_polygon_leaf_count": 0,
		"airborne_transfer_foliage_count": 0,
		"gameplay_branch_tip_foliage_count": 0,
		"atmosphere_layers": ["v2_day_sunset_plates", "far_stalks_a_0.06", "far_stalks_b_0.14", "imagegen_foreground_foliage"],
	}

func _stage_3_bottom_y() -> float:
	if stages != null:
		return stages.stage_bottom_y(3)
	return -float(StageDatabase.stage(3).start_height)
