#!/usr/bin/env python3
"""Küratörlü kelime listeleri: engellenenler ve yaygın çekirdek.

İki ayrı sorunu çözer:

1. KUFUR — sözlüğe hiç girmemesi gereken kelimeler. TDK listesi bir dil
   sözlüğü olduğu için argo ve müstehcen maddeleri de içeriyor; 1. bölümün
   çözüm listesinde "sik" vardı. Bunlar build_dictionary.py aşamasında
   atılır, yani oyuncu yazamaz ve hiçbir bölümün çözümünde görünmez.

   Liste TAM EŞLEŞMEdir, alt dize değil: "sikke" (para), "boks", "yavşan"
   (bitki), "fahiş" (aşırı), "sıçan", "kaşar" (peynir), "götürmek" gibi
   masum kelimeler elenmemeli.

2. YAYGIN — ortalama bir yetişkinin bildiği kelimeler. TDK listesi ağzı,
   eskimiş ve teknik maddelerle dolu: 1. bölümün çözümünde "enik", "esik",
   "kesi", "nesi", "sek", "seki"; 4. bölümde "gayr", "gayrı", "gır", "ıra",
   "yır" vardı. Oyuncu bunları bulamayacağı için "3 harf 0/7" gibi ilerleme
   göstergeleri tamamlanamıyordu.

   Bu liste kelimeleri YASAKLAMAZ. generate_levels.py çarkları seçerken
   yaygın kelime oranını gözetir ve ilerleme göstergeleri yalnız yaygın
   kelimeleri sayar; oyuncu "melas" bulursa yine puan alır, sadece hedef
   olarak gösterilmez.

   Liste eksiksiz değil, eksik olması da sorun değil: eksiklik ölçütü
   sıkılaştırır, yanlışlamaz. Kategori listeleri (data/categories, 1142
   somut isim) bu listeye otomatik eklenir, o yüzden burada somut isimler
   değil günlük soyut/sıfat/fiil dağarcığı toplanmıştır.
"""
from __future__ import annotations

# --------------------------------------------------------------------------
# 1. Sözlükten tamamen çıkarılanlar
# --------------------------------------------------------------------------

## Müstehcen ve ağır hakaret. Tam eşleşme.
KUFUR = {
    # cinsel içerikli kök ve türevleri
    "sik", "sikme", "sikmek", "siktirici", "siktirme", "siktirmek",
    "siklememe", "siklememek", "sikleme", "siklemek",
    "am", "amcık", "yarak", "yarrak", "taşak", "taşaklı",
    "dalyarak", "dalyaraklık",
    "penis", "vajina", "testis",
    # dışkı
    "bok", "boklama", "boklamak", "boklanma", "boklanmak", "boklaşma",
    "boklaşmak", "boklu", "bokluk", "boktan",
    "göt", "götlek", "götveren",
    "osurgan", "osurma", "osurmak", "osurtma", "osurtmak", "osuruk", "osuruş",
    "sıçma", "sıçmak",
    # ağır hakaret
    "orospu", "orospuluk", "orostopol", "orostopolluk",
    "puşt", "puştluk", "ibne", "ibnelik",
    "kahpe", "kahpece", "kahpecik", "kahpelenme", "kahpelenmek",
    "kahpeleşme", "kahpeleşmek", "kahpelik",
    "piç", "piçleşme", "piçleşmek", "piçlik",
    "pezevenk", "pezevenklik",
    "kaltak", "kaltaklık", "kaltakçı",
    "sürtük", "sürtükleşme", "sürtükleşmek", "sürtüklük",
    "yavşak", "şıllık", "dallama",
    "kancık", "kancıklık", "kancıkça",
    # fuhuş
    "fahişe", "fahişelik", "kerhane", "kerhaneci", "genelev", "fuhuş",
    "jigolo", "jigololuk",
}


# --------------------------------------------------------------------------
# 2. Yaygın çekirdek
# --------------------------------------------------------------------------

