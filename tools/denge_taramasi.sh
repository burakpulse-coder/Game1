#!/usr/bin/env bash
#
# Denge taraması: bütün bölümleri otomatik oynatıcıyla oynar ve sonuç tablosu
# yazar. Amaç, oynanamayan ya da aşırı zor bölümleri elle oynamadan bulmak.
#
# İki profil vardır ve ikisi de gerekli:
#
#   --insan   ortalama bir oyuncuyu taklit eder (sınırlı kelime dağarcığı,
#             dakikada ~11 kelime, yanlış denemeler, yavaş parmak, tepki
#             gecikmesi). "Bir insan bu bölümü geçebilir mi?" sorusunu ölçer.
#   (profilsiz) bütün çözüm kelimelerini bilen, en verimli sırayla oynayan,
#             hiç hata yapmayan bot. "Bölüm teorik olarak geçilebilir mi?"
#             sorusunu ölçer.
#
# İnsan profilinde kaybedilip botta kazanılan bölüm = insan için fazla zor.
# İkisinde de kaybedilen bölüm = matematiksel olarak sorunlu.
#
# Kullanım:
#   GODOT=/yol/godot tools/denge_taramasi.sh [--insan] [--yukseltme=oto|N]
#
# Çıktı: /tmp/kk_denge/<profil>.txt

set -uo pipefail

PROJE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
CIKTI_DIZIN="${CIKTI_DIZIN:-/tmp/kk_denge}"
ES_ZAMANLI="${ES_ZAMANLI:-3}"
TOPLAM="${TOPLAM:-60}"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "Godot bulunamadı. GODOT=/yol/godot tools/denge_taramasi.sh" >&2
	exit 2
fi

PROFIL="bot"
EK_ARG=("--hizli")
for arg in "$@"; do
	case "$arg" in
		--insan) PROFIL="insan"; EK_ARG+=("--insan") ;;
		--yukseltme=*) EK_ARG+=("$arg") ;;
		*) echo "bilinmeyen seçenek: $arg" >&2; exit 2 ;;
	esac
done

mkdir -p "$CIKTI_DIZIN"
CIKTI="$CIKTI_DIZIN/$PROFIL.txt"
: > "$CIKTI"

echo "== Denge taraması: profil=$PROFIL, $TOPLAM bölüm, $ES_ZAMANLI eşzamanlı =="

oyna() {
	local seviye="$1"
	# Her bölüm kendi kayıt dosyasıyla çalışsın; yoksa eşzamanlı koşular
	# birbirinin yükseltmelerini eziyor.
	local ev
	ev="$(mktemp -d)"
	HOME="$ev" timeout 420 "$GODOT" --headless --path "$PROJE" \
		"$PROJE/scenes/Demo.tscn" -- "--seviye=$seviye" "${EK_ARG[@]}" 2>/dev/null \
		| grep -a "SONUC" || echo "[Demo] SONUC seviye=$seviye ZAMAN_ASIMI"
	rm -rf "$ev"
}

for seviye in $(seq 1 "$TOPLAM"); do
	oyna "$seviye" >> "$CIKTI" &
	while [ "$(jobs -rp | wc -l)" -ge "$ES_ZAMANLI" ]; do
		wait -n
	done
done
wait

sort -t= -k2 -n "$CIKTI" -o "$CIKTI"
echo
echo "== Sonuç ($PROFIL) =="
KAYIP=$(grep -c "YENILGI\|ZAMAN_ASIMI" "$CIKTI" || true)
echo "kaybedilen bölüm: $KAYIP / $TOPLAM"
grep "YENILGI\|ZAMAN_ASIMI" "$CIKTI" || echo "  (yok)"
echo
echo "tam tablo: $CIKTI"
