class_name Balance
extends RefCounted

const PLAYER_VERTICAL_SPEED := 125.0
const PLAYER_HORIZONTAL_SPEED := 680.0
const PLAYER_HORIZONTAL_ACCELERATION := 6000.0
const BRANCH_TRANSITION_SECONDS := 0.40
const BRANCH_COMMAND_BUFFER_SECONDS := 0.05
const BRANCH_ARC_HEIGHT := 64.0
const TRUNK_HALF_WIDTH := 67.0
const SPIDER_SPEED_RATIO := 0.94
const SPIDER_FOLLOW_DELAY_SECONDS := 0.08
const SPIDER_FOLLOW_SECONDS := 0.32
const SPIDER_TRUNK_FOLLOW_SPEED := 900.0
const SPIDER_RAMP_FULL_DISTANCE := 288.0
const START_DISTANCE := 240.0
const CATCH_DISTANCE := 28.0
const DANGER_SECONDS := 3.0
const DANGER_GAP := 56.0
const DANGER_APPROACH_SECONDS := 0.6
const DANGER_RETREAT_SECONDS := 1.5
const GAUGE_MAX_DISTANCE := 360.0
const SPIDER_RAMP_SPAN := 108.0
const SPIDER_CATCHUP_ON_GAP := 420.0
const SPIDER_CATCHUP_OFF_GAP := 365.0
const SPIDER_CATCHUP_BLEND_SECONDS := 0.50
const SPIDER_CATCHUP_ORIGIN := 360.0
const SPIDER_CATCHUP_SPAN := 180.0
const SPIDER_PRESSURE_BANDS := [
	{"from": 1, "to": 14, "g_lo": 240.0, "pressure": 0.0},
	{"from": 15, "to": 19, "g_lo": 252.0, "pressure": 4.0},
	{"from": 20, "to": 24, "g_lo": 264.0, "pressure": 12.0},
	{"from": 25, "to": 28, "g_lo": 264.0, "pressure": 12.0},
	{"from": 29, "to": 29, "g_lo": 264.0, "pressure": 12.0},
	{"from": 30, "to": 30, "g_lo": 264.0, "pressure": 12.0},
]
const ROUTE_X := [-150.0, 0.0, 150.0]
## Legacy fallback only; runtime stage durations come from StageDatabase lengths.
const STAGE_DURATION_SECONDS := 22.4
const STAGE_COUNT := 240
const ENDLESS_SPEED_RAMP_SECONDS := 180.0
const ENDLESS_MAX_SPEED_SCALE := 2.0
const DIFFICULTY_STEP_SECONDS := 20.0
const DIFFICULTY_MAX_TIER := 3
## Legacy fallback only; runtime geometry comes from each stage's length.
const STAGE_HEIGHT := 2800.0
const PATTERN_SEED := 20260923
const BEAN_WARNING_SECONDS := 1.60
const BEAN_KNOCKBACK_SECONDS := 0.36
const BEAN_STUN_SECONDS := 0.18
const BEAN_KNOCKBACK_SPEED := 180.0
const BEAN_FALL_SPEED := 220.0
const BEAN_SPAWN_LEAD_PX := 360.0
const BEAN_HIT_RADIUS := 30.0
const SPIDER_BOOST_RATIO := 1.15
const SPIDER_BOOST_SECONDS := 2.0
const ROUTE_DEAD_END_WARNING_SECONDS := 1.20
const ROUTE_DEAD_END_WARNING_PX := PLAYER_VERTICAL_SPEED * ROUTE_DEAD_END_WARNING_SECONDS
const TIME_WINGS_STAGE := 5
const TIME_WINGS_SECONDS := 10.0
const TIME_WINGS_SLOW_SCALE := 0.5
const FIRE_WINGS_STAGE := 10
const FIRE_WINGS_SECONDS := 10.0
const FIRE_WINGS_SPEED_SCALE := 1.8
const ROCK_KNOCKBACK_SECONDS := 0.70
const ROCK_STUN_SECONDS := 0.40
const ROCK_KNOCKBACK_SPEED := 210.0
const ROCK_ROLL_SPEED := PLAYER_VERTICAL_SPEED * 1.8
const ROCK_FALL_SPEED := PLAYER_VERTICAL_SPEED * 2.2
const ROCK_INVULNERABILITY_SECONDS := 0.55
const TUTORIAL_SECONDS := 3.0
const STAGE_COMPLETE_SECONDS := 1.5
const TOUCH_BUTTON_MIN_PX := 44.0
const PIXELS_PER_METER := 18.0
const GAUGE_THRESHOLDS := {
	"GREEN": 0.20,
	"YELLOW": 0.40,
	"ORANGE": 0.60,
	"RED": 0.80,
	"DANGER": 1.00,
}
const GAUGE_GAP_THRESHOLDS := {"GREEN": 240.0, "YELLOW": 180.0, "ORANGE": 96.0, "RED": 56.0, "DANGER": 28.0}

static func speed_scale_for_time(t: float) -> float:
	return 1.0 + (ENDLESS_MAX_SPEED_SCALE - 1.0) * clampf(t / ENDLESS_SPEED_RAMP_SECONDS, 0.0, 1.0)

static func difficulty_tier_for_time(t: float) -> int:
	return mini(int(floor(t / DIFFICULTY_STEP_SECONDS)), DIFFICULTY_MAX_TIER)

static func tier_name(tier: int) -> String:
	return ["EASY", "NORMAL", "HARD", "EXPERT"][clampi(tier, 0, DIFFICULTY_MAX_TIER)]

static func estimated_time_for_height(h: float) -> float:
	var distance := maxf(h, 0.0) / PLAYER_VERTICAL_SPEED
	var ramp_distance := ENDLESS_SPEED_RAMP_SECONDS * (1.0 + ENDLESS_MAX_SPEED_SCALE) * 0.5
	if distance >= ramp_distance:
		return ENDLESS_SPEED_RAMP_SECONDS + (distance - ramp_distance) / ENDLESS_MAX_SPEED_SCALE
	var acceleration := (ENDLESS_MAX_SPEED_SCALE - 1.0) / ENDLESS_SPEED_RAMP_SECONDS
	# Rationalized quadratic root avoids cancellation near the start of a run.
	return 2.0 * distance / (1.0 + sqrt(1.0 + 2.0 * acceleration * distance))
