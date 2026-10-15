# Subly — Siri ve Kısayollar (App Intents, iOS 26)

Tasarım dosyası gelince `CLAUDE_CODE_PROMPT_<FEATURE>.md` handoff'u yazılır ve geliştirme ona göre yapılır. Prompt İngilizce (önceki handoff'larla aynı dil), metin örnekleri TR/EN.

Ortak tasarım bağlamı (her prompta kopyalanır):

> Subly is a calm, minimal iOS subscription tracker. UIKit, MVVM-C. Design system: graphite `#16181C` surfaces in dark, warm paper `#F3EFE6` in light; electric-lime accent `#C8F169` with near-black `#141609` content on lime fills (lime text/strokes become olive `#5F7F1C` on light surfaces); SF Pro, heavy headlines with tight tracking, tabular numerals for money; 22pt side gutters; cards with 22pt continuous corners; floating pill tab bar (Home · Subs · Timeline) with a separate lime FAB. Service tiles are rounded squares with the brand letter. Existing references: `Subly v5 (Dark).dc.html`, `Subly v5 (Light).dc.html`, `Subly Reminder Notification.dc.html`. Deliver every screen in dark AND light, iPhone 15/16 Pro frame (393×852), plus states listed below.

---

---

## Siri ve Kısayollar (App Intents, iOS 26)

### Mevcut durum

Üç intent zaten var: `AddSubscriptionIntent`, `NextRenewalIntent`, `SpendInCategoryIntent`. Eksik olanlar: aylık toplam, abonelik varlığı (entity) ile doğal sorgular, `AppShortcutsProvider` ile Siri ifadeleri, sonuç kartları (snippet), Kısayollar ve Spotlight görünürlüğü, uygulama içinde keşfettirme.

### Kapsam

**Intent'ler**

| Intent | Siri ifadesi (TR / EN) | Sonuç |
|---|---|---|
| `MonthlySpendIntent` | "Subly'de bu ay ne kadar abonelik ödüyorum" / "How much am I paying for subscriptions this month in Subly" | Tutar + aktif abonelik sayısı + yıllık; snippet kartı |
| `NextRenewalIntent` (var) | "Subly'de sıradaki yenileme ne" / "What's my next renewal in Subly" | Servis, tarih, tutar; snippet |
| `SubscriptionRenewalIntent` (yeni, entity param) | "Subly'de Spotify ne zaman yenileniyor" | O aboneliğin yenileme tarihi ve tutarı |
| `AddSubscriptionIntent` (var, genişlet) | "Subly'ye Spotify ekle" / "Add Spotify to Subly" | Katalogdan eşleşirse tutar/döngü otomatik, onay diyaloğu; eşleşmezse tutar sorulur |
| `OpenRecapIntent` | "Subly özetimi göster" | Uygulamayı açıp özeti oynatır (`openAppWhenRun = true`) |
| `SpendInCategoryIntent` (var) | "Subly'de yayın kategorisine ne ödüyorum" | Tutar; snippet |

**App Entity:** `SubscriptionEntity` (`AppEntity`, `IndexedEntity`): ad, tutar, döngü, yenileme tarihi, servis harfi. `EntityQuery` ad ile arar; `DisplayRepresentation` servis tile'ı ile. iOS 26'da `IndexedEntity` Spotlight'a ve Apple Intelligence'a abonelikleri açar ("Spotify'ı Subly'de aç").

**AppShortcutsProvider:** her intent için 3–5 ifade, `\(.applicationName)` yer tutucusuyla; TR ve EN `AppShortcuts.strings`. Kısa ifadeler (Siri bunları Kısayollar uygulamasında ve "Siri ile Subly" listesinde gösterir). Semboller: `creditcard`, `calendar`, `plus.circle`, `sparkles`.

**Snippet görünümleri (SwiftUI):** Siri ve Spotlight sonuçları için 3 kart: Aylık toplam, Sıradaki yenileme, Eklendi onayı. Snippet'lar sistem arka planı üstünde durur; Subly'nin grafit/lime dili küçük bir kart içinde uygulanır. Dinamik tip ve koyu/açık görünüm zorunlu.

**Keşfettirme (uygulama içi):**
- Ayarlar → **Siri ve Kısayollar** satırı → ekran: üstte kısa açıklama, altında her intent için "Hey Siri, …" örnek satırı ve `SiriTipView`; en altta `ShortcutsLink` ("Kısayollar'da aç").
- Dashboard'da ilk hafta bir kez görünen küçük ipucu kartı: "Siri'ye sor: Bu ay ne kadar abonelik ödüyorum?" (kapatılabilir; uzaktan anahtar `siri_tip_enabled`).
- Kilit ekranı widget'ının uzun basma menüsünde "Siri ile sor".

