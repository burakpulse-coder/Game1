# Kelime Kalesi — Görsel Üretim İstemleri

Bu dosya, oyunun kalan tüm görselleri için hazır istemleri (prompt) içerir.
Her madde tek bir görsel üretir; birden çok varlık **tek sayfada** istenir çünkü
aynı görselde üretilen varlıklar birbiriyle stil tutar ve kredi ucuza gelir.

## Önce şunu oku

**1. Her üretimde referans görsel ekle.** Elimizde zaten stili belirleyen bir
sayfa var: `assets/sprites/dusman/` klasöründeki düşmanların üretildiği sayfa.
Nano Banana Pro'ya bunu referans olarak verirsen bütün set aynı dilde konuşur.
Referans veremiyorsan aşağıdaki STİL BLOĞU'nu her isteme aynen yapıştır.

**2. Çözünürlük.** Tek varlık için 1K yeter. Izgara sayfalarında (3'ten çok
hücre) **2K veya 4K** seç, yoksa hücre başına düşen çözünürlük sprite için az
kalıyor.

**3. Zemin her zaman düz beyaz.** Kesme işini ben yapıyorum; gölge, zemin,
çerçeve, yazı olursa kesim bozuluyor.

**4. Dosya adı.** Her maddenin altında yazan adı kullan. Adları koda göre
seçtim; farklı bir adla yüklersen bağlarken karışır.

---

## STİL BLOĞU (referans görsel veremediğinde her isteme ekle)

```
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, saturated but slightly muted earthy colors,
polished casual mobile game sprite art. Solid pure white background. No ground,
no cast shadows, no bases, no frames, no borders, no text, no labels, no numbers.
```

---

# ÖNCELİK 1 — Yürüyüş animasyonu

Şu an düşmanlar kayarak ilerliyor, adım atmıyor. Her düşman için **4 kareli tek
sıra** üretilecek. Kareleri ben otomatik keseceğim, o yüzden aralarında boşluk
olması ve karakterin kare içinde aynı boyda kalması kritik.

Altı istemin de yapısı aynı; sadece karakter tarifi değişiyor. Hepsinde:

- En-boy oranı: **16:9**
- Çözünürlük: **2K**
- Referans olarak o düşmanın mevcut sprite'ını ver (`assets/sprites/dusman/*.png`)

### 1.1 — `goblin_yurume.png`

```
A four-frame walking animation strip of one single character, arranged left to
right in one horizontal row, with generous empty space between each frame.
The character is IDENTICAL in all four frames: same size, same colors, same
proportions, same facing direction (three-quarter view facing the viewer's
left). Only the legs and arms change position to show a walk cycle: frame 1
left leg forward contact pose, frame 2 passing pose with legs together, frame 3
right leg forward contact pose, frame 4 passing pose with legs together. The
head stays at the same height in every frame.
The character: a small skinny green goblin holding a crude rusty dagger,
pointed ears, big yellow eyes, brown loincloth.
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, saturated but slightly muted earthy colors,
polished casual mobile game sprite art. Solid pure white background. No ground,
no cast shadows, no bases, no frames, no borders, no text, no labels, no numbers.
```

### 1.2 — `ork_yurume.png`

Aynı istem, karakter satırı şununla değişecek:

```
The character: a burly muscular green orc soldier carrying a heavy wooden club,
tusks, brown leather boots and belt.
```

### 1.3 — `zirhli_trol_yurume.png`

```
The character: a hulking troll encased in thick grey riveted steel plate armor,
heavy shoulder plates, small angry eyes, brown cloth skirt.
```

### 1.4 — `hayalet_yurume.png`

Hayaletin bacağı yok; onun için yürüme yerine süzülme:

```
A four-frame floating animation strip of one single character, arranged left to
right in one horizontal row, with generous empty space between each frame.
The character is IDENTICAL in all four frames: same size, same colors, same
proportions, same facing direction. Only the wispy tail and arms change shape to
show a slow floating drift: frame 1 tail curling left, frame 2 tail straight and
body slightly higher, frame 3 tail curling right, frame 4 tail straight and body
slightly lower.
The character: a translucent pale blue-white ghost with no legs and a wispy
trailing tail, hollow dark eyes, simple round head.
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, saturated but slightly muted earthy colors,
polished casual mobile game sprite art. Solid pure white background. No ground,
no cast shadows, no bases, no frames, no borders, no text, no labels, no numbers.
```

