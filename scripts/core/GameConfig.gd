class_name GameConfig
extends RefCounted

## Oyun dengesinin tek kaynağı. Sahnelerde sabit sayı kullanılmaz; hepsi buradan
## okunur ki denge ayarı tek dosyadan yapılabilsin.

# --- Kelime -------------------------------------------------------------
const MIN_WORD_LENGTH := 3
const ANCIENT_WORD_LENGTH := 7  ## "Kadim Kelime" eşiği

## Kelime uzunluğu -> etki çarpanı (3=1x, 4=1.5x, 5=2x, 6+=3x)
const LENGTH_MULTIPLIERS := {3: 1.0, 4: 1.5, 5: 2.0}
const LENGTH_MULTIPLIER_MAX := 3.0

const COMBO_STEP := 0.10       ## Arka arkaya doğru kelime başına +%10
const COMBO_MAX := 1.0         ## En fazla +%100
const GENERAL_ENERGY_RATIO := 0.05  ## Kategori dışı kelime: tüm kulelere %5

# --- İnşa puanı ---------------------------------------------------------
## 3 harfli kelimenin taban katkısı. Geç bölümlerde yuva sayısı 9'a çıktığı için
## kuleler zamanında ayağa kalkmıyordu; bu değer savunmanın kurulma hızını belirler.
const BUILD_POINTS_PER_WORD := 48.0
const BUILD_POINT_THRESHOLD := 100.0  ## Yeni kule için gereken puan
const UPGRADE_COST_L2 := 130.0
const UPGRADE_COST_L3 := 190.0
const MAX_TOWER_LEVEL := 3

# --- Ulti ---------------------------------------------------------------
const ULTI_CHARGE_PER_ANCIENT := 0.5   ## Her Kadim Kelime %50 şarj
const ULTI_DAMAGE := 400.0

# --- Kule tipleri -------------------------------------------------------
## menzil: piksel | atis_araligi: saniye | hasar: can
const TOWERS := {
	"okcu": {
		"ad": "Okçu Kulesi",
		"kategori": "hayvan",
		"menzil": 240.0,
		"atis_araligi": 0.55,
		"hasar": 12.0,
		"alan_yaricap": 0.0,
		"renk": "#c9772e",
		"mermi_hiz": 900.0,
		"aciklama": "Hızlı ateş eden tek hedefli kule.",
	},
	"buyu": {
		"ad": "Büyü Kulesi",
		"kategori": "doga",
		"menzil": 210.0,
		"atis_araligi": 1.25,
		"hasar": 15.0,
		"alan_yaricap": 78.0,
		"renk": "#3f8fd6",
		"mermi_hiz": 520.0,
		"aciklama": "Alan hasarı verir; hayaletlere işleyen tek kule.",
	},
	"mancinik": {
		"ad": "Mancınık",
		"kategori": "nesne",
		"menzil": 330.0,
		"atis_araligi": 2.4,
		"hasar": 58.0,
		"alan_yaricap": 60.0,
		"renk": "#8d6b4b",
		"mermi_hiz": 380.0,
		"aciklama": "Yavaş ama çok yüksek hasar; zırhlı düşmanları ezer.",
	},
	"sifa": {
		"ad": "Şifa Çeşmesi",
		"kategori": "yiyecek",
		"menzil": 0.0,
		"atis_araligi": 3.0,
		"hasar": 0.0,
		"alan_yaricap": 0.0,
		"renk": "#4fbf6a",
		"mermi_hiz": 0.0,
		"iyilestirme": 7.0,
		"aciklama": "Saldırmaz; kalenin canını yeniler.",
	},
}

## Kule seviyesine göre güç çarpanı (1, 2, 3).
const TOWER_LEVEL_SCALE := [1.0, 1.45, 2.0]

