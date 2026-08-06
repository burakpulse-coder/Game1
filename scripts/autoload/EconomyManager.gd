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
## Günlük giriş serisi
## --------------------------------------------------------------------------
##
## Yedi günlük döngü. Bir gün kaçırılırsa seri baştan başlar; aynı gün ikinci
## kez alınamaz. Ödemeyen oyuncunun düzenli elmas/destek kaynağı burasıdır.

signal daily_claimed(day: int, reward: Dictionary)


## Bugün ödül alınabilir mi?
func daily_available() -> bool:
	var state: Dictionary = SaveManager.progress.get("gunluk", {})
	return str(state.get("tarih", "")) != SaveManager.today_string()


## Bugün hangi gün sırasında? 1..7. Henüz alınmadıysa alınacak günü verir.
func daily_day() -> int:
	var state: Dictionary = SaveManager.progress.get("gunluk", {})
	var last := str(state.get("tarih", ""))
	var day := int(state.get("gun", 0))
	if not daily_available():
		return maxi(day, 1)
	# Bir günden fazla ara verildiyse döngü baştan başlar.
	if SaveManager.days_between(last, SaveManager.today_string()) != 1:
		return 1
	return (day % GameConfig.DAILY_REWARDS.size()) + 1


func daily_streak() -> int:
	return int(SaveManager.progress.get("gunluk", {}).get("seri", 0))


func daily_reward_for(day: int) -> Dictionary:
	var index := clampi(day - 1, 0, GameConfig.DAILY_REWARDS.size() - 1)
	return GameConfig.DAILY_REWARDS[index]


## Günün ödülünü verir. `multiplier` ödüllü video için 2 olur.
## Zaten alınmışsa hiçbir şey yapmaz ve boş sözlük döner.
func claim_daily(multiplier: int = 1) -> Dictionary:
	if not daily_available():
		return {}
	var day := daily_day()
	var last := str(SaveManager.progress.get("gunluk", {}).get("tarih", ""))
	var streak := daily_streak()
	streak = streak + 1 if SaveManager.days_between(last, SaveManager.today_string()) == 1 else 1

	var reward := daily_reward_for(day)
	var verilen := _grant_reward(reward, multiplier)
	SaveManager.progress["gunluk"] = {
		"tarih": SaveManager.today_string(),
		"gun": day,
		"seri": streak,
		"video": multiplier > 1,
	}
	SaveManager.mark_dirty()
	daily_claimed.emit(day, verilen)
	return verilen


## Bugünün ödülü ödüllü videoyla ikiye katlanabilir mi?
func daily_can_double() -> bool:
	var state: Dictionary = SaveManager.progress.get("gunluk", {})
	return str(state.get("tarih", "")) == SaveManager.today_string() \
		and not bool(state.get("video", false))


## Ödül zaten alındıysa videoyla FARKI verir (bir kat daha).
func double_daily_with_ad() -> Dictionary:
	if daily_can_double():
		var reward := daily_reward_for(daily_day())
		var verilen := _grant_reward(reward, GameConfig.DAILY_AD_MULTIPLIER - 1)
		SaveManager.progress["gunluk"]["video"] = true
		SaveManager.mark_dirty()
		return verilen
	return {}


func _grant_reward(reward: Dictionary, multiplier: int) -> Dictionary:
	var verilen := {}
	if reward.has("altin"):
		var altin := int(reward["altin"]) * multiplier
		add_gold(altin)
		verilen["altin"] = altin
	if reward.has("elmas"):
		var elmas := int(reward["elmas"]) * multiplier
		add_gems(elmas)
		verilen["elmas"] = elmas
	if reward.has("destek"):
		var adet := int(reward.get("adet", 1)) * multiplier
		grant_booster(str(reward["destek"]), adet)
		verilen["destek"] = reward["destek"]
		verilen["adet"] = adet
	return verilen


## --------------------------------------------------------------------------
## Kumbara
## --------------------------------------------------------------------------
##
## Oyuncu OYNADIKÇA dolar, gerçek parayla boşaltılır. Bilerek şeffaf: içine
## yalnızca oyuncunun kendi kazandığı elmas girer, hiçbir şey arkasına
## kilitlenmez ve oyun kumbarasız bitirilebilir.

signal piggy_changed(amount: int)


func piggy_amount() -> int:
	return clampi(int(SaveManager.progress.get("kumbara", 0)), 0, GameConfig.PIGGY_CAPACITY)


func piggy_full() -> bool:
	return piggy_amount() >= GameConfig.PIGGY_CAPACITY


func add_to_piggy(amount: int) -> int:
	if amount <= 0 or piggy_full():
		return 0
	var eklenen := mini(amount, GameConfig.PIGGY_CAPACITY - piggy_amount())
	SaveManager.progress["kumbara"] = piggy_amount() + eklenen
	SaveManager.mark_dirty()
	piggy_changed.emit(piggy_amount())
	return eklenen


## Bölüm kazanınca kumbaraya düşen pay.
func fill_piggy_for_level(stars: int, ancient_words: int) -> int:
	return add_to_piggy(GameConfig.PIGGY_PER_LEVEL
		+ stars * GameConfig.PIGGY_PER_STAR
		+ ancient_words * GameConfig.PIGGY_PER_ANCIENT)


## Satın alma tamamlandığında çağrılır: biriken elması verir ve sıfırlar.
func break_piggy() -> int:
	var amount := piggy_amount()
	if amount <= 0:
		return 0
	SaveManager.progress["kumbara"] = 0
	add_gems(amount)
	SaveManager.mark_dirty()
	piggy_changed.emit(0)
	return amount


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
