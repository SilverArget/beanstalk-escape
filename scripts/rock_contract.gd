class_name RockContract
extends RefCounted

# Turn 1 contract only. Rock gameplay begins in the separately approved milestone.
enum Kind { STATIC, ROLLING, FALLING, MOVING }
var kind: Kind
var knockback_seconds := 0.0
var stun_seconds := 0.0
