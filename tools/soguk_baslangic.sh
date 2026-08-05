#!/usr/bin/env bash
#
# Soğuk başlangıç denetimi.
#
# Godot'un global `class_name` kaydı `.godot/global_script_class_cache.cfg`
# dosyasında tutulur ve yalnızca editör projeyi taradığında üretilir. Yeni bir
# `class_name` betiği eklendiğinde editör açıkken `git pull` yapan bir oyuncuda
# bu önbellek eskimiş kalır; o zaman GameConfig/UiKit gibi adlar çözülemez,
# tüm betikler ayrıştırma hatası verir ve ekranda yalnızca projenin varsayılan
# arka plan rengi (koyu mavi) kalır. Testler bunu yakalamaz, çünkü testler
# hazır bir önbellekle çalışır.
#
# Bu betik tam olarak o durumu taklit eder: önbelleği siler, editör taramasını
# çalıştırır, sonra oyunu gerçekten açar ve herhangi bir betik/sahne hatasında
# başarısız olur.
#
# Kullanım:  GODOT=/yol/Godot_v4.3-stable_linux.x86_64 tools/soguk_baslangic.sh

set -uo pipefail

PROJE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "Godot bulunamadı. GODOT=/yol/godot tools/soguk_baslangic.sh" >&2
	exit 2
fi

KOS() {
	if command -v xvfb-run >/dev/null 2>&1; then
		xvfb-run -a "$GODOT" "$@"
	else
		"$GODOT" "$@"
	fi
}

echo "== Önbellek siliniyor (.godot) =="
rm -rf "$PROJE/.godot"

echo "== Editör taraması =="
KOS --editor --headless --path "$PROJE" --quit >/dev/null 2>&1

ONBELLEK="$PROJE/.godot/global_script_class_cache.cfg"
if [ ! -s "$ONBELLEK" ]; then
	echo "BAŞARISIZ: sınıf önbelleği üretilmedi ($ONBELLEK)" >&2
	exit 1
fi

echo "== Oyun açılışı =="
CIKTI="$(KOS --headless --path "$PROJE" --quit-after 400 2>&1)"

# Ayrıştırma/yükleme hataları sessizce geçmesin; oyun bu durumda boş ekran verir.
if echo "$CIKTI" | grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Sahne yüklenemedi|Bilinmeyen ekran"; then
	echo "$CIKTI" | grep -E "SCRIPT ERROR|Parse Error|Failed to load script|Sahne yüklenemedi|Bilinmeyen ekran" >&2
	echo "BAŞARISIZ: soğuk başlangıçta betik hatası var — oyuncu boş ekran görür." >&2
	exit 1
fi

# Yeni çekilen bir kurulumda .import dosyaları gelir ama içe aktarılmış dokular
# (.godot/imported) gelmez. Sprite'lar yüklenemediğinde oyun yordamsal çizime
# düşmeli — düşmanların görünmez kalması kabul edilemez.
echo "== Doku yokken geri düşüş =="
find "$PROJE/.godot/imported" -name "*.ctex" -delete 2>/dev/null
find "$PROJE/.godot/imported" -name "*.md5" -delete 2>/dev/null
CIKTI2="$(KOS --headless --path "$PROJE" --quit-after 300 2>&1)"
if echo "$CIKTI2" | grep -qE "SCRIPT ERROR|Compilation failed|Parse Error"; then
	echo "$CIKTI2" | grep -E "SCRIPT ERROR|Compilation failed|Parse Error" | head -5 >&2
	echo "BAŞARISIZ: doku yokken betikler çöküyor — oyuncu boş savaş alanı görür." >&2
	exit 1
fi

echo "TAMAM: soğuk başlangıç temiz."
