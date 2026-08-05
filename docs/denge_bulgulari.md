# Denge bulguları — 60 bölümün otomatik taraması

Bu belge `tools/denge_taramasi.sh` ile alınmış ölçümleri ve bunlardan çıkan
sonuçları içerir. Amaç: hangi bölümlerin bir insan için geçilemez olduğunu
elle oynamadan bulmak.

## Yöntem

İki profil çalıştırılır, ikisi de gerçek dokunma olayları üretir:

| profil | ne yapar | neyi ölçer |
|---|---|---|
| **bot** (varsayılan) | bölümün bütün çözüm kelimelerini bilir, en uzun kategori kelimelerini önce yazar, hiç hata yapmaz, parmağı 2100 px/sn | bölüm teorik olarak geçilebilir mi |
| **insan** (`--insan`) | uzunluğa göre sınırlı dağarcık, somut isimlere öncelik, dakikada ~11 kelime, %18 yanlış deneme, 850 px/sn parmak, kule için 0.9–2.4 sn tepki, ultiyi %30 kaçırma | ortalama bir oyuncu geçebilir mi |

İkisi de `--yukseltme=oto` ile, o bölüme kadar biriktirilmiş makul yükseltme
seviyesiyle oynar.

**İnsan profilinin sayıları ölçüm değil, modeldir.** Gerçek oyuncu verisi
yok; amaç mutlak doğruluk değil, altmış bölümü aynı ölçütle karşılaştırmak.
Mutlak kazan/kaybet sınırından çok, bölümlerin birbirine göre sıralaması
güvenilir.

## Sonuç

- **bot: 60 bölümün 59'unu kazanıyor** (yalnız 60. bölüm kaybediliyor)
- **insan profili: 60 bölümün 16'sını kazanıyor**

### İnsan profilinin kazandığı bölümler
1, 2, 3, 4, 6, 8, 9, 10, 11, 12, 14, 15, 19, 25, 27, 46

### ZOR — bot geçiyor, insan geçemiyor (43 bölüm)
5, 7, 13, 16, 17, 18, 20, 21, 22, 23, 24, 26, 28, 29, 30, 31, 32, 33, 34, 35,
36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 47, 48, 49, 50, 51, 52, 53, 54, 55,
56, 57, 58, 59

### BOZUK — ikisi de geçemiyor (1 bölüm)
60 — bot bile kaybediyor: `kelime=49 oldurulen=46`, kale düşüyor.

### Kıl payı kazanılanlar
19 (%13 canla)

13. bölümden sonra insan profilinin kazanması istisna: 60 bölümün 43'ü
"bot geçiyor, insan geçemiyor" durumunda.

## Sebep analizi

Üç hipotez tek tek ölçüldü.

### 1. "Oyuncu yeterince hızlı kelime bulamıyor" — HAYIR

Bot, dakikada 10 kelimeye kısıtlandığında (`--kelime-hizi=10`) hâlâ rahat
kazanıyor:

| bölüm | 30 kel/dk | 20 kel/dk | 14 kel/dk | 10 kel/dk |
|---|---|---|---|---|
| 8 | 3★ %100 | 3★ %100 | 3★ %100 | 3★ %100 |
| 20 | 3★ %100 | 2★ %66 | 1★ %40 | 1★ %45 |
| 35 | 3★ %100 | 3★ %100 | 3★ %100 | 3★ %100 |
| 50 | 3★ %100 | 3★ %100 | 3★ %100 | 3★ %100 |

Yani tempo tek başına duvar değil.

### 2. "Oyuncu doğru kelimeleri seçemiyor" — TEK BAŞINA HAYIR

Botun kelime planı + insanın temposu/hataları/tepkisi ile 20, 35 ve 50.
bölümler yine kaybediliyor.

### 3. İkisinin birleşimi — EVET, ÇÜNKÜ MARJ YOK

Ekonomi son derece tepe ağırlıklı:

- 6 harfli **kategori** kelimesi: `48 × 3.0 = 144` puan, tek kelimede 100
  eşiğini aşıyor — anında kule.
- 4 harfli **kategori dışı** kelime: `48 × 1.5 × 0.05 = 3.6` puan (her kule
  tipine ayrı ayrı) — yaklaşık **40 kat** zayıf.

Bir uzun kategori kelimesi ~40 kısa kelimeye bedel. Oyuncu uzun kategori
kelimelerini bulamazsa kule dikemiyor; kule dikemeyince hiçbir düşman
ölmüyor. Ölçümlerde bunun izi net: kaybedilen bölümlerin çoğunda
`oldurulen=0`.

İlk sekiz bölümde çözüm listesinde ~20 kelime var ama **yalnız 3'ü kategori
kelimesi**. Oyuncunun o üçünden ikisini bulması pratikte zorunlu.

## Denenen düzeltmeler (henüz uygulanmadı)

