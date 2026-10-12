# Subly — Ana Ekran Widget'ları (Renewal Rings)

**Durum:** ✅ Uygulandı (12 Eki 2026). Kaynak: `design_handoff_subly_v5 2/CLAUDE_CODE_PROMPT_WIDGETS.md`
ve `Subly Widgets.dc.html`. 13 yeni birim testi (halka hesabı + widget öğe
üretici), toplam 46 test geçiyor. `subly://add` derin bağlantısı simülatörde
doğrulandı.

## 1. Ne var

| Aile | İçerik |
|---|---|
| **Small** | Tek abonelik: 84pt halka (çizgi 7) içinde 44pt r13 servis karosu, sağ üstte 18pt Subly işareti, altta ad (15/700), "when" (13/700 accent) + fiyat (13/600 secondary, tabular). |
| **Medium · 3** | Başlık satırı (işaret 14 + "Upcoming" · sağda "$46.48 this week") + 3 eşit sütun: 68pt halka (çizgi 6), 36pt r11 karo, ad 12.5/700, when 11.5/700 accent. Her sütun kendi detayına `Link`. |
| **Medium · 2** | Aynı başlık, 2 yatay sütun: halka + (ad 14/700, when 12.5/700 accent, fiyat 12.5/600). |
| **Medium · 1** | Başlık yok. 118pt halka (çizgi 9), 56pt r16 karo; sağda "Next renewal", ad 19/800, fiyat 30/800 (tracking −0.8, tabular), "When · Date" 13/700 accent. |
| **Boş** | İşaret + "Add your first subscription" → `subly://add`. |

- **Halka matematiği** (`RenewalProgressCalculator`): `progress = clamp((cycleDays − daysLeft) / cycleDays, 0.02, 1)`.
  `cycleDays` döngüden: aylık = o dönemin gerçek gün sayısı (28–31), yıllık = 365/366,
  haftalık = 7, custom = aylık (modelde gün sayısı alanı yok). Yay 12'den başlar,
  saat yönünde, yuvarlak uçlu.
- **"When":** 0 → Today, 1 → Tomorrow, aksi → "In N days".
- **Animasyon:** `RingArc` `Animatable`; `.animation(.spring(duration: 1.1, bounce: 0), value: progress)`
  ile zaman çizelgesi girişleri arasında süpürür. Sayılar `.contentTransition(.numericText())`.
  Reduce Motion açıkken süpürme yok.
- **Zaman çizelgesi:** şimdi + sonraki 7 gün için 00:01'de birer giriş, `.atEnd`.
  Her repository yazması (`save/archive/delete`) `WidgetCenter.reloadAllTimelines()` çağırır
  (`SwiftDataSubscriptionRepository.notifyObservers`), roll-forward da yeniler.
- **Sabitleme:** `AppIntentConfiguration` + `RenewalRingConfigurationIntent`
  ("Subscriptions" parametresi, Small 1 / Medium 3). Boşsa en yakın yenilemeler.
- **Dokunma:** Small ve 1'li Medium `widgetURL(subly://subscription/<id>)`; 2/3'lü
  sütunlar ayrı `Link`. Uygulama tarafında `DeepLinkRouter` (`subly://subscription/<id>`,
  `subly://add`) — bildirim "Subly'de incele" aksiyonu da aynı yoldan geçer.
  URL şeması `project.yml` → `CFBundleURLTypes`.
- **Renkler** (`WidgetTheme`): arka plan `#16181C`/`#FFFFFF`, halka `#C8F169`/`#8CB33A`,
  iz `white 0.10`/`black 0.08`, accent metin `#C8F169`/`#5F7F1C`, işaret çubukları
  `#4A5240 / #8CA85B / #C8F169(#8CB33A)`. Marka karoları iki temada aynı
  (`BrandPalette`, uygulamadaki `SublyBrandAppearance` ile ortak tablo).
  Halka ve karo `widgetAccentable()` (iOS 18 renkli ana ekran).
- **Erişilebilirlik:** her öğe tek eleman: "{Name}, {price}, renews {when}, {percent}% of the billing cycle elapsed." Fiyatlar `minimumScaleFactor(0.8)`.
- **Eskiyen tarih:** uygulama açılmadıysa `WidgetItemBuilder` yenileme tarihini bir
  sonraki döngüye yansıtır (Faz 2 planındaki A maddesi widget için çözüldü).

## 2. Dosyalar

| Dosya | Görev |
|---|---|
| `Subly/Domain/UseCases/RenewalProgressCalculator.swift` | Halka yüzdesi, döngü uzunluğu |
| `Subly/Domain/UseCases/WidgetItemBuilder.swift` | Abonelik → widget öğesi; sıralama, sabitleme, haftalık toplam |
| `Subly/Domain/Models/BrandPalette.swift` | UIKit'siz marka renk tablosu (app + widget) |
| `SublyWidgets/WidgetTheme.swift` | Renk tokenları, `StackMark`, `ServiceTileView`, `RingArc`, `ProgressRing` |
| `SublyWidgets/RenewalRingIntent.swift` | `PinnedSubscription` AppEntity + sorgu + yapılandırma intent'i |
| `SublyWidgets/RenewalRingWidget.swift` | Sağlayıcı, giriş, Small/Medium/boş görünümler, `#Preview`'lar |
| `Subly/Services/Notifications/DeepLinkRouter.swift` | `subly://` yönlendirme (bildirim + widget ortak) |
| `SublyTests/RenewalProgressCalculatorTests.swift` (8) · `WidgetItemBuilderTests.swift` (5) | Testler |

