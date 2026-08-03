# Kelime Kalesi

Türkçe kelime bulmaca + kule savunma hibriti. **Godot 4.3 / GDScript**, dikey
(portrait) Android oyunu.

Oyuncu bir kale lordudur. Ekranın altındaki harf çarkında parmağını kaydırarak
kelime kurar; kelimenin **kategorisi** hangi kulenin inşa edileceğini belirler.
Düşmanlar oyuncu kelime ararken de yürümeye devam eder — kelime bulma hızı =
savunma gücü.

| Kategori | Kule | Özellik |
|---|---|---|
| Hayvan (kurt, at, aslan…) | Okçu Kulesi | Hızlı, tek hedef |
| Doğa (dağ, yağmur, orman…) | Büyü Kulesi | Alan hasarı; hayaletlere işleyen tek kule |
| Nesne/araç (kılıç, çekiç, zırh…) | Mancınık | Yavaş, yüksek hasar; zırh deler |
| Yiyecek (ekmek, bal, elma…) | Şifa Çeşmesi | Kale canını yeniler |
| Kategori dışı geçerli kelime | Genel enerji | Tüm kulelere %5 güç |

Kelime uzunluğu çarpanı: 3 harf 1x · 4 harf 1.5x · 5 harf 2x · 6+ harf 3x.
**7+ harf = "Kadim Kelime"** → ekranı temizleyen ulti büyüsünü şarj eder.

---

## Hızlı başlangıç

```bash
# Godot 4.3 ile projeyi aç
godot --path .

# Testleri çalıştır (604 doğrulama; başarısızlıkta çıkış kodu 1)
godot --headless --path . scenes/Testler.tscn

# Her ekranın PNG görüntüsünü üret (görsel denetim için)
xvfb-run -a godot --path . --resolution 540x960 scenes/EkranGoruntusu.tscn
```

Oyun **tamamen çevrimdışı** oynanabilir. Reklam, satın alma ve bulut kaydı
eklentileri yoksa ilgili sistemler sessizce yerel moda düşer; oynanışta hiçbir
şey kaybolmaz.

---

## Mimari

Kod modülerdir; her sistem ayrı sınıftadır ve sahnelerden bağımsız test edilebilir.

```
scripts/
  core/          Motor bağımsız çekirdek
    TurkishText      Türkçe yerel ayarlı harf dönüşümü ve sıralama
    TrieDict         Sıkıştırılmış DAWG sözlük okuyucu
    GameConfig       Tüm denge sabitleri (kule, düşman, bölge, ekonomi)
    ObjectPool       Düşman/mermi nesne havuzu
    ProcArt          Yordamsal vektör çizim kitaplığı
    UiKit            Ortak arayüz bileşenleri ve palet
  autoload/      Otomatik yüklenen tekil servisler
    WordEngine       Sözlük doğrulama + kategori çözümleme + puanlama
    LevelDB          Seviye verisi
    SaveManager      Yerel kayıt (JSON) + ayarlar (ConfigFile)
    EconomyManager   Altın/elmas, kalıcı yükseltmeler, ipucu
    AudioManager     Müzik + ses efekti havuzu
    Haptics          Titreşim geri bildirimi
    PerfManager      60/30 FPS otomatik ayarı
    AdManager        AdMob sarmalayıcısı (eklenti yoksa devre dışı)
    IapManager       Play Billing sarmalayıcısı (eklenti yoksa devre dışı)
    PlayServices     Play Games: oturum, başarım, bulut kayıt, skor tablosu
    SceneRouter      Ekran geçişleri
  gameplay/
    Battle           Seviye orkestratörü (Oyun.tscn kökü)
    Battlefield      Yollar, yuvalar, kale, havuzlar
    WaveManager      Dalga akışı ve nefes molaları
    TowerSystem      Kelime → inşa puanı → kule inşa/yükseltme
    Tower/TowerSlot/Enemy/Projectile/Castle/PathTrack
  ui/
    LetterWheel      Kaydırmalı harf çarkı
    Hud              Oyun içi arayüz
    TutorialOverlay  İlk 3 seviyenin interaktif öğreticisi
  screens/         Menü, harita, önizleme, sonuç, yükseltme, mağaza, ayarlar, başarımlar
```

