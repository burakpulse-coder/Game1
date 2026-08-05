class_name SpriteBank
extends RefCounted

## Elle çizilmiş sprite'ların kayıt defteri.
##
## Oyun yordamsal çizimle (ProcArt) başladı ve tüm görselleri hâlâ kod üretebilir.
## Sprite'lar bunun yerine değil, ÜSTÜNE gelir: bir tür için dosya varsa o
## kullanılır, yoksa çizim ProcArt'a düşer. Böylece set yarım kaldığında bile
## oyun eksiksiz görünür ve sprite'sız bir tür eklemek hiçbir şeyi bozmaz.
##
## Dosyalar ekrandaki boyutlarına yakın (256 piksel yükseklik) tutulur; büyük
## dosyaları küçültmek hem paketi şişiriyor hem mipmap'siz titreme yapıyordu.

const ENEMY_PATH := "res://assets/sprites/dusman/%s.png"
const ENEMY_HEIGHT := 2.65   ## sprite yüksekliği / oyun yarıçapı oranı
const ENEMY_HEAD := 1.85     ## sprite tepesi (yarıçap katı); üst süsler bunun üstüne

static var _cache := {}


## Düşman türünün sprite'ı; yoksa null (çağıran ProcArt'a düşer).
static func enemy(type_id: String) -> Texture2D:
	return _load(ENEMY_PATH % type_id)


static func has_enemy(type_id: String) -> bool:
	return enemy(type_id) != null


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_cache[path] = texture
	return texture


## Sprite'ı, ayakları verilen yarıçapın tabanına gelecek şekilde çizer.
##
## `radius` oyunun çarpışma/denge yarıçapı; sprite yüksekliği buna oranlanır ki
## Zırhlı Trol gerçekten Goblin'den 1.35 kat iri görünsün — dosyaların kendi
## boyutları değil, oyunun verisi ölçüyü belirler.
##
## Sprite'ın tepesi `-ENEMY_HEAD * radius` hizasındadır; can çubuğu gibi üst
## süslerin nereye konacağını çağıran buradan öğrenir.
static func draw_enemy(canvas: CanvasItem, texture: Texture2D, radius: float,
		facing: float, flash: float, walk: float = 0.0) -> void:
	var box_height := radius * ENEMY_HEIGHT
	var source := texture.get_size()
	var box_width := box_height * source.x / maxf(source.y, 1.0)
	# Yürüyüş zıplaması: sabit bir sprite cansız duruyor, yordamsal çizimin
	# adım animasyonu vardı. Ayak hizası korunur, gövde iner çıkar.
	var bob := sin(walk * 2.0) * radius * 0.07
	var rect := Rect2(-box_width * 0.5, radius * 0.92 - box_height - absf(bob),
		box_width, box_height + absf(bob) * 0.5)
	if facing > 0.0:
		# Negatif genişlik dokuyu yatay çevirir.
		rect = Rect2(rect.position.x + box_width, rect.position.y, -box_width, box_height)
	# Vuruşta 1'in üstüne çıkan modulate dokuyu beyaza doğru parlatır.
	var glow := 1.0 + flash * 1.15
	canvas.draw_texture_rect(texture, rect, false, Color(glow, glow, glow))