| deneme | sonuç |
|---|---|
| `GENERAL_ENERGY_RATIO` 0.05 → 0.20 | yalnız 8. bölüm kazanılır hâle geldi |
| `GENERAL_ENERGY_RATIO` 0.15 + `BUILD_POINT_THRESHOLD` 100 → 70 | denenen 5 bölümün 2'si (25, 50) kazanılır hâle geldi |

Yani tek bir sabiti oynatmak yetmiyor; dalga baskısı, kategori kelimesi sayısı
ve inşa ekonomisi birlikte ele alınmalı.

## Tam tablo

```
 blm              insan                bot  harf  kat durum
------------------------------------------------------------------------
   1  ZAFER 3* can=%100  ZAFER 3* can=%100     5    3 TAMAM
   2  ZAFER 3* can=%100  ZAFER 3* can=%100     5    3 TAMAM
   3   ZAFER 1* can=%28  ZAFER 3* can=%100     5    3 TAMAM
   4   ZAFER 2* can=%75  ZAFER 3* can=%100     5    3 TAMAM
   5 YENILGI kel=9 old=7  ZAFER 3* can=%100     5    3 ZOR
   6  ZAFER 3* can=%100  ZAFER 3* can=%100     5    3 TAMAM
   7 YENILGI kel=13 old=17  ZAFER 3* can=%100     5    3 ZOR
   8   ZAFER 1* can=%27  ZAFER 3* can=%100     5    3 TAMAM
   9   ZAFER 1* can=%49  ZAFER 3* can=%100     5    5 TAMAM
  10   ZAFER 2* can=%78  ZAFER 3* can=%100     5    5 TAMAM
  11  ZAFER 3* can=%100  ZAFER 3* can=%100     5    4 TAMAM
  12   ZAFER 1* can=%43   ZAFER 2* can=%54     5    4 TAMAM
  13 YENILGI kel=7 old=0  ZAFER 3* can=%100     6    6 ZOR
  14  ZAFER 3* can=%100  ZAFER 3* can=%100     6    7 TAMAM
  15  ZAFER 3* can=%100  ZAFER 3* can=%100     6    5 TAMAM
  16 YENILGI kel=15 old=21   ZAFER 3* can=%87     6    5 ZOR
  17 YENILGI kel=11 old=15  ZAFER 3* can=%100     6    5 ZOR
  18 YENILGI kel=15 old=34  ZAFER 3* can=%100     6    8 ZOR
  19   ZAFER 1* can=%13   ZAFER 3* can=%87     6    5 TAMAM
  20 YENILGI kel=7 old=0  ZAFER 3* can=%100     6    5 ZOR
  21 YENILGI kel=9 old=12   ZAFER 3* can=%87     6    8 ZOR
  22 YENILGI kel=5 old=0  ZAFER 3* can=%100     6    8 ZOR
  23 YENILGI kel=14 old=34   ZAFER 3* can=%87     6    6 ZOR
  24 YENILGI kel=13 old=14  ZAFER 3* can=%100     6    6 ZOR
  25   ZAFER 2* can=%74   ZAFER 1* can=%21     7   13 TAMAM
  26 YENILGI kel=8 old=19  ZAFER 3* can=%100     7   10 ZOR
  27   ZAFER 1* can=%34   ZAFER 3* can=%87     7   11 TAMAM
  28 YENILGI kel=13 old=32  ZAFER 3* can=%100     7   10 ZOR
  29 YENILGI kel=14 old=42  ZAFER 3* can=%100     7   13 ZOR
  30 YENILGI kel=9 old=5  ZAFER 3* can=%100     7   10 ZOR
  31 YENILGI kel=8 old=2  ZAFER 3* can=%100     7   11 ZOR
  32 YENILGI kel=6 old=0  ZAFER 3* can=%100     7   10 ZOR
  33 YENILGI kel=6 old=1   ZAFER 1* can=%25     7   12 ZOR
  34 YENILGI kel=15 old=44  ZAFER 3* can=%100     7   11 ZOR
  35 YENILGI kel=13 old=45  ZAFER 3* can=%100     7    9 ZOR
  36 YENILGI kel=12 old=16  ZAFER 3* can=%100     7    9 ZOR
  37 YENILGI kel=9 old=11  ZAFER 3* can=%100     8   19 ZOR
  38 YENILGI kel=21 old=63   ZAFER 1* can=%19     8   16 ZOR
  39 YENILGI kel=13 old=35   ZAFER 3* can=%90     8   15 ZOR
  40 YENILGI kel=14 old=4  ZAFER 3* can=%100     8   13 ZOR
  41 YENILGI kel=6 old=0  ZAFER 3* can=%100     8   18 ZOR
  42 YENILGI kel=7 old=7   ZAFER 1* can=%38     8   20 ZOR
  43 YENILGI kel=14 old=43   ZAFER 1* can=%25     8   20 ZOR
  44 YENILGI kel=14 old=33  ZAFER 3* can=%100     8   19 ZOR
  45 YENILGI kel=8 old=0  ZAFER 3* can=%100     8   21 ZOR
  46  ZAFER 3* can=%100  ZAFER 3* can=%100     8   19 TAMAM
  47 YENILGI kel=10 old=15   ZAFER 2* can=%76     8   18 ZOR
  48 YENILGI kel=8 old=0   ZAFER 1* can=%14     8   17 ZOR
  49 YENILGI kel=18 old=40  ZAFER 3* can=%100     8   16 ZOR
  50 YENILGI kel=14 old=23  ZAFER 3* can=%100     8   18 ZOR
  51 YENILGI kel=10 old=2  ZAFER 3* can=%100     8   19 ZOR
  52 YENILGI kel=7 old=10  ZAFER 3* can=%100     8   19 ZOR
  53 YENILGI kel=15 old=45  ZAFER 3* can=%100     8   13 ZOR
  54 YENILGI kel=10 old=7  ZAFER 3* can=%100     8   19 ZOR
  55 YENILGI kel=13 old=47   ZAFER 3* can=%88     8   18 ZOR
  56 YENILGI kel=11 old=31  ZAFER 3* can=%100     8   18 ZOR
  57 YENILGI kel=8 old=7  ZAFER 3* can=%100     8   18 ZOR
  58 YENILGI kel=5 old=3  ZAFER 3* can=%100     8   17 ZOR
  59 YENILGI kel=20 old=59   ZAFER 3* can=%88     8   16 ZOR
  60 YENILGI kel=9 old=17 YENILGI kel=49 old=46     8   16 BOZUK
```