## Üç harfliler. Erken bölümlerin belkemiği: 5 harfli çarklardan en çok
## bunlar türetiliyor. Sözlükteki 736 üç harfli maddenin içinden seçildi.
YAYGIN_3 = """
acı ada adi ait akü alt ama ana ani anı ara art arz arı asa asi ata ayı
azı açı ağa aşk aşı bal bar bas bat bay bağ baş bej bel ben bey bez beş
bin bir bit biz bol bot boy boz boş bul but buz cam can caz cep cin cip
cop dal dam dar dağ dev dik dil din dip diz diş don doz dua dul dut duy
duş döl dün düz düş dış ebe ego ela fal fan far fay fen fes fil fit fiş
fok fon gaf gar gaz gen gez geç giz gol gri gök göl göz göç gül gün gür
güz güç hac hak hal ham han hap has hat haz haç hem hep her hey his hit
hiç hop hoş huy hür hız iki ile ilk ima iri iyi jel jet kal kan kap kar
kas kat kay kaz kaç kaş kek kel kes kez kil kim kin kir kit kod kok kol
kot koy koz koç kul kum kur kuş kök kör köy köz küf kül küp küs kıl kır
kız kıç kış laf lav leş lif lig loş mal mat maç maş meç mil mis mit mor
mum muz nal nar naz nem net not nur oba oda oje ora org ova oya pak pas
pat pay pek pes peş pil pis pop poz pul put raf rap ray ret rol ruh ruj
saf sal sap say saz saç sağ sel sen ses set siz sis sol son sos soy sur
suç söz süs süt sık sır tak tam tas tat tay taç taş tef tek tel ten ter
tez tip tok ton top toy toz tur tuz tuş tül tüm tüp tür tüy tıp tır ulu
var vay yak yan yar yas yat yay yaz yağ yaş yel yem yen yer yok yol yön
yük yün yüz yıl zam zar zil zor zıt çak çal çam çan çap çay çağ çek çim
çip çit çiğ çok çöl çöp çöz çıt öcü ölü örf öte üst ütü üye ırk ısı şah
şal şef şen şey şiş şok şov şut şık
"""

## Oyunda geçen ama ilk taramada gözden kaçan yaygın kelimeler. Bölüm
## verisi üretildikten sonra "nadir" işaretlenenler gözden geçirilerek
## eklendi: "yazık", "ilke", "elçi", "yargı", "çark" gibi günlük
## kelimeler nadir sayılıyordu.
YAYGIN_EK = """
ark akor karo akar kart alo ayık kola atık bor orta akma aks askı barok
kıta aktar artı arş balo rakı aşık karlı karma kayma kazı kıt arsa aylak
ilke kaba karış kırma kıyas yaka yarı çakı çark çıkar çırak yazık
ant ayıp baz katlı kayış odak razı sıra alma alçı asma asmak atış aylık
bank baron bazı borç boya dokuz ekin elçi ilçe kalma kano kayıp kısma
lakap link marş nikel oraya parka takı zorba çile çıta alarm aptal aroma
arzu arıza asla azot batık kapma kapış kast kasıt koma koyma koşma layık
mayo mola moral ordu paslı plak sapık sayma sayım sıkma tane tank tarz
yakma yama yargı yarma yarık yarın yasak çarpı ıslak şato şayet mask
kadı kobay kont krom klasik obur topak tura sakar sarp rant şark çolak
yatık yamak yalak batıl bodur bunak duba azat ayet asal aruz ardıl
kaplı kayan klan klas klon kramp opal plaza star zat kura lot aşma aşmak
alto arap arma balya kalıt opak pakt tork çakır çıra ırak arık kota
katar kırat ayrık kayır oral aba dok ekli koyar mark çat çeki apak yakı
"""