**Ekranlar kod içinde kurulur.** Her `.tscn` yalnızca kök düğüm + betikten
oluşur; arayüz `UiKit` üzerinden inşa edilir. Böylece tüm ekranlar aynı paleti
ve dokunma hedefi boyutlarını (en az 96 px) paylaşır ve başsız olarak test
edilebilir.

**Savaş alanı görselleri yordamsaldır.** Kale, kuleler ve düşmanlar ikili
sprite yerine `ProcArt` ile vektör çizilir: her çözünürlükte keskin, APK'da yer
kaplamıyor ve kozmetik renk tek parametreyle değişiyor.

---

## Veri hattı

Oyun verisi `tools/` altındaki betiklerle çevrimdışı üretilir ve sonuç `data/`
altına yazılır. Üretim **deterministiktir**: aynı girdi her zaman aynı çıktıyı verir.

```bash
python3 tools/build_dictionary.py    # ~5 sn
python3 tools/build_categories.py    # ~1 sn
python3 tools/generate_levels.py     # ~4 dk (60 seviyenin çarkını arar)
python3 tools/generate_audio.py      # ~2 sn
```

### Sözlük

`tools/raw_tdk_list.txt` — TDK Güncel Türkçe Sözlük tabanlı 76.186 girdilik ham
liste ([CanNuhlar/Turkce-Kelime-Listesi](https://github.com/CanNuhlar/Turkce-Kelime-Listesi)).

`build_dictionary.py` bu listeyi temizler:

| Elenen | Adet | Neden |
|---|---|---|
| Özel isim | 2.620 | Oyunda kullanılmaz |
| Çok kelimeli girdi ("aba güreşi") | 14.606 | Tek kelimelik çarkta kurulamaz |
| Uzunluk sınırı dışı | 533 | 2–16 harf dışında |

Kalan **58.304 kelime** minimal DAWG (Daciuk artımlı algoritması) olarak
**309 KB**'lık ikili dosyaya sıkıştırılır. Düzeltme işaretli harfler oyun
alfabesine indirgenir (`kâğıt` → `kağıt`), böylece çarkta düzeltme işaretli taş
gerekmez.

> Spesifikasyondaki 60–80 bin hedefi tek kelimelik girdiler için 58 bin olarak
> gerçekleşti; aradaki fark, swipe mekaniğinde kurulamayan çok kelimeli TDK
> girdilerinden geliyor.

**Çalışma anı başarımı:** sözlük tek parça `PackedByteArray` olarak okunur,
düğüm nesnesi ayrılmaz. Ölçülen değerler (test koşusundan):

* yükleme: **~2 ms**
* tek kelime doğrulama: **~15 µs** (spesifikasyon hedefi <5 ms)

### Kategori sözlükleri

`tools/category_seeds.py` içinde elle derlenmiş kelime tohumları bulunur. Her
tohum ana sözlükle doğrulanır; sözlükte olmayanlar rapor edilip elenir, birden
çok kategoriye giren kelimeler öncelik sırasına göre tek kategoriye atanır.

| Kategori | Kelime | Spesifikasyon hedefi |
|---|---|---|
| hayvan | 257 | ~500 |
| doga | 292 | ~600 |
| nesne | 363 | ~800 |
| yiyecek | 230 | ~400 |
| **toplam** | **1.142** | ~2.300 |

> Listeler hedefin altında. Türkçe kategori sözlükleri elle derlendiği için
> genişletme açık uçlu bir iştir: `tools/category_seeds.py` dosyasına kelime
> eklenip `build_categories.py` yeniden çalıştırılması yeterlidir — sözlükte
> olmayan kelimeler otomatik elendiği için hatalı giriş riski yoktur.
> Mevcut listeler oynanış için yeterli: seviyelerin çarkından hedef
> kategorilerde ortalama **11 kelime** türetilebiliyor.

### Seviyeler

`generate_levels.py` 60 seviyenin harf çarkını **rastgele değil küratörlü**
seçer. Her çark, sözlükten seçilen bir "kaynak kelime"nin harflerinden oluşur ve
şu ölçütler sağlanana kadar adaylar elenir:

* çarktan türetilebilen toplam kelime ≥ 8–14 (çark boyutuna göre)
* hedef kategorilerden türetilebilen kelime ≥ 3–7
* her hedef kategoriden en az bir kelime
* aynı harften en fazla iki tane, en az iki farklı sesli harf
* 7+ harfli çarklarda en az bir Kadim Kelime (kaynak kelimenin kendisi garanti eder)

Ölçüt sağlanamazsa kademeli gevşetme uygulanır ve hangi seviyelerin gevşetildiği
raporlanır. Üretilen veri:

* çarktan türetilebilen kelime: en az 14, ortalama 82
* hedef kategoriden kelime: en az 3, ortalama 11

Zorluk eğrisi: 5 harfli çark → 8 harfe çıkar (seviye 1/13/25/37), yol sayısı
1 → 2 (seviye 21) → 3 (seviye 41), düşman tipleri sırayla açılır
(goblin 1, ork 4, zırhlı trol 9, hayalet 16, harf hırsızı 22), her 15. seviye
bölgeye özel faz değiştiren boss.

### Ses

`generate_audio.py` 13 ses efektini ve 2 müzik döngüsünü standart kütüphaneyle
(`wave` + `math`) sentezler — depoda telifi belirsiz ikili ses dosyası yoktur,
tonlar tek dosyadan ayarlanır. Toplam 1,3 MB.

---

## Test

```bash
godot --headless --path . scenes/Testler.tscn
```

604 doğrulama; başarısızlıkta çıkış kodu 1 (CI'da kullanılabilir). Kapsam:

* **Türkçe harf dönüşümü** — `i↔İ`, `I↔ı`, düzeltme işareti katlama, alfabe sıralaması
* **Trie sözlük** — bilinen kelimeler var, uydurma kelimeler yok, ön ek sorgusu
* **Başarım** — doğrulama süresi ölçülür ve 5 ms sınırına karşı doğrulanır
* **Çark çözücü** — türetilen her kelime hem sözlükte hem çark harflerinden kurulabilir
* **Kelime motoru** — kategori/kule eşlemesi, uzunluk çarpanları, Kadim Kelime eşiği,
  tekrar eden ve geçersiz kelimelerin reddi
* **Seviye verisi** — 60 seviyenin tamamı için çark boyutu, dalga, boss işareti,
  düşman tipleri ve **kayıtlı çözüm kelimelerinin gerçekten türetilebilirliği**
* **Ekonomi** — yükseltme maliyet eğrisi, yıldız ödülü, tekrar oynama indirimi
* **Kayıt** — yıldızın düşmemesi, kilit açma kuralları, diskten geri okuma
* **Uçtan uca savaş** — sahne kurulumu, yuvaların yolun üstüne düşmemesi,
  kelimeyle kule inşası, kulenin menzildeki düşmana hasar vermesi,
  hayalet bağışıklığı, trol zırhı ve mancınık zayıflığı, harf hırsızının
  harf kilitleyip ölünce açması, ultinin ekranı temizlemesi

Görsel denetim için `scenes/EkranGoruntusu.tscn` her ekranın PNG'sini üretir.

---

## Android derlemesi

Hedef: **min API 24**, target API 34, `arm64-v8a` + `armeabi-v7a` + `x86_64`,
dikey kilitli, immersive mod.

`export_presets.cfg` hazırdır. Derlemek için:

1. **Godot dışa aktarma şablonlarını** kur (Editor → Manage Export Templates).
2. **Android SDK + JDK 17** kur ve Editor Settings → Export → Android altında
   SDK yolunu göster.
3. Project → Install Android Build Template (eklenti kullanacaksanız zorunlu).
4. İmzalama anahtarını üret ve `export_presets.local.cfg` içinde tanımla
   (bu dosya `.gitignore`'dadır — anahtar deposuna asla depoya girmez):

```bash
keytool -genkeypair -v -keystore kelime_kalesi.keystore \
  -alias kelimekalesi -keyalg RSA -keysize 2048 -validity 10000
```

5. Dışa aktar:

```bash
godot --headless --path . --export-release "Android" build/kelime_kalesi.aab
```

### Android eklentileri

Üç servis eklenti gerektirir. **Hiçbiri zorunlu değildir** — eklenti yoksa
`Engine.has_singleton()` kontrolü başarısız olur ve servis sessizce yerel moda
düşer, oyun tam oynanabilir kalır.

| Servis | Eklenti tekili | Ne olur (eklenti yoksa) |
|---|---|---|
| `AdManager` | `AdMob` | Reklam gösterilmez; ödüllü video isteği `false` döner ve ödül verilmez |
| `IapManager` | `GodotGooglePlayBilling` | Mağaza ürünleri listelenir ama satın alma "kullanılamıyor" döner |
| `PlayServices` | `GodotPlayGameServices` | Başarımlar ve kayıt yalnızca cihazda tutulur |

`AdManager.AD_UNITS` içindeki kimlikler Google'ın **resmî test kimlikleridir**;
yayına çıkmadan önce Play Console'daki gerçek birim kimlikleriyle değiştirin.

---

## Ekonomi ve gelir modeli

* **Altın** (soft): seviye sonu kazanılır, kalıcı yükseltmelere harcanır.
* **Elmas** (hard): IAP ile alınır, ipucu ve kozmetiklerde kullanılır.

**Reklam kuralları** (`AdManager` içinde uygulanır):

* Ödüllü video: yenilgide "devam et", günlük sandık x2, ekstra ipucu.
* Geçiş reklamı: **3 seviyede bir, yalnızca sonuç ekranında** — oyun ortasında asla.
* "Reklamları Kaldır" satın alımı geçiş reklamlarını kapatır, ödüllü videolar kalır.

**Pay-to-win yoktur.** Kalıcı yükseltmeler yalnızca **altınla** alınır; elmas
yalnızca ipucu ve **kozmetiklere** gider. Kozmetikler yalnızca renk değiştirir —
`EconomyManager.cosmetic_color()` dışında oynanışa hiçbir yerden dokunmazlar.
Bu kural testle de sabitlenmiştir (`tower_damage_multiplier` yalnızca yükseltmeye bağlı).

**İpucu:** günde 3 ücretsiz hak, sonrası 8 elmas. Ücretsiz haklar `SaveManager`
içinde tarih başına sıfırlanır.

---

## Ekran düzeni

Dikey 1080×1920 referans, tüm en-boy oranlarına duyarlı:

```
0.00 ─┬─ Üst şerit: duraklat, kale canı, dalga
      │
      │  SAVAŞ ALANI — yollar, kule yuvaları, düşmanlar, kale
      │
0.53 ─┼─ HUD bandı: 4 kule inşa göstergesi, combo, kelime, İpucu/Karıştır/Ulti
0.685 ┼─
      │  HARF ÇARKI — 5–8 rünik taş, kaydırmalı seçim
1.00 ─┴─
```

HUD savaş alanının üstüne binmez; üçü ayrı bantlarda durur. Harf çarkının
yarıçapı en dar kenara göre sınırlanır, böylece taşlar hiçbir cihazda ekran
dışına taşmaz.

---

## Bilinen sınırlar

* **Kategori sözlükleri hedefin altında** (1.142 / ~2.300). Genişletme yolu
  yukarıda anlatıldı; oynanış mevcut listelerle akıcı.
* **Sonsuz mod yok.** Skor tablosu altyapısı (`PlayServices.LEADERBOARDS`) ve
  `submit_score()` hazır, mod eklendiğinde bağlanması yeterli.
* **Kozmetikler renk düzeyinde.** Farklı siluetler `ProcArt` içine yeni çizim
  fonksiyonu eklenerek genişletilebilir.
* **Yerelleştirme altyapısı hazır ama tek dil.** Metinler şu an kaynak içinde;
  `ayarlar.dil` anahtarı ve dil ekranı mevcut, çeviri dosyası eklendiğinde
  `tr()` çağrılarına geçilebilir.
* Bu depoda **APK üretilmedi** — Android SDK gerektiriyor. `export_presets.cfg`
  doğrulandı (Godot presetten yalnızca SDK eksikliği nedeniyle şikayet ediyor).

---

## Lisans ve kaynaklar

* Kelime listesi: TDK Güncel Türkçe Sözlük tabanlı açık liste
  ([CanNuhlar/Turkce-Kelime-Listesi](https://github.com/CanNuhlar/Turkce-Kelime-Listesi)).
* Görseller ve sesler bu depoda üretilir; dışarıdan telifli varlık kullanılmaz.
