class_name ScaleLock
extends RefCounted

const REFERENCE_SIZE := Vector2i(960, 540)
const GAMEPLAY_ZOOM := 1.0

const CHARACTER_HEIGHT := 108.0
const CHARACTER_WIDTH := 44.0
const COLLIDER_HEIGHT := 86.0
const COLLIDER_WIDTH := 30.0
const TRUNK_WIDTH := 180.0
const BRANCH_WIDTH := 44.0
const BRANCH_CENTER_GAP := 150.0
const TEXTURE_ELEMENT_MAX := 48.0
const GRIP_DETAIL := 12.0
const GAMEPLAY_LEAF_MAX := 120.0
const OUTLINE_WIDTH := 3.0
const CHARACTER_REFERENCE_Y := 390.0
const HUD_FONT_HEIGHT := 20.0
const SURFACE_EDGE_INSET := 68.0
const SUPPORTED_BRANCH_OFFSET := 0.0
const VISIBLE_SEAMS := 0

static func measurements() -> Dictionary:
	return {
		"character_height": CHARACTER_HEIGHT,
		"character_width": CHARACTER_WIDTH,
		"collider_height": COLLIDER_HEIGHT,
		"collider_width": COLLIDER_WIDTH,
		"trunk_width": TRUNK_WIDTH,
		"branch_width": BRANCH_WIDTH,
		"branch_center_gap": BRANCH_CENTER_GAP,
		"texture_element_max": TEXTURE_ELEMENT_MAX,
		"grip_detail": GRIP_DETAIL,
		"gameplay_leaf_max": GAMEPLAY_LEAF_MAX,
		"outline_width": OUTLINE_WIDTH,
		"gameplay_zoom": GAMEPLAY_ZOOM,
		"character_reference_y": CHARACTER_REFERENCE_Y,
		"hud_font_height": HUD_FONT_HEIGHT,
		"surface_edge_inset": SURFACE_EDGE_INSET,
		"supported_branch_offset": SUPPORTED_BRANCH_OFFSET,
		"visible_seams": VISIBLE_SEAMS,
	}