**Apple Intelligence (iOS 26):** `AppShortcutsProvider` ifadeleri ve `IndexedEntity` yeterli; ek olarak intent'lere `@Parameter(title:requestValueDialog:)` ve `AssistantIntent`/`AssistantEntity` (Apple'ın "App Intents domains") şemaları varsa uygulanır. Hedef: Siri'nin ekranda görünen aboneliği bağlamdan anlaması ("bunu Subly'ye ekle").

### Teknik notlar

- Intent'ler arka planda çalışır (`openAppWhenRun = false`), repository'ye App Group üzerinden erişir; `MonthlySpendIntent` Dashboard'daki hesapla aynı use case'i çağırmalı (tek kaynak).
- Para biçimi kullanıcının tercih ettiği para birimiyle (`CurrencyManager.preferredDisplayCurrency`).
- `AddSubscriptionIntent` katalog eşleşmesinde `CatalogPriceService` fiyatını kullanır; eklenen aboneliğe `catalogName` yazılır (Zam Alarmı ile ortak alan).
- `IntentResult & ProvidesDialog & ShowsSnippetView`.
- Gizlilik: hiçbir intent sunucuya gitmez.

### Testler

- Intent `perform()` birim testleri sahte repository ile (tutar, boş liste, eşleşmeyen ad).
- `SubscriptionEntityQuery` ad araması (prefix, büyük/küçük harf, Türkçe karakter).
- Kısayollar ifadeleri derleme zamanında doğrulanır (`AppShortcutsProvider` build'de kontrol eder).

### Claude Design promptu

```
[Ortak tasarım bağlamı]

Feature: "Siri & Shortcuts" — Subly answers questions and adds subscriptions through Siri, Spotlight and the Shortcuts app on iOS 26, and teaches users these phrases inside the app.

Design these, each in dark and light:

01 Siri result snippets (the compact card Siri shows over the current screen, iOS 26 style with the Siri glow at the bottom). Three variants:
  a) "Monthly spend": Subly mark + "This month" caption, big tabular amount "$102.45", secondary "7 active · $1,229.40/yr", a tiny 5-bar month sparkline (reuse the Dashboard's bar motif). Siri's spoken line below: "You're paying $102.45 this month across 7 subscriptions."
  b) "Next renewal": service tile (N), "Netflix · renews Oct 15", amount "$15.49", "in 2 days" chip in lime. Spoken: "Netflix renews on October 15 for $15.49."
  c) "Added": checkmark-in-lime-circle, "Spotify added", "$10.99 · monthly · renews Nov 12", small "Edit in Subly" link. Spoken: "Added Spotify, $10.99 a month."
  Also show the confirmation dialog Siri asks before adding when the price is unknown: "How much is it per month?" with a numeric field.

02 Spotlight results: searching "spotify" shows a Subly row (service tile, "Spotify · $10.99/mo · renews Nov 12") and a top-hit card "Subly: How much do I spend this month?" action.

03 Shortcuts app: Subly's shortcut tiles ("Monthly spend", "Next renewal", "Add subscription", "Show my recap") using the lime/graphite tile style with SF Symbols creditcard, calendar, plus.circle, sparkles.

04 In-app Settings → "Siri & Shortcuts" screen: header copy "Ask Siri. No tapping needed.", then a list of phrase rows, each with a waveform glyph, the phrase in quotes ("Hey Siri, how much am I paying for subscriptions this month in Subly?") and a one-line answer preview; a "Try it" affordance per row (SiriTipView-like); footer button "Open in Shortcuts". Turkish variant: "Hey Siri, Subly'de bu ay ne kadar abonelik ödüyorum?".

05 Dashboard tip card (first-week only, dismissible): small card under the hero: waveform + "Ask Siri: 'How much am I paying this month?'" with × and a "Show phrases" link.

Keep the snippets small (they sit over whatever app is open); dynamic type medium and large shown for 01a. Use tabular numerals for money. No red; lime is the only accent.
```

---

---

## Bağımlılıklar

- Mevcut üç intent'in üstüne kurulur; sunucu değişikliği yok.
- `AddSubscriptionIntent` katalog eşleşmesinde `catalogName` yazar (Zam Alarmı ile ortak alan).
- Uzaktan anahtar: `app_config.siri_tip_enabled` (Dashboard ipucu kartı).
