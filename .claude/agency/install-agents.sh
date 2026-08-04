#!/usr/bin/env bash
#
# install-agents.sh — msitarzewski/agency-agents koleksiyonundan Claude Code
# alt-ajanlarini bu projeye (veya kullanici geneline) kurar.
#
# Kullanim:
#   ./.claude/agency/install-agents.sh                      # curated.txt listesini kurar
#   ./.claude/agency/install-agents.sh --list               # tum roster'i listeler
#   ./.claude/agency/install-agents.sh --division game-development,testing
#   ./.claude/agency/install-agents.sh --agent godot-shader-developer,design-ui-designer
#   ./.claude/agency/install-agents.sh --file benim-listem.txt
#   ./.claude/agency/install-agents.sh --all                # 271 ajanin tamami (~18k token)
#   ./.claude/agency/install-agents.sh --global --division security
#   ./.claude/agency/install-agents.sh --source /yol/agency-agents --all --dry-run
#
# Secenekler:
#   --division <a,b>   Sadece bu bolumler
#   --agent <a,b>      Sadece bu ajan slug'lari (dosya adi, .md'siz)
#   --file <yol>       Satir basina bir slug iceren liste dosyasi (# yorum destekli)
#   --all              Roster'in tamami
#   --list             Kurulum yapmadan mevcut ajanlari yazdirir
#   --global           ~/.claude/agents altina kurar (varsayilan: <repo>/.claude/agents)
#   --dest <yol>       Hedef dizini acikca belirtir
#   --source <yol>     Klonlamak yerine yereldeki agency-agents kopyasini kullanir
#   --update           Onbellekteki klonu git pull ile tazeler
#   --dry-run          Sadece ne kurulacagini gosterir
#   --force            Var olan dosyalarin uzerine yazar (varsayilan davranis da budur)
#
# Ajan dosyalari kurulurken frontmatter normalize edilir:
#   name: "Godot Gameplay Scripter"  ->  name: godot-gameplay-scripter
#                                        displayName: Godot Gameplay Scripter
# Claude Code alt-ajan adlari kucuk harf + tire bekler; slug dosya adindan uretilir.

set -euo pipefail

UPSTREAM="https://github.com/msitarzewski/agency-agents.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/.cache/agency-agents"
CURATED_FILE="$SCRIPT_DIR/curated.txt"

# Ajan barindirmayan ust dizinler (bkz. upstream divisions.json).
NON_DIVISIONS=(".git" ".github" "integrations" "scripts" "examples" "strategy")

SOURCE=""
DEST=""
SELECT_MODE="curated"
DIVISIONS=""
AGENTS=""
LIST_FILE=""
GLOBAL=0
DRY_RUN=0
DO_UPDATE=0

die() { printf 'hata: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

usage() {
  sed -n '3,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --division) DIVISIONS="${2:-}"; SELECT_MODE="filter"; shift 2 ;;
    --agent)    AGENTS="${2:-}";    SELECT_MODE="filter"; shift 2 ;;
    --file)     LIST_FILE="${2:-}"; SELECT_MODE="filter"; shift 2 ;;
    --all)      SELECT_MODE="all";  shift ;;
    --list)     SELECT_MODE="list"; shift ;;
    --global)   GLOBAL=1;           shift ;;
    --dest)     DEST="${2:-}";      shift 2 ;;
    --source)   SOURCE="${2:-}";    shift 2 ;;
    --update)   DO_UPDATE=1;        shift ;;
    --dry-run)  DRY_RUN=1;          shift ;;
    --force)    shift ;;
    -h|--help)  usage; exit 0 ;;
    *) die "bilinmeyen secenek: $1 (yardim icin --help)" ;;
  esac
done

# --- kaynak: yerel kopya ya da onbellekteki klon ---------------------------
if [[ -n "$SOURCE" ]]; then
  [[ -d "$SOURCE" ]] || die "--source dizini yok: $SOURCE"
  SRC="$(cd "$SOURCE" && pwd)"
else
  if [[ -d "$CACHE_DIR/.git" ]]; then
    if [[ $DO_UPDATE -eq 1 ]]; then
      info "onbellek tazeleniyor: $CACHE_DIR"
      git -C "$CACHE_DIR" pull --ff-only --quiet || info "uyari: pull basarisiz, mevcut kopya kullanilacak"
    fi
  else
    info "agency-agents klonlaniyor -> $CACHE_DIR"
    mkdir -p "$(dirname "$CACHE_DIR")"
    git clone --depth 1 --quiet "$UPSTREAM" "$CACHE_DIR" \
      || die "klonlama basarisiz. Ag erisimi yoksa --source ile yerel bir kopya verin."
  fi
  SRC="$CACHE_DIR"
fi

# --- hedef ------------------------------------------------------------------
if [[ -z "$DEST" ]]; then
  if [[ $GLOBAL -eq 1 ]]; then DEST="$HOME/.claude/agents"; else DEST="$REPO_ROOT/.claude/agents"; fi
fi

# --- roster'i topla ---------------------------------------------------------
# Cikti satiri: <division>\t<slug>\t<yol>
collect_roster() {
  local skip f rel division slug
  while IFS= read -r f; do
    rel="${f#"$SRC"/}"
    division="${rel%%/*}"
    skip=0
    for nd in "${NON_DIVISIONS[@]}"; do [[ "$division" == "$nd" ]] && skip=1; done
    [[ $skip -eq 1 ]] && continue
    # sadece frontmatter'inda name+description olan dosyalar ajandir
    head -20 "$f" | grep -q '^name:' || continue
    head -20 "$f" | grep -q '^description:' || continue
    slug="$(basename "$f" .md)"
    printf '%s\t%s\t%s\n' "$division" "$slug" "$f"
  done < <(find "$SRC" -type f -name '*.md' | sort)
}

