"""Kule kategorileri için elle derlenmiş Türkçe kelime tohumları.

Buradaki her kelime `build_categories.py` tarafından TDK tabanlı ana sözlükle
karşılaştırılır; sözlükte bulunmayanlar rapor edilip elenir. Böylece kategori
listeleri ana sözlükle daima tutarlı kalır.

Kural: yalnızca kategoriye TEK BAŞINA ait olan adlar yazılır. "bal arısı",
"kaya balığı" gibi tamlamaların parçaları ("kaya", "bal") kendi kategorilerine
aittir, hayvan listesine yazılmaz.

Bir kelime birden fazla kategoride geçerse PRIORITY sırasına göre tek kategoriye
atanır (bkz. build_categories.py).
"""

# Öncelik: bir kelime birden çok listede yer alırsa soldaki kategori kazanır.
PRIORITY = ["hayvan", "yiyecek", "doga", "nesne"]

HAYVAN = """
hayvan yavru sürü kuş balık böcek sürüngen kemirgen yırtıcı
at eşek katır tay kısrak aygır beygir midilli küheylan
deve hecin lama alpaka bizon yak
inek öküz boğa dana buzağı tosun manda camız sığır düve
koyun kuzu koç toklu oğlak keçi teke çebiç marya
köpek enik kancık tazı zağar finolar samoyed
kurt çakal tilki sırtlan çita
kedi pisi aslan kaplan panter puma jaguar leopar vaşak
ayı panda koala kanguru
maymun şempanze goril orangutan makak babun
fil mamut gergedan zürafa zebra antilop ceylan
geyik karaca sığın elik
domuz sıpa hınzır yabandomuzu
tavşan sincap kunduz sıçan fare köstebek
gelincik sansar samur kokarca porsuk vizon
yarasa kirpi rakun tapir
balina yunus fok mors narval ayıbalığı
ahtapot kalamar denizatı denizyıldızı denizanası
vatoz levrek çipura lüfer palamut torik kolyoz
hamsi sardalya istavrit kefal mezgit uskumru tirsi
sazan turna alabalık yayın izmarit sinarit orfoz lahos
dülger iskorpit karagöz mırmır çinekop zargana kupes
karides yengeç midye istiridye salyangoz sünger
kartal şahin atmaca doğan kerkenez akbaba çaylak
baykuş puhu kukumav
karga kuzgun saksağan alakarga sığırcık
serçe ispinoz iskete bülbül kızılgerdan
güvercin kumru üveyik tahtalı
kırlangıç ebabil guguk
leylek balıkçıl kaşıkçı flamingo pelikan karabatak
martı kutan angut
ördek kaz kuğu suna
tavuk horoz piliç civciv hindi
tavus sülün keklik bıldırcın çil turaç
papağan kanarya saka
ağaçkakan hüthüt penguen
çulluk toygar tarlakuşu bayağı
yılan engerek kobra piton boa
kertenkele bukalemun iguana varan keler
kaplumbağa tosbağa timsah
kurbağa semender
sinek sivrisinek tatarcık atsineği
arı yabanarı oğul kraliçe
karınca termit
uğurböceği hamamböceği tahtakurusu bokböceği
kelebek tırtıl koza ipekböceği güve
çekirge cırcırböceği ağustosböceği
akrep örümcek kene bit pire
solucan sülük kırkayak çıyan
yusufçuk larva kurtçuk pupa nimf
ejderha ejder anka simurg grifon şahmeran
kuzgun kartalca leylek
sömestr
tırtıl kelebek
pars maral sungur bahri orkinos iskarmoz böğü gelengi kımıl
ahtapot yengeç deniztarağı
kaz kazayağı
sırtlan çakal
"""