# --- Düşman tipleri -----------------------------------------------------
## zirh: gelen hasarın çarpanı (0.5 = yarısı) | zayiflik: bu kule tipine karşı çarpan
const ENEMIES := {
	"goblin": {
		"ad": "Goblin",
		"can": 32.0, "hiz": 92.0, "hasar": 5.0, "altin": 3,
		"zirh": 1.0, "zayiflik": {}, "bagisiklik": [],
		"renk": "#78b04a", "boy": 0.85,
		"aciklama": "Hızlı ama zayıf. Kalabalık gelir.",
	},
	"ork": {
		"ad": "Ork",
		"can": 78.0, "hiz": 62.0, "hasar": 11.0, "altin": 5,
		"zirh": 1.0, "zayiflik": {}, "bagisiklik": [],
		"renk": "#4c7a3a", "boy": 1.0,
		"aciklama": "Dengeli asker. Orta can, orta hız.",
	},
	"zirhli_trol": {
		"ad": "Zırhlı Trol",
		"can": 240.0, "hiz": 34.0, "hasar": 26.0, "altin": 12,
		"zirh": 0.5, "zayiflik": {"mancinik": 2.2}, "bagisiklik": [],
		"renk": "#6b6f7a", "boy": 1.35,
		"aciklama": "Zırhı hasarı yarıya indirir. Mancınık zırhı parçalar.",
	},
	"hayalet": {
		"ad": "Hayalet",
		"can": 66.0, "hiz": 78.0, "hasar": 13.0, "altin": 8,
		"zirh": 1.0, "zayiflik": {}, "bagisiklik": ["okcu", "mancinik"],
		"renk": "#9fb6d9", "boy": 1.0,
		"aciklama": "Fiziksel saldırılara dokunulmaz; yalnız Büyü Kulesi vurur.",
	},
	"harf_hirsizi": {
		"ad": "Harf Hırsızı",
		"can": 54.0, "hiz": 118.0, "hasar": 4.0, "altin": 10,
		"zirh": 1.0, "zayiflik": {}, "bagisiklik": [],
		"renk": "#b45fb0", "boy": 0.9,
		"calar_harf": true, "calma_suresi": 5.0,
		"aciklama": "Çarktan bir harfi 5 saniye kilitler. Öldürülünce harf açılır.",
	},
	"boss_vadi": {
		"ad": "Yeşil Vadi Devi",
		"can": 1400.0, "hiz": 30.0, "hasar": 40.0, "altin": 60,
		"zirh": 0.8, "zayiflik": {}, "bagisiklik": [],
		"renk": "#3f6b2c", "boy": 1.9, "boss": true,
		"fazlar": [{"can_orani": 0.6, "hiz_carpani": 1.35}, {"can_orani": 0.25, "hiz_carpani": 1.7, "cagirir": "goblin"}],
		"aciklama": "Canı azaldıkça hızlanır ve goblin çağırır.",
	},
	"boss_orman": {
		"ad": "Karanlık Orman Cadısı",
		"can": 2200.0, "hiz": 44.0, "hasar": 46.0, "altin": 90,
		"zirh": 1.0, "zayiflik": {}, "bagisiklik": ["okcu"],
		"renk": "#4a2f5e", "boy": 1.8, "boss": true,
		"fazlar": [{"can_orani": 0.55, "hiz_carpani": 1.3, "cagirir": "hayalet"}, {"can_orani": 0.2, "hiz_carpani": 1.6, "cagirir": "hayalet"}],
		"aciklama": "Oklara dokunulmaz, hayalet çağırır.",
	},
	"boss_buz": {
		"ad": "Buz Dağları Kadim Devi",
		"can": 3200.0, "hiz": 32.0, "hasar": 55.0, "altin": 130,
		"zirh": 0.45, "zayiflik": {"mancinik": 2.0}, "bagisiklik": [],
		"renk": "#7fc4e0", "boy": 2.1, "boss": true,
		"fazlar": [{"can_orani": 0.5, "hiz_carpani": 1.25, "cagirir": "zirhli_trol"}, {"can_orani": 0.2, "hiz_carpani": 1.5, "cagirir": "harf_hirsizi"}],
		"aciklama": "Kalın zırhlı. Mancınık şart.",
	},
	"boss_ejder": {
		"ad": "Ejder Kalesi Efendisi",
		"can": 4800.0, "hiz": 38.0, "hasar": 70.0, "altin": 200,
		"zirh": 0.6, "zayiflik": {}, "bagisiklik": [],
		"renk": "#a63232", "boy": 2.3, "boss": true,
		"fazlar": [
			{"can_orani": 0.7, "hiz_carpani": 1.2, "cagirir": "ork"},
			{"can_orani": 0.4, "hiz_carpani": 1.45, "cagirir": "hayalet"},
			{"can_orani": 0.15, "hiz_carpani": 1.8, "cagirir": "zirhli_trol"},
		],
		"aciklama": "Üç fazlı son patron.",
	},
}

