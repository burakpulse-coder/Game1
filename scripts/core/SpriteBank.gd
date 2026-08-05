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
##
## Bilerek `class_name` KULLANMIYOR. Global sınıf adları yalnızca editör
## projeyi taradığında `.godot/global_script_class_cache.cfg` dosyasına yazılır;
## editör açıkken `git pull` yapan bir kurulumda yeni bir global sınıf
## çözülemiyor ve onu kullanan her betik derlenemiyor — düşmanlar hiç doğmuyordu.
## Yol üzerinden `preload` bu kayıttan bağımsızdır, her zaman çalışır.

const ENEMY_PATH := "res://assets/sprites/dusman/%s.png"
const WALK_PATH := "res://assets/sprites/dusman/%s_yurume.png"
const WALK_FRAMES := 4       ## yürüyüş şeridindeki eşit hücre sayısı
const ENEMY_HEIGHT := 2.65   ## sprite yüksekliği / oyun yarıçapı oranı
const ENEMY_HEAD := 1.85     ## sprite tepesi (yarıçap katı); üst süsler bunun üstüne

static var _cache := {}


## Düşman türünün sprite'ı; yoksa null (çağıran ProcArt'a düşer).
static func enemy(type_id: String) -> Texture2D:
	return _load(ENEMY_PATH % type_id)


static func has_enemy(type_id: String) -> bool:
	return enemy(type_id) != null


## Düşmanın yürüyüş şeridi (WALK_FRAMES eşit hücreli tek sıra); yoksa null.
## Şerit yoksa çağıran tek kareli sprite'a, o da yoksa ProcArt'a düşer.
static func enemy_walk(type_id: String) -> Texture2D:
	return _load(WALK_PATH % type_id)


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		# Godot dokuları yalnızca editör projeyi taradığında içe aktarır; taranmamış
		# bir kurulumda içe aktarılmış doku (.godot/imported) yoktur ve yüklenemez.
		# O durumda ham PNG doğrudan okunur. Dışa aktarılmış pakette ilk yol zaten
		# çalıştığı için buraya düşülmez.
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
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
## Yatay çevirmeyi ÇAĞIRAN yapar (bkz. Enemy._draw). Burada Rect2'ye negatif
## genişlik vermek işe yaramıyor: Godot dokuyu çevirmek yerine kendi genişliği
## kadar sağa kaydırıyor — sağa yürüyen düşmanlar yolun yanında görünüyordu.
static func draw_enemy(canvas: CanvasItem, texture: Texture2D, radius: float,
		flash: float, walk: float = 0.0) -> void:
	var box_height := radius * ENEMY_HEIGHT
	var source := texture.get_size()
	var box_width := box_height * source.x / maxf(source.y, 1.0)
	# Yürüyüş zıplaması: sabit bir sprite cansız duruyor, yordamsal çizimin
	# adım animasyonu vardı. Ayak hizası korunur, gövde iner çıkar.
	var bob := sin(walk * 2.0) * radius * 0.07
	var rect := Rect2(-box_width * 0.5, radius * 0.92 - box_height - absf(bob),
		box_width, box_height + absf(bob) * 0.5)
	# Vuruşta 1'in üstüne çıkan modulate dokuyu beyaza doğru parlatır.
	var glow := 1.0 + flash * 1.15
	canvas.draw_texture_rect(texture, rect, false, Color(glow, glow, glow))


## Yürüyüş şeridinden tek kare çizer. Kareler eşit genişlikte olduğu için
## hücre sınırı bölmeyle bulunur; şeridi `tools/kes_yurume.py` böyle üretir.
##
## Burada zıplama YOK: hareket karelerin kendisinde. Tek kareli sprite'ta
## eklediğimiz yapay zıplama burada üst üste binip titremeye yol açıyordu.
static func draw_enemy_frame(canvas: CanvasItem, sheet: Texture2D, radius: float,
		flash: float, frame: int) -> void:
	var cell_width := float(sheet.get_width()) / float(WALK_FRAMES)
	var cell_height := float(sheet.get_height())
	var box_height := radius * ENEMY_HEIGHT
	var box_width := box_height * cell_width / maxf(cell_height, 1.0)
	var rect := Rect2(-box_width * 0.5, radius * 0.92 - box_height, box_width, box_height)
	var source := Rect2(cell_width * float(posmod(frame, WALK_FRAMES)), 0.0,
		cell_width, cell_height)
	var glow := 1.0 + flash * 1.15
	canvas.draw_texture_rect_region(sheet, rect, source, Color(glow, glow, glow))