YIYECEK = """
yiyecek yemek aş azık erzak zahire katık çerez meze
kahvaltı öğün ziyafet şölen sofra lokma
ekmek pide lavaş bazlama yufka simit çörek poğaça börek
mantı erişte makarna bulgur pilav lapa köfte
un maya hamur kepek irmik nişasta
buğday arpa yulaf çavdar mısır pirinç darı
mercimek nohut fasulye bakla bezelye börülce
et kıyma but pirzola kaburga ciğer böbrek işkembe
kebap sucuk pastırma salam sosis kavurma
çorba tarhana yahni güveç sote haşlama
dolma sarma salata cacık turşu
zeytin yağ tereyağı margarin
süt yoğurt ayran kefir kaymak krema
peynir kaşar tulum lor çökelek
yumurta omlet menemen
bal pekmez reçel marmelat şurup helva tahin
şeker lokum baklava kadayıf tulumba revani şekerpare
kurabiye bisküvi pasta kek tart puding muhallebi
sütlaç keşkül kazandibi aşure güllaç
dondurma şerbet limonata hoşaf komposto
çay kahve salep boza şıra
elma armut ayva erik kayısı şeftali kiraz vişne
üzüm incir dut nar hurma
portakal mandalina limon greyfurt turunç bergamot
muz ananas mango avokado
çilek ahududu böğürtlen kızılcık
karpuz kavun
ceviz fındık badem fıstık kestane leblebi
domates salatalık biber patlıcan kabak
patates soğan sarımsak havuç turp pancar
lahana karnabahar brokoli ıspanak pazı marul
kereviz pırasa enginar bamya
mantar kuşkonmaz semizotu roka tere dereotu
maydanoz nane fesleğen kekik reyhan
tuz karabiber kimyon sumak
tarçın karanfil zencefil safran vanilya
susam haşhaş anason rezene
sirke salça
şıra pekmez
lokum kadayıf
tatlı tuzlu ekşi acımsı
peksimet
kuskus bulgur
turşu tuzluk
tirit papara
kaygana
höşmerim kadayıfçı
sarımsaklı
tuzsuz yağsız
etli sütlü ballı
mayalı
çığırtma
kapama
mücver
pide çiğköfte
"""

DOGA = """
doğa manzara çevre iklim hava ortam
dağ tepe yamaç doruk zirve sırt yayla plato ova düzlük
vadi boğaz geçit kanyon uçurum yar kayalık bayır
orman koru ağaçlık çalılık fundalık makilik bozkır step
çöl vaha kumul kum çakıl taş kaya
deniz okyanus körfez koy liman kanal
göl gölet havuz baraj bataklık sazlık
nehir ırmak dere çay akarsu şelale çağlayan kaynak pınar
su dalga akıntı gelgit köpük buhar girdap
yağmur çisenti sağanak yağış kar tipi dolu buz kırağı
çiy sis pus duman bulut gökyüzü sema
rüzgar meltem fırtına kasırga hortum poyraz lodos
yıldız gündoğusu batı kuzey güney doğu
şimşek yıldırım boran gürleme
güneş ay gezegen takımyıldız
şafak tan sabah öğle ikindi akşam gece gündüz
mevsim ilkbahar yaz sonbahar kış bahar güz
toprak çamur balçık kil verimli humus gübre mineral
granit mermer bazalt kireç kuvars mika
maden altın gümüş bakır demir kurşun çinko kalay
elmas yakut zümrüt safir akik firuze inci mercan
kömür petrol
ateş alev kor kıvılcım kül köz
lav volkan yanardağ krater deprem
ağaç çam köknar ladin sedir servi ardıç porsuk
meşe kayın gürgen kavak söğüt çınar ıhlamur
akçaağaç dişbudak karaağaç akasya
defne mersin sakız palmiye kamış bambu
çiçek gül lale karanfil zambak sümbül nergis menekşe
papatya gelincik yasemin manolya ortanca kamelya
orkide leylak begonya kaktüs sardunya
ot çim çayır otlak yonca sap saman
yaprak dal kök gövde kabuk tomurcuk gonca filiz sürgün
tohum çekirdek polen reçine
yosun liken eğrelti
diken çalı funda ısırgan
kıyı sahil plaj kumsal delta ada yarımada burun
mağara kovuk oyuk in
buzul çığ heyelan sel taşkın
gökkuşağı serap kutup
gölge ışık aydınlık karanlık
sıcak soğuk ılık serin donma ayaz
kuraklık nem rutubet
tarla bağ bahçe bostan meyvelik
patika iz keçiyolu
ufuk boşluk uzay evren
ekvator tropik
menderes
buzulçağı
yeryüzü dünya küre
derinlik yükseklik genişlik
bereket
çığlık
kaynarca akıntı burgaç
ardıçkuşu
çorak verimlilik
tepecik dağlık ovalık
yamaçlık
gökcisim
yıldızkümesi
sarmaşık zakkum ökseotu
zeytinlik fidan fidanlık
meyveli çekirdekli
yaprakdöken
"""