## Dört harf ve üstü: günlük dağarcık. Somut isimler kategori listelerinden
## (data/categories) geldiği için burada sıfat, zarf, soyut isim, fiil ve
## gündelik kalıplar toplanmıştır.
YAYGIN_UZUN = """
abla acele acemi açık açlık ada adam adet adil adım afiş ahır aile
ajan akıl akım akın akış aklı akort aksi aktif alan alay albay alçak
alev alıcı alım alın alkış almak almanak alt altı altın ana anahtar
anket anlam anne antik apartman araba aralık arama aramak arka arkadaş armut
artık artış asker asıl asır aslan astar aşama aşçı aşırı ata atak ateş
atlas atlet atlı atma atmak avans avlu avukat ayak ayar ayaz ayın ayna
ayrı ayrım aynı azalma azap azgın bacak bacak badem bahar bahçe bakan
bakır bakış bakma bakmak bakteri balık balkon balon banka bant baraj
barış basamak basit basın baskı basma basmak baston başak başarı başka
batak batı bayan bayat bayrak bebek bedel beden bekar bekçi belge belirti
belki bellek bencil benzer beraber berbat bereket besin beton beyaz beyin
biber biçim bilek bilet bilgi bilim bilinç bilmek bina binek binmek biraz
birey birim birlik bisiklet bitki bitmek biçki blok boğaz bolluk bomba
bordo borsa boyun boşluk bölge bölme bölüm bölünme börek bulut bulmak
bulut burun buyruk buzul bücür büfe bütün büyü büyük büyüme
cadde cambaz camlı canlı cazip cebir cehalet cennet cesaret cevap cevher
cihaz cilt cimri cinsel civar coşku cömert cuma cümle cüzdan dadı dahi
dakika damar damat damla danış dans dantel darbe darı davet davul dayak
dayanak dede dedikodu defa defter değer değil değişim delik delil deli
demek demir demlik deneme deney denge deniz depo deprem derece derin ders
dert destek deste detay devam devlet devre dikey dikiş dikkat dilek dilim
dinamik dinç direk direnç diriliş dirsek dizgi doku doktor dolap dolar
dolay dolgu dolu domates dost dosya doğa doğal doğru doğum dua duman
durak durum duruş duvar duygu düdük düello düğme düğün dükkan dünya düşük
düşman düşünce düzen düzey ecza edebi efsane eğim eğitim eğlence ekip
eklem ekmek ekran eksen eksik ekstra elbise elden eldiven elek elem
eleman elma emek emeklilik emin emir emlak enerji engel enlem erik
erkek erken eser esas esir eski esnaf esprili etek etken etki etkili etli
etnik etraf ev evlat evlilik evrak evren fabrika faiz fakat fakir fanila
fark fasulye fatura fayda fazla felaket felsefe fener ferah fidan fikir
filiz film final firma fiyat fizik fişek flama fotoğraf fren fuar futbol
gaddar galiba galip gayret gazete gazoz gebe gebermek gece geçen geçit geçiş
gelecek gelin gelir geliş gemi genel geniş gerek gerçek gergin geri
gevşek gezgin gezi gibi gider giriş girdi gizem gizli gonca gurbet gurur
güneş günlük güven güçlü güzel gölge gömlek gönül görev görgü görme
görüntü görüş gösterme gövde gübre gümüş günah gündem güneş gürültü hafif
hafta hakem hakim haklı halat halka halı hamak hamur hanım harcama
hareket harf harika harita hasar hasret hasta hatta hatıra hava havlu
havuz hayal hayat hayır hayvan hazine hazır hedef hediye hekim helal
hemen henüz hesap heyecan hikaye hile hisse hoca hukuk hurma huzur hücre
hüküm hüner ideal iftar iğne ihmal ikram ilaç ilan ileri ilgi ilişki ilkbahar
imza inanç ince inek insan inşaat ipek irade isim istek isyan işaret işlem
işçi kabuk kabul kaburga kaçak kader kadın kadro kafa kafes kağıt kahve
kalabalık kalas kalbi kalkma kale kalem kalın kalıp kalite kalkan kalp
kamera kamp kamu kanal kanat kanepe kanıt kapak kapı kaplan kaplama kaptan
kar kara karar karga karışım karne karşı kasa kasap kasım kasket kaset
kaslı kaset katkı katman katı kavga kavram kayak kayık kayıt kaza kazak
kazanç keder kedi kelime kemer kemik kenar kendi kepçe kere kesim kesin
keskin keten keyif kısa kısım kıvırcık kıyafet kıyı kız kızak kilit kilo
kilise kimlik kira kiraz kirli kişi kitap kolay koltuk komik konak konser
konu konuk konum kopya korku kral kravat kredi krem kriz kule kulüp kumaş
kunduz kupa kural kurbağa kurdele kurşun kurt kuruluş kutu kuvvet kuzen
kuzey küçük küfe kültür küme küpe kürek kütük laboratuvar lamba lastik
lehçe leke levha liman lise liste lokanta lokma lüks maaş macera madde
maden mahalle makam makarna makas makine mandal manevi mantık manzara
marka market martı masa masal maske masraf matbaa mavi mayıs mazi mecbur
medya melek memnun memur mendil menü merak merdiven merkez mermer mesaj
meslek mesut metal metin metre mevsim meydan mezar mızrak miras misafir
model modern molla motor muhtar mutfak mutlu muzip mücadele müdür mühür
müzik nakit nakış namaz namus nasihat neden nefes nefret nehir neşe niyet
normal nokta numara nüfus ocak oda odun okul okuma okur olay olgu olmak
omuz onay onur opera orman ortak ortam otel otobüs oturma oyun oyuncak
öfke öğle öğrenci öğretmen öksürük ölçek ölçü ölüm ömür önce önder önem
öneri örgü örnek örtü öykü özel özet özgür özlem paket palto pamuk panel
para parça pardon park parmak parti pasta patates patika patron pazar
pazen pembe pencere perde peron peron peynir pilav pilot pinti pirinç
plaj plan plaka polis politika porsiyon posta profil program proje pusula
radyo rahat rakam rakip randevu rapor rastgele raket refah rehber reklam
renk resim resmi rezerv rica ritim roman rota rüya rüzgar saat sabah
sabun sadece safir sahil sahne sakal sakin salata salon sanat sanayi
sancı sandal sanki saray sarhoş sarı satır satış savaş sayfa sayı sebep
sebze seçim sefer sehpa sekiz selam sepet serin sergi servis ses sessiz
sevgi sevinç sezon sıcak sigara silah silgi simit sinema sinir sistem
sivri siyah sofra soğan soğuk sokak solmak sonuç sorun soru soyut söylem
söylev spor su subay sucuk sunum sürat süre süreç sürpriz sürü süslü
şafak şair şaka şampiyon şans şarkı şarap şart şeker şekil şemsiye şerbet
şeref şezlong şifa şiir şike şimdi şirket şişman şoför şölen şubat şurup
şüphe tabak taban tabela tablo tahta takım taksi talep talih tampon tanık
tanım taraf tarak tarih tarla tas tasarım taşıma tatil tatlı tavan tavuk
tazminat tebrik tehlike tekne teklif tekrar telefon televizyon telaş
tembel temel temiz temmuz tencere teneke tepe tepki terazi tercih tereyağı
terlik ters teslim tespit teyze tıbbi ticaret tiyatro tohum toka toplam
toplum torba torun toz trafik tramvay tren tuzak tutum tuvalet türkü tüccar
tünel tüfek uçak uçurum uçuş ufuk ulaşım umut unsur usta usul utanç uygun
uyku uyum uzak uzman uzun ücret üçgen üçlü ülke ümit ünlü üretim ürün
üstün üzgün üzüm vadi vagon vakit vakıf valiz vantilatör vapur varlık
vatan vazo vergi verim veri video vida vitrin vurgu vücut yabancı yağmur
yakıt yalan yalnız yamaç yanıt yapı yaprak yara yarar yardım yarım yarış
yasa yastık yatak yatırım yavaş yayın yazar yazı yelek yemek yemiş yenge
yeni yeşil yetenek yetki yıldız yıkama yolcu yorgun yorum yumurta
yurt yuva yüksek yürek yüzük zafer zaman zarar zaten zayıf zehir zemin
zengin zeytin zihin zil zincir ziyaret zorluk zümre
"""