Eski `MonthlyTotalWidget` ve `UpcomingRenewalsWidget` korundu; arka planları yeni
token'a alındı. Bundle sırası: Renewal Rings → Upcoming → Monthly.

## 3. Handoff'tan sapmalar

- **Veri kaynağı:** handoff App Group'ta JSON anlık görüntü yazılmasını istiyor; widget
  zaten App Group'taki paylaşılan SwiftData deposunu okuyor (`SharedSubscriptionProvider`).
  Ayrı bir anlık görüntü dosyası eklenmedi — aynı sonuç, tek doğruluk kaynağı.
- **İlk eklemede 0'dan süpürme / yenileme günü ertesi sıfırlama:** WidgetKit yalnızca
  girişler arası animasyonu destekliyor; `RingArc` animatable olduğundan değer
  değişince süpürüyor. "Önceki değer bilinmiyor" durumunda (ilk ekleme) sistem
  animasyonsuz çizebilir; bu kısıt handoff'ta da kabul edilmişti.
- **Yerelleştirme:** widget hedefi `Strings`/`Localizable.strings`'i içermiyor; metinler
  İngilizce ("Upcoming", "Today", "In N days"). Ayrı bir widget string tablosu v1.1 işi.
- **Custom döngü:** modelde gün sayısı olmadığı için aylık kabul ediliyor (uygulamanın
  geri kalanıyla tutarlı).

## 4. Diğer kontroller (bu tur bulunanlar)

- **Düzeltildi:** Abonelik listesindeki kaydırarak sil/arşivle/geri al akışı
  hatırlatmaları yeniden kurmuyordu (`SubscriptionListViewModel`) → `reminderSync.resync()` eklendi.
- **Düzeltildi:** repository yazmaları widget'ları yenilemiyordu → `notifyObservers` içinde reload.
- **Ölü kod:** `SublyAppMark` ("coral S" işareti) README'deki üç çubuklu işaretle çelişiyor
  ama hiçbir yerden kullanılmıyor; `SublyLogoView` doğru işareti çiziyor. Silinebilir.
- **Bekleyen:** bildirim Content Extension (uzun basınca geri sayım kartı), takvim
  senkronu ve ay sonu çapası düzeltmesi (`docs/YENILEME_DONGUSU_PLANI.md` Faz 2).

## 5. Önizleme / QA

- Xcode'da `SublyWidgets/RenewalRingWidget.swift` → `#Preview` (Small, Medium 3/2/1, Empty); canvas'ta tema değiştirerek dark/light.
- Cihaz/simülatörde: ana ekranda boş alana uzun bas → "+" → "Subly" → Renewal Rings. Widget'a uzun bas → "Edit Widget" ile abonelik sabitle.
- Derin bağlantı: `xcrun simctl openurl booted "subly://add"`.

## Kilit ekranı widget'ları (`CLAUDE_CODE_PROMPT_LOCKSCREEN_WIDGETS.md`) — ✅ 12 Eki 2026
`SublyWidgets/LockScreenRingWidget.swift`, aynı bundle; `WidgetItemBuilder`, `RenewalProgressCalculator`, `RingArc` ve paylaşılan depo yeniden kullanılır.
- **Tek renk, sistem tonlu:** her şey `.primary` / `.secondary`; iz `.primary.opacity(0.28)`, arka plan `AccessoryWidgetBackground()`. `widgetRenderingMode != .vibrant` (StandBy vb.) ise yay `#C8F169`. Marka rengi yok. Halka alt sınırı 0,03.
- **Inline:** şablon mini halka görseli (0/25/50/75/90/100 adımlarına yuvarlanır) + "{Ad} · {Ne zaman} · {Fiyat}"; sığmazsa `ViewThatFits` ile "{Ad} · {Ne zaman}". Boş: "Subly · Yakında yenileme yok".
- **Circular:** 72pt halka, çizgi 5; ortada baş harf (20/800) + kısa geri sayım "14d/3d/1d/Today" (11/700 `.secondary`). Boş: tek renk stack mark.
- **Rectangular:** 52pt halka + ad (15/700), ne zaman (13/600), fiyat (13/600 tabular). Aynı gün 2+ yenileme → "Netflix +1" ve günün toplamı. Boş: "Abonelik ekle".
- **Yapılandırma:** `LockRingConfigurationIntent` — abonelik sabitleme veya "Slot" (1–4): n-inci en yakın yenileme; dört daire yan yana dizilebilir.
- **Zaman çizelgesi/dokunma:** 7 gün boyunca 00:01 girişleri, `.atEnd`; `subly://subscription/<id>`, boş → `subly://add`. Animasyon girişler arası spring, Reduce Motion'da yok.
- `#Preview`: circular 14d/3d/1d/Today/boş, rectangular (tek, +1, boş), inline (dolu/boş).
- Sapma: inline "çoklu yenileme" varyantı (B ekranı "3 renewals this week") eklenmedi; inline her zaman seçilen tek aboneliği gösterir (`weekCount` entry'de hazır).