NESNE = """
nesne araç gereç alet takım eşya
kılıç pala yatağan hançer bıçak kama şiş satır balta nacak
mızrak kargı süngü ok yay kiriş sadak temren
kalkan zırh miğfer tolga göğüslük dizlik kolçak
topuz gürz çomak sopa değnek asa
mancınık koçbaşı kule burç mazgal sur hendek
sapan tüfek tabanca top gülle barut fitil
çekiç tokmak örs kerpeten pense keski törpü eğe
testere matkap burgu vida çivi perçin
bıçkı rende planya çekül gönye cetvel
kürek bel kazma tırmık çapa orak tırpan yaba dirgen
saban pulluk kağnı araba tekerlek dingil boyunduruk
ip halat sicim urgan tel zincir kanca çengel
ağ olta tuzak kapan
kova leğen tas maşrapa testi küp çömlek güveç tencere
tava kazan kepçe kevgir süzgeç havan dibek pota
tabak çanak kase bardak kadeh sürahi ibrik şişe
kaşık çatal tepsi sini
sepet küfe heybe torba çuval dağarcık kese çanta
sandık kutu kasa kavanoz fıçı varil bidon teşt
masa sandalye tabure sedir divan koltuk kanepe
yatak karyola beşik döşek yorgan yastık minder halı kilim
dolap raf çekmece konsol vitrin
ayna tarak fırça makas iğne iplik yüksük
kumaş bez keten yün pamuk ipek atlas kadife çuha
gömlek kaftan cübbe entari elbise etek pantolon
palto ceket yelek hırka şal atkı eldiven çorap
ayakkabı çizme çarık terlik nalın mest
şapka külah kalpak sarık başlık takke fes
kemer kuşak toka düğme kopça
yüzük bilezik küpe kolye gerdanlık broş taç tuğ
kalem mürekkep kağıt parşömen kitap defter tomar
mühür damga levha tabela pusula harita
fener kandil mum meşale lamba şamdan
saat çan zil davul tef zurna ney kaval
kemençe saz bağlama kanun tambur rebap
kayık sandal gemi tekne yelken dümen çapa
fayton kızak
kapı pencere kilit anahtar sürgü mandal menteşe
merdiven basamak iskele direk kalas tahta
tuğla kerpiç harç çimento sıva
duvar çatı kubbe kemer sütun temel
köprü tünel kuyu çeşme oluk künk boru
ocak baca fırın körük maşa
terazi kantar tartı ölçek dirhem
para akçe sikke mangır
bayrak sancak flama
boru nefir
oyuncak topaç çember bilye zar
tespih muska tılsım nazarlık
iksir kristal
cımbız
süpürge havlu sabun lif
şemsiye baston
yelpaze mendil peçe
kablo fiş pil ampul
çelik tunç bronz pirinç
kalıp kepenk
sofra örtüsü
tokmak kürek
tabanca fişek
bileği
kırba matara
mahmuz üzengi eyer semer dizgin gem koşum
nal mıh
zembil sele
kütük takoz
şiş maşa
mumluk
madalyon mühürlük
kandilli
peştamal
tuluk kırba
kalemlik
yazıt kitabe
sancaklık
sapan taşı
kurşun kalıp
zırhlı
gemici feneri
ok yayı
"""


def parse(block: str) -> list[str]:
    words: list[str] = []
    seen: set[str] = set()
    for token in block.split():
        if token in seen:
            continue
        seen.add(token)
        words.append(token)
    return words


SEEDS = {
    "hayvan": parse(HAYVAN),
    "doga": parse(DOGA),
    "nesne": parse(NESNE),
    "yiyecek": parse(YIYECEK),
}

CATEGORY_META = {
    "hayvan": {
        "ad": "Hayvanlar",
        "kule": "okcu",
        "renk": "#c9772e",
        "aciklama": "Okçu Kulesi — hızlı, tek hedef",
    },
    "doga": {
        "ad": "Doğa",
        "kule": "buyu",
        "renk": "#3f8fd6",
        "aciklama": "Büyü Kulesi — alan hasarı",
    },
    "nesne": {
        "ad": "Nesne ve Araçlar",
        "kule": "mancinik",
        "renk": "#8d6b4b",
        "aciklama": "Mancınık — yavaş, yüksek hasar",
    },
    "yiyecek": {
        "ad": "Yiyecekler",
        "kule": "sifa",
        "renk": "#4fbf6a",
        "aciklama": "Şifa Çeşmesi — kale canı yeniler",
    },
}