# --- Bölgeler -----------------------------------------------------------
const REGIONS := [
	{"id": "yesil_vadi", "ad": "Yeşil Vadi", "renk": "#6fae4a", "gereken_yildiz": 0, "boss": "boss_vadi"},
	{"id": "karanlik_orman", "ad": "Karanlık Orman", "renk": "#3f5d3a", "gereken_yildiz": 22, "boss": "boss_orman"},
	{"id": "buz_daglari", "ad": "Buz Dağları", "renk": "#7fb6d6", "gereken_yildiz": 55, "boss": "boss_buz"},
	{"id": "ejder_kalesi", "ad": "Ejder Kalesi", "renk": "#a3452f", "gereken_yildiz": 92, "boss": "boss_ejder"},
]
## Bölge görsel temaları. Dört bölge oynanışta farklıydı ama ekranda tıpatıp
## aynı görünüyordu; manzara katmanı (Scenery) rengini ve süslerini buradan alır.
const REGION_THEMES := {
	"yesil_vadi": {
		"gok_ust": "#6f9fc4", "gok_alt": "#a8c98a",
		"zemin": "#5f9b45", "zemin_alt": "#3d6b2e",
		"leke": "#6fae4a", "ufuk": "#3f6b3a", "uzak_tepe": "#7fa86a",
		"yol": "#b09166", "yol_kenar": "#8a6f45",
		"susler": ["agac", "cali", "kaya"],
		"yaprak": "#3e7a34", "govde": "#5a4029", "tas": "#8a8f7a",
		"zerre": "#f6f0a0",
	},
	"karanlik_orman": {
		"gok_ust": "#2e3550", "gok_alt": "#3f5d4a",
		"zemin": "#2f4a30", "zemin_alt": "#1d3020",
		"leke": "#3a5a38", "ufuk": "#1a2a1e", "uzak_tepe": "#2a4030",
		"yol": "#6a5a44", "yol_kenar": "#4a3d2c",
		"susler": ["cam", "mantar", "kutuk"],
		"yaprak": "#25452c", "govde": "#3a2b1e", "tas": "#4a4a52",
		"zerre": "#8ad6a0",
	},
	"buz_daglari": {
		"gok_ust": "#7aa8cf", "gok_alt": "#cfe4f2",
		"zemin": "#c3d9e6", "zemin_alt": "#8fb0c6",
		"leke": "#d8e9f4", "ufuk": "#6f93b0", "uzak_tepe": "#a6c4da",
		"yol": "#9aa8b4", "yol_kenar": "#75838f",
		"susler": ["buz", "kaya", "kutuk"],
		"yaprak": "#8fc4d8", "govde": "#5b5a62", "tas": "#9aa4ae",
		"zerre": "#ffffff",
	},
	"ejder_kalesi": {
		"gok_ust": "#4a2230", "gok_alt": "#8c4230",
		"zemin": "#4a3330", "zemin_alt": "#2b1c1e",
		"leke": "#5a3a32", "ufuk": "#2a1618", "uzak_tepe": "#5c3028",
		"yol": "#6b4f42", "yol_kenar": "#452f28",
		"susler": ["kaya", "lav", "kutuk"],
		"yaprak": "#6b3226", "govde": "#33241f", "tas": "#57505a",
		"zerre": "#ffab5c",
	},
}

const LEVELS_PER_REGION := 15
const TOTAL_LEVELS := 60

# --- Kale / seviye ------------------------------------------------------
const BASE_CASTLE_HP := 100.0
const WAVE_BREAK_SECONDS := 5.0
const STAR_THRESHOLDS := [0.0, 0.5, 0.8]  ## kalan can oranı: 1★ / 2★ / 3★

# --- Ekonomi ------------------------------------------------------------
const GOLD_PER_STAR := 25
const GOLD_BASE_REWARD := 40
const GOLD_PER_WORD := 2
const FREE_HINTS_PER_DAY := 3
const HINT_GEM_COST := 8
const CONTINUE_REVIVE_HP_RATIO := 0.45