ROSTER="$(collect_roster)"
[[ -n "$ROSTER" ]] || die "kaynakta ajan bulunamadi: $SRC"

if [[ "$SELECT_MODE" == "list" ]]; then
  printf '%s\n' "$ROSTER" | awk -F'\t' '{ printf "%-22s %s\n", $1, $2 }'
  printf '\ntoplam: %s ajan\n' "$(printf '%s\n' "$ROSTER" | wc -l | tr -d ' ')"
  exit 0
fi

# --- secim ------------------------------------------------------------------
WANTED_AGENTS=""
add_wanted() { WANTED_AGENTS+="$1"$'\n'; }

case "$SELECT_MODE" in
  curated)
    [[ -f "$CURATED_FILE" ]] || die "curated.txt yok: $CURATED_FILE (--division/--agent/--all kullanin)"
    while IFS= read -r line; do
      line="${line%%#*}"; line="$(printf '%s' "$line" | tr -d '[:space:]')"
      [[ -n "$line" ]] && add_wanted "$line"
    done < "$CURATED_FILE"
    ;;
  filter)
    if [[ -n "$LIST_FILE" ]]; then
      [[ -f "$LIST_FILE" ]] || die "liste dosyasi yok: $LIST_FILE"
      while IFS= read -r line; do
        line="${line%%#*}"; line="$(printf '%s' "$line" | tr -d '[:space:]')"
        [[ -n "$line" ]] && add_wanted "$line"
      done < "$LIST_FILE"
    fi
    if [[ -n "$AGENTS" ]]; then
      while IFS= read -r a; do [[ -n "$a" ]] && add_wanted "$a"; done \
        < <(printf '%s\n' "$AGENTS" | tr ',' '\n' | tr -d '[:blank:]')
    fi
    if [[ -n "$DIVISIONS" ]]; then
      while IFS= read -r d; do
        [[ -z "$d" ]] && continue
        picks="$(printf '%s\n' "$ROSTER" | awk -F'\t' -v want="$d" '$1 == want { print $2 }')"
        [[ -n "$picks" ]] || { printf 'uyari: bolum bulunamadi: %s\n' "$d" >&2; continue; }
        while IFS= read -r s; do [[ -n "$s" ]] && add_wanted "$s"; done <<< "$picks"
      done < <(printf '%s\n' "$DIVISIONS" | tr ',' '\n' | tr -d '[:blank:]')
    fi
    [[ -n "$WANTED_AGENTS" ]] || die "secim bos kaldi (--division/--agent/--file degerlerini kontrol edin)"
    ;;
esac

# --- kurulacak dosyalari belirle -------------------------------------------
SELECTED=""
if [[ "$SELECT_MODE" == "all" ]]; then
  SELECTED="$ROSTER"
else
  MISSING=""
  while IFS= read -r slug; do
    [[ -z "$slug" ]] && continue
    match="$(printf '%s\n' "$ROSTER" | awk -F'\t' -v s="$slug" '$2==s{print; exit}')"
    if [[ -z "$match" ]]; then MISSING+="  $slug"$'\n'; else SELECTED+="$match"$'\n'; fi
  done < <(printf '%s' "$WANTED_AGENTS" | sort -u)
  if [[ -n "$MISSING" ]]; then
    printf 'uyari: roster'"'"'da bulunamayan slug'"'"'lar:\n%s' "$MISSING" >&2
  fi
fi
SELECTED="$(printf '%s' "$SELECTED" | grep -v '^$' || true)"
[[ -n "$SELECTED" ]] || die "kurulacak ajan yok"

COUNT="$(printf '%s\n' "$SELECTED" | wc -l | tr -d ' ')"
info "kaynak : $SRC"
info "hedef  : $DEST"
info "secilen: $COUNT ajan"

if [[ $DRY_RUN -eq 1 ]]; then
  printf '%s\n' "$SELECTED" | awk -F'\t' '{ printf "  [kuru calisma] %s/%s\n", $1, $2 }'
  exit 0
fi

mkdir -p "$DEST"

# --- kur --------------------------------------------------------------------
installed=0
while IFS=$'\t' read -r division slug path; do
  [[ -z "$slug" ]] && continue
  awk -v slug="$slug" -v division="$division" '
    BEGIN { fm = 0 }
    NR == 1 && $0 == "---" { fm = 1; print; next }
    fm == 1 && $0 == "---" { fm = 2; print "division: " division; print; next }
    fm == 1 && /^name:[[:space:]]/ {
      orig = $0
      sub(/^name:[[:space:]]*/, "", orig)
      gsub(/^["'"'"']|["'"'"']$/, "", orig)
      print "name: " slug
      print "displayName: " orig
      next
    }
    fm == 1 && /^description:[[:space:]]/ {
      val = $0
      sub(/^description:[[:space:]]*/, "", val)
      # zaten tirnakliysa dokunma; degilse ve icinde ": " varsa YAML icin tirnakla
      if (val ~ /^["'"'"']/) { print; next }
      if (index(val, ": ") > 0) {
        gsub(/"/, "'"'"'", val)
        print "description: \"" val "\""
      } else { print }
      next
    }
    { print }
  ' "$path" > "$DEST/$slug.md"
  installed=$((installed + 1))
done < <(printf '%s\n' "$SELECTED")

info "kuruldu: $installed ajan -> $DEST"
info "Not: yeni ajanlar bir sonraki Claude Code oturumunda yuklenir."
