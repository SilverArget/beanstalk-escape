class_name BranchGraph
extends RefCounted

const ROUTE_COUNT := 3

func has_support(stages: StageManager, branch_id: int, world_y: float) -> bool:
	if stages == null or branch_id < 0 or branch_id >= ROUTE_COUNT:
		return false
	return stages.has_route_support_at(stages.stage_for_y(world_y), branch_id, stages.progress_in_stage(world_y))

func can_transfer(stages: StageManager, from_branch: int, to_branch: int, world_y: float) -> bool:
	if absi(to_branch - from_branch) != 1:
		return false
	var stage := stages.stage_for_y(world_y)
	var progress := stages.progress_in_stage(world_y)
	return stages.transfer_window_open(stage, progress) and has_support(stages, from_branch, world_y) and stages.can_enter_route_at(stage, to_branch, progress)

func support_point(stages: StageManager, branch_id: int, world_y: float, support_offset := 0.0) -> Vector2:
	return Vector2(stages.branch_x_at(branch_id, world_y) + clampf(support_offset, -12.0, 12.0), world_y)

func transfer_point(stages: StageManager, from_branch: int, to_branch: int, world_y: float, progress: float, lateral_offset := 0.0) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var start := support_point(stages, from_branch, world_y)
	var finish := support_point(stages, to_branch, world_y)
	var point := start.lerp(finish, eased)
	point.y -= Balance.BRANCH_ARC_HEIGHT * sin(t * PI)
	point.x += clampf(lateral_offset, -8.0, 8.0) * sin(t * PI)
	return point

func recovery_target(stages: StageManager, from_branch: int, position: Vector2) -> Dictionary:
	var stage_number := stages.stage_for_y(position.y)
	for target in [from_branch - 1, from_branch + 1]:
		if target < 0 or target >= ROUTE_COUNT:
			continue
		if not stages.has_recovery_edge(stage_number, from_branch, target) or not stages.can_enter_route_at(stage_number, target, stages.progress_in_stage(position.y)):
			continue
		var point := support_point(stages, target, position.y)
		if absf(point.x - position.x) <= 36.0:
			return {"branch_id": target, "point": point}
	return {}
