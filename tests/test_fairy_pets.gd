extends SceneTree

const EXPECTED_FAIRIES := {
	"fairy_leaf": {"price": 150, "level": 1, "effect_name": "SOFT GLOW"},
	"fairy_flower": {"price": 250, "level": 2, "effect_name": "LIGHT TRAIL"},
	"fairy_drop": {"price": 400, "level": 3, "effect_name": "SPARKLE DUST"},
	"fairy_firefly": {"price": 600, "level": 4, "effect_name": "HALO RING"},
	"fairy_cloud": {"price": 900, "level": 5, "effect_name": "PRISM AURA"},
	"fairy_star": {"price": 1200, "level": 6, "effect_name": "STAR BURST"},
}
const LEGACY_MAP := {
	"pet_squirrel": "fairy_leaf",
	"pet_ladybug": "fairy_flower",
	"pet_frog": "fairy_drop",
	"pet_bird": "fairy_firefly",
	"pet_snail": "fairy_cloud",
	"pet_rabbit": "fairy_star",
}

var failures := 0

func _init() -> void:
	var economy_file := FileAccess.open("res://config/economy.json", FileAccess.READ)
	var config: Dictionary = JSON.parse_string(economy_file.get_as_text())
	var pets: Array = config.cosmetics.filter(func(item: Dictionary): return str(item.get("slot", "")) == "PET")
	_check(pets.size() == 6, "six fairy pets configured")
	for pet in pets:
		var item_id := str(pet.get("id", ""))
		var expected: Dictionary = EXPECTED_FAIRIES.get(item_id, {})
		_check(not expected.is_empty(), "%s is a fairy id" % item_id)
		if not expected.is_empty():
			_check(int(pet.get("price", -1)) == int(expected.price), "%s price" % item_id)
			_check(int(pet.get("level", -1)) == int(expected.level), "%s level" % item_id)
			_check(str(pet.get("effect_name", "")) == str(expected.effect_name), "%s effect" % item_id)
			_check(str(pet.get("image", "")) == "%s.png" % item_id, "%s image" % item_id)

	var save := SaveManager.new("user://qa/test_fairy_pets.json")
	var legacy_owned: Array = ["M1"] + LEGACY_MAP.keys()
	var migrated := save._sanitize_shop({"owned": legacy_owned, "equipped": {"PET": "pet_bird"}})
	for new_id in LEGACY_MAP.values():
		_check(migrated.owned.has(new_id), "%s owned migration" % new_id)
	_check(str(migrated.equipped.PET) == "fairy_firefly", "equipped pet migration")

	var effect := FairyEffect.new()
	var effect_material := effect.material as CanvasItemMaterial
	_check(effect_material != null and effect_material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "fairy effects use additive light blending")

	var follower := PetFollower.new()
	follower._ready()
	_check(follower.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "game fairy uses linear mipmap filtering")
	var preview := PlayerVisual.new()
	preview._build_visual()
	var preview_pet := preview.cosmetic_sprites.get("PET") as Sprite2D
	_check(preview_pet.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "preview fairy uses linear mipmap filtering")

	var economy := EconomyManager.new()
	economy.initialize(save)
	var shop := MetaShopUI.new()
	shop.economy = economy
	var pet_card := shop._cosmetic_card(pets[0])
	var pet_icon := (pet_card.get_child(0) as VBoxContainer).get_child(2) as TextureRect
	_check(pet_icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "shop fairy uses linear mipmap filtering")

	for pet in pets:
		var import_file := FileAccess.open("res://assets/art/pets/%s.import" % str(pet.image), FileAccess.READ)
		_check(import_file != null and import_file.get_as_text().contains("mipmaps/generate=true"), "%s generates mipmaps" % str(pet.id))

	pet_card.free()
	shop.free()
	preview.free()
	follower.free()
	effect.free()

	if failures == 0:
		print("PASS: fairy effects and filtering")
	quit(failures)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: %s" % label)