## Yeniden üretmek için

```bash
GODOT=/yol/godot tools/denge_taramasi.sh --insan --yukseltme=oto
GODOT=/yol/godot tools/denge_taramasi.sh --yukseltme=oto
python3 tools/denge_raporu.py /tmp/kk_denge
```


---

# GÜNCELLEME — denge elden geçirildikten sonra

Yukarıdaki ölçümler düzeltme ÖNCESİ durumdur; kayıt olarak bırakıldı.
Aşağıdaki bölüm, kelime listeleri ve denge elden geçirildikten sonraki
durumu anlatır.

## Yapılanlar

| değişiklik | eski | yeni |
|---|---|---|
| kategori dışı kelime payı | %5 | %16 |
| uzunluk çarpanı (6+ harf) | 3.0x | 2.3x |
| kelime taban puanı | 48 | 56 |
| en fazla dalga | 8 | 7 |
| düşman gücü eğimi | 0.030 (son bölüm 2.77x) | 0.021 (2.24x) |
| grup başına düşman artışı | index//2 | index//3 |
| ilk dalga öncesi hazırlık | 3 sn | 14 sn |
| dalga arası mola | 5 sn | 9 sn |
| düşmanın kaleye hasarı | — | ~%27 azaltıldı |
| kale canı eğimi | 0.012 (46. bölüm 1.54x) | 0.020 (1.90x) |

Ayrıca kelime listeleri elden geçti: küfür sözlükten çıkarıldı, çarklar
"yaygın kelime" oranına göre seçilir oldu ve ilerleme göstergeleri yalnız
bulunabilir kelimeleri hedef gösteriyor.

## Sonuç

**İnsan profili: 14/60 → 57/60.**

| yıldız | bölüm sayısı |
|---|---|
| 3 yıldız | 46 |
| 2 yıldız | 4 |
| 1 yıldız | 5 |
| kaybedildi | 3 |

Kaybedilenler: 37, 54, 56.

Üçü de yapısal olarak bozuk değil, sınırda:

- **37**: üç koşudan birinde kazanıldı (1 yıldız, %2 can).
- **54 ve 56**: üç koşuda da kaybedildi, ama komşularıyla (53, 55, 57)
  dalga sayısı, düşman sayısı, güç ve kale canı bakımından neredeyse
  birebir aynı — 53, 55 ve 57 kazanılıyor. Fark dalga tasarımından değil,
  o çarkın kelime bileşiminden geliyor.

## Açık kalan gözlem

Yıldız dağılımı hâlâ üst uca yığılı: 60 bölümün 46'sı 3 yıldız. Yıldız
eşikleri kalan cana bakıyor (`STAR_THRESHOLDS = [0.0, 0.5, 0.8]`) ve
savunma zamanında kurulduğunda pratikte hiç sızma olmuyor. Eşikleri
sıkılaştırmak (örneğin 0.65 / 0.92) yıldızı anlamlı kılar ama bölge açma
gereksinimlerini (22 / 55 / 92 yıldız) de etkiler; ikisi birlikte
ayarlanmalı. Bu değişiklik YAPILMADI.
