# Kelime Kalesi — Claude Code notları

Türkçe kelime bulmaca + kule savunma hibriti. **Godot 4.3 / GDScript**, dikey
(portrait) Android oyunu; masaüstü (Windows/Linux) dışa aktarımları da var.
Oynanış, kule tipleri ve derleme adımları için `README.md`.

## Uzman alt-ajanlar (Agency Agents)

`.claude/agents/` altında [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
koleksiyonundan seçilmiş **29 uzman ajan** kurulu. Her oturumda otomatik yüklenirler.

**Ne zaman kullan:** iş belirli bir uzmanlık alanına düştüğünde ilgili ajanı çağır —
tek bir genel geçiş yerine. Örnekler:

| İş | Ajan |
|---|---|
| GDScript mimarisi, signal/node tasarımı | `godot-gameplay-scripter` |
| Shader, görsel efekt | `godot-shader-developer` |
| Seviye zorluk eğrisi, dalga tasarımı | `level-designer` |
| Kule maliyeti / ekonomi dengesi | `economy-designer` |
| Android/masaüstü derleme, imzalama, yayın | `engineering-mobile-release-engineer` |
| Kod incelemesi | `engineering-code-reviewer` |
| Minimal, riski düşük düzeltme | `engineering-minimal-change-engineer` |
| Türkçe/çoklu dil metin altyapısı | `engineering-i18n-engineer` |
| UI/UX, dokunma hedefleri, okunabilirlik | `design-ui-designer`, `design-ux-researcher` |
| "Gerçekten çalışıyor mu" doğrulaması | `testing-reality-checker` |
| Kare hızı / bellek ölçümü | `testing-performance-benchmarker` |
| Mağaza listelemesi, ekran görüntüleri | `marketing-app-store-optimizer` |

Kurulu tam liste: `ls .claude/agents/`

**Listede yoksa:** `.claude/agency/catalog.md` dosyasında 270 ajanın tamamı var
(bölüm + slug + açıklama). Uygun olanı bul, sonra kur:

```bash
./.claude/agency/install-agents.sh --agent <slug>
```

Kalıcı olmasını istiyorsan slug'ı `.claude/agency/curated.txt` içine de ekle.
Kit'in tamamı ve yeni projelere taşıma adımları: `.claude/agency/README.md`.

Yeni kurulan ajanlar **bir sonraki oturumda** yüklenir; aynı oturumda anında
kullanılamaz.

## Depo kuralları

- Commit mesajları Türkçe, ne değiştiğini ve nedenini söyler.
- `.claude/agents/` commit edilir (ajanlar ağ erişimi olmadan da gelsin diye).
- `.claude/agency/.cache/` commit edilmez.
