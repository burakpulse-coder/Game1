extends Node

## Altın (soft) ve elmas (hard) para birimleri, kalıcı yükseltmeler,
## seviye ödülleri ve ipucu harcaması.

signal currency_changed(altin: int, elmas: int)
signal upgrade_purchased(key: String, level: int)
signal purchase_failed(reason: String)


func gold() -> int:
	return int(SaveManager.progress.get("altin", 0))


func gems() -> int:
	return int(SaveManager.progress.get("elmas", 0))


func add_gold(amount: int) -> void:
	if amount == 0:
		return
	SaveManager.progress["altin"] = maxi(0, gold() + amount)
	SaveManager.mark_dirty()
	currency_changed.emit(gold(), gems())


func add_gems(amount: int) -> void:
	if amount == 0:
		return
	SaveManager.progress["elmas"] = maxi(0, gems() + amount)
	SaveManager.mark_dirty()
	currency_changed.emit(gold(), gems())


func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold() < amount:
		purchase_failed.emit("Yeterli altın yok")
		return false
	add_gold(-amount)
	return true


func spend_gems(amount: int) -> bool:
	if amount <= 0 or gems() < amount:
		purchase_failed.emit("Yeterli elmas yok")
		return false
	add_gems(-amount)
	return true


## --------------------------------------------------------------------------
## Seviye ödülü
## --------------------------------------------------------------------------

## Zafer ödülü: taban + yıldız + bulunan kelime. Tekrar oynamada azaltılır.
func level_reward(level_id: int, stars: int, words_found: int, first_clear: bool) -> int:
	var base := GameConfig.GOLD_BASE_REWARD + level_id * 2
	var reward := base + stars * GameConfig.GOLD_PER_STAR + words_found * GameConfig.GOLD_PER_WORD
	if not first_clear:
		reward = int(reward * 0.35)
	return maxi(reward, 5)


## --------------------------------------------------------------------------
## Kalıcı yükseltmeler
## --------------------------------------------------------------------------

func upgrade_level(key: String) -> int:
	return SaveManager.upgrade_level(key)


func upgrade_cost(key: String) -> int:
	return GameConfig.upgrade_cost(key, upgrade_level(key))


func can_upgrade(key: String) -> bool:
	var cost := upgrade_cost(key)
	return cost > 0 and gold() >= cost


func buy_upgrade(key: String) -> bool:
	var cost := upgrade_cost(key)
	if cost < 0:
		purchase_failed.emit("Bu yükseltme en üst seviyede")
		return false
	if not spend_gold(cost):
		return false
	var level := upgrade_level(key) + 1
	SaveManager.set_upgrade_level(key, level)
	upgrade_purchased.emit(key, level)
	return true


## Yükseltmenin toplam etkisi (örn. 0.18 = +%18).
func upgrade_bonus(key: String) -> float:
	var data: Dictionary = GameConfig.UPGRADES.get(key, {})
	if data.is_empty():
		return 0.0
	return upgrade_level(key) * float(data["seviye_basina"])


func tower_damage_multiplier() -> float:
	return 1.0 + upgrade_bonus("kule_gucu")


func castle_max_hp() -> float:
	return GameConfig.BASE_CASTLE_HP * (1.0 + upgrade_bonus("kale_cani"))


func ulti_charge_multiplier() -> float:
	return 1.0 + upgrade_bonus("ulti_sarji")


func build_point_multiplier() -> float:
	return 1.0 + upgrade_bonus("insa_hizi")


## --------------------------------------------------------------------------
## İpucu
## --------------------------------------------------------------------------

## Önce günlük ücretsiz hak, yoksa elmas harcanır.
func try_spend_hint() -> bool:
	if SaveManager.consume_free_hint():
		return true
	return spend_gems(GameConfig.HINT_GEM_COST)


## --------------------------------------------------------------------------
## Kozmetikler
## --------------------------------------------------------------------------

func owns_cosmetic(id: String) -> bool:
	return SaveManager.progress.get("kozmetikler", []).has(id)


func buy_cosmetic(id: String) -> bool:
	var data: Dictionary = GameConfig.COSMETICS.get(id, {})
	if data.is_empty() or owns_cosmetic(id):
		return false
	if not spend_gems(int(data["elmas"])):
		return false
	SaveManager.progress["kozmetikler"].append(id)
	SaveManager.mark_dirty()
	return true


func equip_cosmetic(id: String) -> bool:
	var data: Dictionary = GameConfig.COSMETICS.get(id, {})
	if data.is_empty() or not owns_cosmetic(id):
		return false
	SaveManager.progress["secili_kozmetik"][data["hedef"]] = id
	SaveManager.mark_dirty()
	return true


func equipped_cosmetic(target: String) -> String:
	return SaveManager.progress.get("secili_kozmetik", {}).get(target, "")


func cosmetic_color(target: String, fallback: Color) -> Color:
	var id := equipped_cosmetic(target)
	var data: Dictionary = GameConfig.COSMETICS.get(id, {})
	if data.has("renk"):
		return Color(data["renk"])
	return fallback
