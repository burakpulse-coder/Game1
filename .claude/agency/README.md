# Agency Agents — kurulum kiti

[msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
koleksiyonundaki **270 uzman alt-ajanı** Claude Code'a kuran taşınabilir kit.
(MIT lisanslı; upstream `c89557f` referans alındı.)

## Bu klasörde ne var

| Dosya | İşlevi |
|---|---|
| `install-agents.sh` | Kurulum betiği — upstream'i klonlar, seçilenleri `.claude/agents/` altına kopyalar |
| `curated.txt` | Bu projede kurulu tutulan ajan listesi (argümansız çalıştırınca bu kurulur) |
| `catalog.md` | 270 ajanın tamamının slug + açıklama dizini — hangi uzmanı çağıracağını buradan seç |
| `.cache/` | Upstream klonu (git'e girmez) |

Kurulu ajanların kendisi `.claude/agents/` altındadır ve **git'e commit edilir** —
böylece her yeni Claude Code oturumunda otomatik yüklenir, ağ erişimi gerekmez.

## Kullanım

```bash
# curated.txt'deki listeyi kur (varsayılan)
./.claude/agency/install-agents.sh

# tüm roster'ı listele
./.claude/agency/install-agents.sh --list

# bölüm bazında kur
./.claude/agency/install-agents.sh --division game-development,testing

# tek tek ajan kur
./.claude/agency/install-agents.sh --agent godot-shader-developer,security-penetration-tester

# hepsini kur (aşağıdaki maliyet notuna bak)
./.claude/agency/install-agents.sh --all

# kullanıcı geneline kur (~/.claude/agents) — kalıcı makinelerde mantıklı
./.claude/agency/install-agents.sh --global --division engineering

# upstream'i tazele
./.claude/agency/install-agents.sh --update

# önce ne olacağını gör
./.claude/agency/install-agents.sh --division security --dry-run
```

Ayrıntılı yardım: `./.claude/agency/install-agents.sh --help`

## Neden hepsi değil de seçilmiş bir set?

Claude Code kurulu her ajanın `name` + `description` alanını **her oturumun sistem
promptuna** yükler. Ölçüldü:

| Kapsam | Ajan | Oturum başı ek bağlam |
|---|---|---|
| Bu projenin seçilmiş seti | 29 | ~7 KB (≈2k token) |
| Tüm roster (`--all`) | 270 | ~72 KB (≈18k token) |

Yani `--all` her oturumdan ~18k token götürür. Kit bu yüzden "hepsini kur" yerine
"kataloğu yanında tut, gerekeni kur" modeliyle çalışır: `catalog.md` yüklenmez,
sadece ihtiyaç anında okunur.

## Yeni bir projede kullanmak

```bash
# 1. Bu klasörü yeni projeye kopyala
cp -r /yol/Game1/.claude/agency /yeni-proje/.claude/agency

# 2. curated.txt'yi o projeye göre düzenle (catalog.md'den slug seç)

# 3. Kur
cd /yeni-proje && ./.claude/agency/install-agents.sh

# 4. .gitignore'a ekle
echo '.claude/agency/.cache/' >> /yeni-proje/.gitignore
```

`.claude/agents/` çıktısını commit et; `.claude/agency/.cache/` klasörünü etme.

## Ajan çağırma

Kurulu bir ajanı Task/Agent aracında `subagent_type` olarak slug'ıyla ver, ya da
sohbette adıyla iste:

```
godot-shader-developer ajanını kullanarak harf çarkına parıltı shader'ı yaz.
```

## Frontmatter normalizasyonu

Upstream ajan adları insan okunur başlıklar (`name: Godot Gameplay Scripter`).
Claude Code alt-ajan adı için küçük harf + tire bekler, bu yüzden betik kurarken:

- `name:` alanını dosya adından üretilen slug ile değiştirir (`godot-gameplay-scripter`)
- Orijinal başlığı `displayName:` olarak saklar
- Ait olduğu bölümü `division:` olarak ekler
- İçinde `": "` geçen tırnaksız `description:` değerlerini tırnaklar (YAML güvenliği)

Gövde metni hiç değiştirilmez.