### 1.5 — `harf_hirsizi_yurume.png`

```
The character: a sneaky hooded purple-cloaked thief clutching a glowing golden
letter tile in one hand, dark mask over the face, white glowing eyes, brown
boots and belt pouch.
```

### 1.6 — `boss_ejder_yurume.png`

```
The character: a large intimidating red dragon-knight boss in dark crimson armor
with a horned helmet and small leathery wings, thick tail.
```

---

# ÖNCELİK 2 — Kuleler

Kulelerin 3 yükseltme seviyesi var ve seviye atladıkça belirgin biçimde
büyümeli/zenginleşmeli — oyuncu bakınca "bu yükseltilmiş" demeli.

### 2.1 — `kuleler.png`

- En-boy oranı: **4:3**
- Çözünürlük: **4K** (12 hücre var, çözünürlük şart)

```
A game asset sprite sheet showing four tower types in three upgrade levels each,
arranged in a clean 4x3 grid: four rows (one per tower type), three columns
(level 1 on the left, level 2 in the middle, level 3 on the right). Every tower
is fully isolated with generous empty space around it, seen from a slight
three-quarter front view, standing upright, no ground beneath them.
Within each row the tower is clearly the SAME tower getting bigger and more
elaborate from left to right: level 1 small and plain, level 2 taller with more
detail, level 3 tallest and most decorated.
Row 1, Archer Tower: a stone tower with a wooden crossbow platform on top and
orange banners. Row 2, Magic Tower: a stone tower topped with a glowing blue
crystal and arcane blue runes. Row 3, Catapult: a squat wooden and stone siege
platform with a brown throwing arm and a boulder. Row 4, Healing Fountain: a
short round stone fountain basin with glowing green water and vines, no weapon.
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, saturated but slightly muted earthy colors,
polished casual mobile game sprite art. Solid pure white background. No ground,
no cast shadows, no bases, no frames, no borders, no text, no labels, no numbers.
```

**Not:** Mağazada "Zümrüt Kuleler" kozmetiği satılıyor. Ayrı bir sayfa üretmene
gerek yok — bu sayfadan yeşil varyantı kod içinde renk katmanıyla üreteceğim.

---

# ÖNCELİK 3 — Patronlar ve kale

### 3.1 — `patronlar.png`

Üç patron eksik (ejder patronu elimizde var).

- En-boy oranı: **16:9**
- Çözünürlük: **2K**

```
A game asset sprite sheet showing three large boss characters in a single
horizontal row, evenly spaced, each fully isolated with generous empty space
between them, front-facing three-quarter view, no ground, no cast shadows.
All three are clearly bosses: much bigger and more imposing than ordinary
enemies.
Left: a massive green forest giant made of mossy stone and bark, with a thick
beard of leaves and huge fists. Middle: a tall dark purple forest witch in a
tattered hooded robe holding a gnarled staff with a glowing violet orb, long
crooked fingers. Right: a colossal pale blue ancient ice giant with jagged
crystal shards growing from its shoulders and back, glowing white eyes.
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, saturated but slightly muted earthy colors,
polished casual mobile game sprite art. Solid pure white background. No ground,
no cast shadows, no bases, no frames, no borders, no text, no labels, no numbers.
```

### 3.2 — `kaleler.png`

Mağazadaki üç kale kozmetiği: Taş, Altın, Obsidyen.

- En-boy oranı: **16:9**
- Çözünürlük: **2K**

```
A game asset sprite sheet showing the same fantasy castle keep three times in a
single horizontal row, evenly spaced, each fully isolated with generous empty
space between them, front-facing three-quarter view, no ground, no cast shadows.
The three castles have IDENTICAL shape, size and proportions — a compact square
keep with two side towers, crenellated battlements, a big arched wooden gate and
small flags on the towers. Only the material changes.
Left: grey stone castle with red flags. Middle: the same castle built from
polished golden stone with gold trim and white flags. Right: the same castle
built from black obsidian with dark violet glowing seams and purple flags.
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, saturated but slightly muted earthy colors,
polished casual mobile game sprite art. Solid pure white background. No ground,
no cast shadows, no bases, no frames, no borders, no text, no labels, no numbers.
```

