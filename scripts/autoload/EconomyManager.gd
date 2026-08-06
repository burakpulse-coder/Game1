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
## Destekler
## --------------------------------------------------------------------------
##
## Kozmetik satışı kaldırıldı; yerine bölümü geçmeye yardım eden tüketilir
## destekler geldi. Elmasla alınır, elmas oyun içinde de kazanılır — yani
## ödeme kilit açmaz, hızlandırır.

signal boosters_changed


func booster_count(id: String) -> int:
	return int(SaveManager.progress.get("destekler", {}).get(id, 0))


func grant_booster(id: String, amount: int = 1) -> void:
	if amount <= 0 or not GameConfig.BOOSTERS.has(id):
		return
	var envanter: Dictionary = SaveManager.progress.get("destekler", {})
	envanter[id] = booster_count(id) + amount
	SaveManager.progress["destekler"] = envanter
	SaveManager.mark_dirty()
	boosters_changed.emit()


## Elmasla bir destek satın alır.
func buy_booster(id: String, amount: int = 1) -> bool:
	var data: Dictionary = GameConfig.BOOSTERS.get(id, {})
	if data.is_empty() or amount <= 0:
		return false
	if not spend_gems(int(data["elmas"]) * amount):
		return false
	grant_booster(id, amount)
	return true


## Envanterden bir destek düşer. Yoksa false döner ve hiçbir şey değişmez.
func consume_booster(id: String) -> bool:
	if booster_count(id) <= 0:
		return false
	var envanter: Dictionary = SaveManager.progress.get("destekler", {})
	envanter[id] = booster_count(id) - 1
	SaveManager.progress["destekler"] = envanter
	SaveManager.mark_dirty()
	boosters_changed.emit()
	return true


func boosters_of_kind(kind: String) -> Array:
	var found: Array = []
	for id in GameConfig.BOOSTERS:
		if str(GameConfig.BOOSTERS[id].get("tur", "")) == kind:
			found.append(id)
	return found


## --------------------------------------------------------------------------
## Bölüm öncesi takılan destekler
## --------------------------------------------------------------------------

func equipped_boosters() -> Array:
	var secili: Array = SaveManager.progress.get("secili_destekler", [])
	# Envanterde kalmayanlar düşer: satın alma ekranından çıkıp gelen oyuncu
	# elinde olmayan bir desteği takılı görmesin.
	var temiz: Array = []
	for id in secili:
		if booster_count(str(id)) > 0 and GameConfig.BOOSTERS.has(id):
			temiz.append(id)
	if temiz.size() != secili.size():
		SaveManager.progress["secili_destekler"] = temiz
	return temiz


func toggle_equipped_booster(id: String) -> bool:
	var data: Dictionary = GameConfig.BOOSTERS.get(id, {})
	if data.is_empty() or str(data.get("tur", "")) != "oncesi":
		return false
	var secili := equipped_boosters()
	if secili.has(id):
		secili.erase(id)
	else:
		if booster_count(id) <= 0:
			purchase_failed.emit("Bu destekten kalmadı")
			return false
		if secili.size() >= GameConfig.MAX_PRE_BOOSTERS:
			purchase_failed.emit("En fazla %d destek takabilirsin" % GameConfig.MAX_PRE_BOOSTERS)
			return false
		secili.append(id)
	SaveManager.progress["secili_destekler"] = secili
	SaveManager.mark_dirty()
	boosters_changed.emit()
	return true


## Savaş başlarken takılı destekleri envanterden düşer ve listesini döner.
func take_equipped_boosters() -> Array:
	var kullanilan: Array = []
	for id in equipped_boosters():
		if consume_booster(str(id)):
			kullanilan.append(id)
	SaveManager.progress["secili_destekler"] = []
	SaveManager.mark_dirty()
	boosters_changed.emit()
	return kullanilan