## Kalıcı yükseltmeler: her seviye için maliyet ve etki.
const UPGRADES := {
	"kule_gucu": {
		"ad": "Kule Gücü",
		"aciklama": "Tüm kulelerin hasarı artar.",
		"max_seviye": 10,
		"taban_maliyet": 120,
		"maliyet_carpani": 1.45,
		"seviye_basina": 0.06,
	},
	"kale_cani": {
		"ad": "Kale Canı",
		"aciklama": "Kalenin başlangıç canı artar.",
		"max_seviye": 10,
		"taban_maliyet": 100,
		"maliyet_carpani": 1.40,
		"seviye_basina": 0.08,
	},
	"ulti_sarji": {
		"ad": "Ulti Şarjı",
		"aciklama": "Kadim Kelime ultiyi daha hızlı doldurur.",
		"max_seviye": 8,
		"taban_maliyet": 150,
		"maliyet_carpani": 1.5,
		"seviye_basina": 0.07,
	},
	"insa_hizi": {
		"ad": "İnşa Hızı",
		"aciklama": "Kelimeler daha çok inşa puanı verir.",
		"max_seviye": 10,
		"taban_maliyet": 140,
		"maliyet_carpani": 1.45,
		"seviye_basina": 0.05,
	},
}

# --- Reklam / mağaza ----------------------------------------------------
const INTERSTITIAL_EVERY_N_LEVELS := 3

const IAP_PRODUCTS := {
	"elmas_kucuk": {"ad": "Küçük Elmas Kesesi", "elmas": 100, "fiyat": "₺29,99", "tur": "tuketilir"},
	"elmas_orta": {"ad": "Orta Elmas Sandığı", "elmas": 320, "fiyat": "₺79,99", "tur": "tuketilir"},
	"elmas_buyuk": {"ad": "Büyük Elmas Hazinesi", "elmas": 900, "fiyat": "₺199,99", "tur": "tuketilir"},
	"reklamsiz": {"ad": "Reklamları Kaldır", "elmas": 0, "fiyat": "₺59,99", "tur": "kalici"},
	"baslangic": {"ad": "Başlangıç Paketi", "elmas": 250, "altin": 1500, "fiyat": "₺49,99", "tur": "kalici", "tek_seferlik": true},
}

## Kozmetikler oyun gücünü etkilemez (pay-to-win yok).
const COSMETICS := {
	"kale_varsayilan": {"ad": "Taş Kale", "elmas": 0, "hedef": "kale", "renk": "#8e8e96"},
	"kale_altin": {"ad": "Altın Kale", "elmas": 180, "hedef": "kale", "renk": "#d8b23c"},
	"kale_obsidyen": {"ad": "Obsidyen Kale", "elmas": 240, "hedef": "kale", "renk": "#3a3548"},
	"kule_varsayilan": {"ad": "Klasik Kuleler", "elmas": 0, "hedef": "kule", "renk": "#9a8f7f"},
	"kule_zumrut": {"ad": "Zümrüt Kuleler", "elmas": 200, "hedef": "kule", "renk": "#3fa87a"},
	"kule_kizil": {"ad": "Kızıl Kuleler", "elmas": 200, "hedef": "kule", "renk": "#b5483c"},
}


static func length_multiplier(word_length: int) -> float:
	if LENGTH_MULTIPLIERS.has(word_length):
		return LENGTH_MULTIPLIERS[word_length]
	return LENGTH_MULTIPLIER_MAX if word_length >= 6 else 0.0


## Seviyenin bölge teması (Scenery ve PathTrack buradan renk alır).
static func theme_of_level(level_id: int) -> Dictionary:
	var region: Dictionary = REGIONS[region_of_level(level_id)]
	return REGION_THEMES.get(region["id"], REGION_THEMES["yesil_vadi"])


static func region_of_level(level_id: int) -> int:
	return clampi((level_id - 1) / LEVELS_PER_REGION, 0, REGIONS.size() - 1)


static func is_boss_level(level_id: int) -> bool:
	return level_id % LEVELS_PER_REGION == 0


static func upgrade_cost(key: String, current_level: int) -> int:
	var data: Dictionary = UPGRADES.get(key, {})
	if data.is_empty() or current_level >= int(data["max_seviye"]):
		return -1
	return int(round(float(data["taban_maliyet"]) * pow(float(data["maliyet_carpani"]), current_level)))