---

# ÖNCELİK 4 — Manzara süsleri

Savaş alanında dört bölgeye dağılan sekiz süs var: ağaç, çam, çalı, kaya,
mantar, buz, kütük, lav.

### 4.1 — `susler.png`

- En-boy oranı: **1:1**
- Çözünürlük: **2K**

```
A game asset sprite sheet of eight fantasy scenery props arranged in a clean 4x2
grid, evenly spaced, each fully isolated with generous empty space around it,
seen from a slight three-quarter front view, no ground, no cast shadows.
Top row left to right: a round leafy broadleaf tree with a brown trunk; a tall
dark green conifer pine tree; a small rounded green bush; a grey boulder rock.
Bottom row left to right: a cluster of red-capped spotted mushrooms; a jagged
pale blue ice crystal formation; a cut tree stump with visible rings; a small
pool of glowing orange lava with dark crusted edges.
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, saturated but slightly muted earthy colors,
polished casual mobile game sprite art. Solid pure white background. No ground,
no cast shadows, no bases, no frames, no borders, no text, no labels, no numbers.
```

---

# ÖNCELİK 5 — Bölge arka planları

Dört bölgenin savaş alanı zemini. Bunlar kesilmeyecek, tam kare olarak
kullanılacak — o yüzden beyaz zemin **istemiyoruz**, tam dolu manzara istiyoruz.

Dördü de: en-boy oranı **4:5**, çözünürlük **2K**.

Ortak kuyruk (her dördünün sonuna ekle):

```
Top-down slightly tilted game battlefield background for a casual mobile tower
defense game, seen from above at a shallow angle. Flat empty terrain with no
buildings, no roads, no paths, no characters, no props in the middle — only the
ground surface and a distant horizon strip at the very top. Clean vector-like
cartoon style with soft cel shading and gentle color variation, no outlines on
the terrain, no text, no labels, no UI, no frames, no vignette.
```

### 5.1 — `bolge_yesil_vadi.png`
```
A bright sunny green valley: lush grass meadow in fresh greens, soft rolling
hills on the horizon, warm blue sky.
```
+ ortak kuyruk

### 5.2 — `bolge_karanlik_orman.png`
```
A gloomy dark forest floor: deep muted green and brown moss and dirt, low mist,
dark treeline silhouette on the horizon, dim overcast sky.
```
+ ortak kuyruk

### 5.3 — `bolge_buz_daglari.png`
```
A frozen mountain plateau: pale blue-white snow and ice, faint frost patterns,
jagged snowy peaks on the horizon, cold pale sky.
```
+ ortak kuyruk

### 5.4 — `bolge_ejder_kalesi.png`
```
A volcanic wasteland: dark cracked scorched rock with faint glowing orange
fissures, ash drifts, distant black volcano silhouettes, deep red smoky sky.
```
+ ortak kuyruk

---

# ÖNCELİK 6 — Yol dokusu

Düşmanların yürüdüğü yol. **Kesintisiz döşenebilir (seamless tileable)** olmalı,
yoksa yol boyunca ek yerleri belli olur.

### 6.1 — `yol_dokulari.png`

- En-boy oranı: **1:1**
- Çözünürlük: **2K**

```
Four seamless tileable texture tiles arranged in a clean 2x2 grid, each tile a
perfect square that tiles seamlessly with itself on all four edges, separated by
a thin white gap. Top-down view of a road surface, flat lighting, no shadows,
no objects, no text.
Top left: a dirt path of packed light brown earth with small pebbles.
Top right: a dark mossy forest trail of damp brown soil with green moss patches.
Bottom left: a packed snow path, pale blue-white with faint footprint texture.
Bottom right: a road of dark volcanic basalt cobblestones with faint orange
glowing cracks between the stones.
Clean vector-like cartoon style with soft cel shading and subtle color
variation, casual mobile game art.
```

---

# ÖNCELİK 7 — Harf taşları ve arayüz

### 7.1 — `harf_tasi.png`

Harf çarkındaki taş. Harf yazısını **kod basacak**, o yüzden taş boş olmalı.