def _cozumle(metin: str) -> set[str]:
    return {kelime for kelime in metin.split() if kelime}


# --------------------------------------------------------------------------
# 3. Kategori listelerinden çıkarılanlar
# --------------------------------------------------------------------------

## Kategori listeleri (hayvan/doğa/nesne/yiyecek) somut isimlerden oluşuyor
## ama içlerinde ortalama bir oyuncunun aklına gelmeyecek maddeler vardı:
## "elik", "çebiç", "kupes", "künk", "nefir", "tirit"... Bunlar oyunda ayrıca
## kule enerjisi veren kelimeler olduğu için zararsız değil — oyuncu
## bulamadığı bir kelimeye bağlı kalıyor. Sözlükten silinmezler, sadece
## kategoriye (dolayısıyla hedefe) girmezler.
KATEGORI_DISI = """
elik enik puhu pupa saka sıpa suna çebiç bahri camız hecin kımıl keler
kupes kutan lahos marya orfoz tirsi toklu torik turaç zağar sığın yayın
makak angut maral pisi kefal

mika sema humus kovuk kumul funda boran akik gölet

mıh tuğ çuha künk mest teşt sele pota sini gürz çekül dibek kağnı kırba
nalın nefir rebap sadak tolga tuluk urgan kargı bıçkı heybe semer sicim
sürgü tomar törpü nacak keski

tirit lapa katık pazı
"""


def kategori_disi() -> set[str]:
    """Kategori listelerine girmemesi gereken nadir somut isimler."""
    return _cozumle(KATEGORI_DISI)


def yaygin_cekirdek() -> set[str]:
    """Elle küratörlü yaygın kelimeler (kategori listeleri hariç)."""
    return _cozumle(YAYGIN_3) | _cozumle(YAYGIN_EK) | _cozumle(YAYGIN_UZUN)


if __name__ == "__main__":
    cekirdek = yaygin_cekirdek()
    print(f"küfür listesi : {len(KUFUR)}")
    print(f"yaygın çekirdek: {len(cekirdek)}")