- En-boy oranı: **1:1**
- Çözünürlük: **1K**

```
A game asset sheet showing three versions of the same round rune stone in a
single horizontal row, evenly spaced, fully isolated, seen straight from the
front, no ground, no cast shadows.
All three are IDENTICAL in shape and size: a thick round carved stone disc with
a bevelled rim and a smooth blank flat center, ancient carved rune notches
around the outer rim only. The center must stay completely empty and smooth.
Left: warm sandy beige stone, normal state. Middle: the same stone glowing with
a warm golden light, selected state. Right: the same stone in cold dull grey
with a faint blue-grey tint, locked state.
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, polished casual mobile game sprite art. Solid
pure white background. No text, no letters, no runes in the center, no numbers,
no frames.
```

### 7.2 — `arayuz_simgeleri.png`

- En-boy oranı: **1:1**
- Çözünürlük: **2K**

```
A game UI icon sheet showing twelve icons arranged in a clean 4x3 grid, evenly
spaced, each fully isolated with generous empty space around it, seen straight
from the front, no ground, no cast shadows.
Row 1: a shiny gold coin seen face-on; a faceted cyan gem; a five-pointed gold
star, filled; a five-pointed star outline, empty and dull grey.
Row 2: a closed brass padlock; a glowing yellow light bulb hint icon; two curved
arrows forming a shuffle/refresh circle; a pause icon of two thick rounded
vertical bars.
Row 3: a small red heart; a crossed sword and shield; a rolled parchment scroll;
a treasure chest with gold trim, closed.
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, saturated colors, polished casual mobile game
UI art. Solid pure white background. No text, no labels, no numbers, no frames.
```

### 7.3 — `butonlar.png`

Butonlar Godot'ta **9 dilim (nine-patch)** olarak esnetilecek: köşeler sabit
kalır, ortası uzar. Bu yüzden ortalarının düz ve desensiz olması şart.

- En-boy oranı: **1:1**
- Çözünürlük: **2K**

```
A game UI sheet showing four horizontal rounded rectangle buttons stacked in a
single vertical column, evenly spaced, each fully isolated, seen straight from
the front, no ground, no cast shadows. Every button is a wide rounded rectangle
with the same corner radius and the same height. The middle of each button must
be a completely flat, smooth, uniform color with no gradient, no pattern, no
shine, no highlight, no ornament — only the rounded corners and the outer border
carry detail, because the middle will be stretched.
Button 1: warm gold with a slightly darker gold border and a thin dark navy
outline. Button 2: deep indigo purple with a lighter purple border and a thin
dark navy outline. Button 3: the same indigo purple but visibly darker and
desaturated, disabled state. Button 4: muted stone grey with a darker grey
border and a thin dark navy outline.
Art style: clean vector-like cartoon, thick dark navy outlines, flat cel
shading, polished casual mobile game UI art. Solid pure white background. No
text, no labels, no icons, no numbers, no frames.
```

---

# ÖNCELİK 8 — Mermiler

### 8.1 — `mermiler.png`

- En-boy oranı: **16:9**
- Çözünürlük: **1K**

```
A game asset sheet showing four small projectiles in a single horizontal row,
evenly spaced, each fully isolated with generous empty space between them, seen
from the side, pointing to the right, no ground, no cast shadows.
Left to right: a wooden arrow with grey fletching; a glowing blue arcane orb
with a soft energy trail; a rough grey boulder; a small sparkling green healing
mote with soft glow.
Art style: clean vector-like cartoon, bold rounded chunky shapes, thick dark
navy outlines, soft cel shading, polished casual mobile game sprite art. Solid
pure white background. No text, no labels, no numbers, no frames.
```

---

# Yükleme

Ürettiklerini bu sohbete yükle. Hepsini birden beklemeye gerek yok — bir
öncelik grubunu bitirdiğinde yolla, ben keser, oyuna bağlar, ekran görüntüsüyle
doğrular ve dala gönderirim. Sonra bir sonrakine geçeriz.

Bir görsel beklediğin gibi çıkmazsa at gitsin, tarifi biraz değiştirip yeniden
üret — istemleri buna göre bağımsız yazdım, biri diğerine bağlı değil.
