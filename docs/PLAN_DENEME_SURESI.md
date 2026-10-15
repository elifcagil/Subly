# Subly — Deneme Süresi Takibi (ücretsiz deneme bitmeden sert uyarı)

Tasarım dosyası gelince `CLAUDE_CODE_PROMPT_<FEATURE>.md` handoff'u yazılır ve geliştirme ona göre yapılır. Prompt İngilizce (önceki handoff'larla aynı dil), metin örnekleri TR/EN.

Ortak tasarım bağlamı (her prompta kopyalanır):

> Subly is a calm, minimal iOS subscription tracker. UIKit, MVVM-C. Design system: graphite `#16181C` surfaces in dark, warm paper `#F3EFE6` in light; electric-lime accent `#C8F169` with near-black `#141609` content on lime fills (lime text/strokes become olive `#5F7F1C` on light surfaces); SF Pro, heavy headlines with tight tracking, tabular numerals for money; 22pt side gutters; cards with 22pt continuous corners; floating pill tab bar (Home · Subs · Timeline) with a separate lime FAB. Service tiles are rounded squares with the brand letter. Existing references: `Subly v5 (Dark).dc.html`, `Subly v5 (Light).dc.html`, `Subly Reminder Notification.dc.html`. Deliver every screen in dark AND light, iPhone 15/16 Pro frame (393×852), plus states listed below.

---

---

## Deneme Süresi Takibi (ücretsiz deneme bitmeden sert uyarı)

### Ürün davranışı

- Abonelik eklerken **"Ücretsiz deneme"** anahtarı. Açılınca: deneme bitiş tarihi (varsayılan bugün + 7/14/30 gün ön ayar), bittikten sonraki fiyat ve döngü.
- Deneme süresince abonelik listede ve Dashboard'da **"Deneme · 5 gün"** rozetiyle görünür; aylık toplamda sayılmaz (ödeme yok), ayrı bir **"Yaklaşan ödemeler"** satırında "Deneme bitince $15.49/ay" diye görünür.
- **Sert uyarı:** deneme bitmeden 3 gün, 1 gün ve bitiş günü sabah; bitiş günü uyarısı `.timeSensitive`, sessiz saatleri **deler** (ses + banner). Gerekçe: kullanıcı iptal etmezse para çekilir, bu normal hatırlatmadan farklı.
- Bildirim aksiyonları: **İptal ettim** (abonelik arşivlenir, "deneme bitti, iptal edildi" olarak işaretlenir; tasarruf özette sayılır), **Devam ediyorum** (deneme ücretli aboneliğe dönüşür), **Yarın hatırlat** (bitiş gününde yok).
- Bitiş günü geçtiğinde kullanıcı hiçbir şey seçmediyse abonelik otomatik ücretliye döner (`nextRenewalDate = trialEndsAt`, tutar = dönüşüm fiyatı) ve Dashboard'da "Netflix denemesi dün bitti, artık $15.49/ay" bilgi kartı çıkar.
- **Kullanıcıyı buna itmek:** (a) katalogdan deneme sunan bir servis eklenince form üstünde öneri çipi "Netflix 30 gün ücretsiz deneme sunuyor · Deneme olarak ekle"; (b) onboarding'in ikinci ekranında "Denemelerini unutma" kartı; (c) Dashboard'da deneme yoksa ve kullanıcı 3+ aboneliğe sahipse bir kez "Deneme sürelerini de takip et" ipucu; (d) özette "bu dönem X deneme bitti, Y'sini iptal ettin, Z kazandın" satırı.

### Veri modeli

```swift
struct Trial: Codable, Equatable, Sendable {
    var endsAt: Date                 // gün hassasiyeti, saat = ekleme saati (hatırlatmalarla aynı kural)
    var convertsToAmount: Decimal
    var convertsToCycle: BillingCycle
    var outcome: Outcome?            // nil = sürüyor
    enum Outcome: String, Codable { case cancelled, converted, expiredUnanswered }
    var resolvedAt: Date?
}
var trial: Trial?                    // Subscription'a yeni alan (Core Data: ayrı küçük entity ya da JSON)
```

Türetilmiş: `isOnTrial = trial?.outcome == nil && trial.endsAt >= today`. `Subscription.amount` deneme boyunca 0 kabul edilir (toplamlar), `trial.convertsToAmount` "yaklaşan" gösterimde kullanılır.

Katalog (sunucu): `catalog_prices.trial_days int null` — deneme sunan servisler için gün sayısı; form önerisi buradan gelir. Migration tek satır `alter table`.

Sunucu aynalama (isteğe bağlı, istatistik): `devices.trials_tracked int` ve `trials_cancelled int` toplam sayaçları; kimlik yok.

### İstemci akışı

1. **Form:** "Ücretsiz deneme" anahtarı → bitiş tarihi (ön ayar çipleri 7 · 14 · 30 gün + takvim), "Deneme bitince" tutar + döngü (katalogdan dolu gelir). Anahtar açıkken normal "tutar" alanı gizlenir ya da "Deneme bitince" olarak yeniden etiketlenir.
2. **Hatırlatma planlama:** `ReminderContentBuilder` deneme için ayrı dal: lead'ler `[3, 1, 0]` sabit (kullanıcı değiştiremez; "sert uyarı" ürün kararı), identifier `trial.<id>.<endsKey>`, kategori `TRIAL_ENDING` / `TRIAL_LAST_DAY`. Bitiş günü isteği: `.timeSensitive`, ses açık, sessiz saat kuralı atlanır. Aynı günde normal hatırlatmalarla **gruplanmaz** (ayrı thread `trials`).
3. **Aksiyonlar:** `trial.cancelled` → `outcome = .cancelled`, `isArchived = true`, bekleyen deneme bildirimleri silinir. `trial.keep` → `outcome = .converted`, `amount = convertsToAmount`, `billingCycle = convertsToCycle`, `nextRenewalDate = endsAt`, normal hatırlatmalar planlanır. `trial.snooze` → ertesi gün aynı saat (bitiş gününde sunulmaz).
4. **Roll-forward:** mevcut `RenewalRolloverService` ön planda `endsAt < today && outcome == nil` olanları `.expiredUnanswered` + ücretliye dönüştürür ve Dashboard bilgi kartını tetikler.
5. **Görünüm:** liste satırında rozet "Deneme · 5 gün" (lime çerçeve, 1 gün kala dolu lime, bitiş günü "Bugün bitiyor"); Dashboard hero altında "Denemeler" bölümü (varsa): servis, kalan gün, "bitince $X/ay"; Timeline'da deneme bitişi farklı işaretli (içi boş halka).
6. **Widget:** halka widget'ı deneme için halkayı lime yerine beyaz çerçeve + "Trial" etiketi ile gösterir; kilit ekranı satır widget'ı "Netflix deneme · 2 gün".
7. **Özet:** `RecapService` dönem içinde biten denemeleri sayar: `trialsEnded`, `trialsCancelled`, `savedAmount` (iptal edilenlerin yıllık dönüşüm tutarı). Özet kart 01 altına tek satır ya da yeni mini kart.
8. **Uzaktan anahtarlar:** `trial_nudges_enabled` (ipucu kartları), katalog `trial_days`.

Bildirim metinleri:
- 3 gün: "Netflix denemen 3 gün sonra bitiyor" / "Sonra $15.49/ay çekilecek. Devam edecek misin?"
- 1 gün: "Yarın: Netflix denemen bitiyor" / "İptal etmezsen yarın $15.49 çekilir."
- Bitiş günü (sert): "Bugün son gün: Netflix" / "Bugün iptal etmezsen $15.49/ay başlıyor."
- Aksiyonlar: "İptal ettim" · "Devam ediyorum" · "Yarın hatırlat"
- EN: "Your Netflix trial ends in 3 days" / "Then it's $15.49/mo. Keeping it?" · "Tomorrow: Netflix trial ends" / "Cancel today or pay $15.49 tomorrow." · "Last day: Netflix" / "Cancel today or $15.49/mo starts." · "I cancelled" · "Keeping it" · "Remind me tomorrow"

### Kenar durumları

- Deneme bitişi bugün ve eklenme saati geçmişse: bitiş günü bildirimi hemen (1 dk sonra) atılır.
- Kullanıcı deneme bitişini geçmişe girerse form uyarır ("Bu deneme zaten bitmiş") ve doğrudan ücretli abonelik olarak kaydetmeyi önerir.
- Deneme sırasında kullanıcı tutarı düzenlerse `convertsToAmount` güncellenir, `amount` değil.
- Arşivlenen (iptal edilen) deneme listede "Arşiv"de "Deneme · iptal edildi" etiketiyle kalır; silmek ayrı.
- Bildirim izni kapalıysa form üstünde tek satır uyarı: "Deneme uyarıları için bildirimleri aç" (Ayarlar'a link). Bu özellik bildirimsiz anlamsız; izin yoksa bile Dashboard rozetleri çalışır.
- 64 bildirim sınırında deneme bildirimleri hatırlatmalardan **önce** gelir (öncelik: deneme bitiş > aynı gün yenileme > diğer).

### Testler

- `TrialPlanningTests`: 3/1/0 gün tarihleri ve saat, bitiş günü `.timeSensitive` + sessiz saatte ses açık, gruplanmama, snooze yok bitiş günü, geçmiş bitiş → hemen.
- `TrialRolloverTests`: cevapsız bitiş → ücretliye dönüşüm ve sonraki hatırlatmalar.
- `RecapServiceTests`: `trialsCancelled` ve `savedAmount`.
- Form validasyonu: geçmiş tarih, tutar boş.
- Toplamlar: denemedeki abonelik aylık toplamda 0, "yaklaşan"da dönüşüm tutarı.

### Claude Design promptu

```
[Ortak tasarım bağlamı]

Feature: "Free trial tracking" — the user marks a subscription as a free trial, Subly counts down and warns hard before the first charge, and the outcome (cancelled / kept) feeds the quarterly recap. This is a money-saving feature; nudge users toward it without nagging.

Design these, each in dark and light:

01 Add subscription form with a "Free trial" toggle row near the top. OFF state = current form. ON state: the amount field becomes "After the trial" (amount + cycle), plus a "Trial ends" row with preset chips 7 · 14 · 30 days and a date value, and a one-line hint "We'll warn you 3 days, 1 day and the morning it ends." Show the catalog suggestion chip that appears above the form when the picked service offers a trial: "Netflix offers a 30-day trial · Add as trial" (lime chip with a tiny gift/clock glyph). Also the notifications-off warning strip: "Turn on notifications to get trial warnings → Settings".

02 Subscriptions list rows on trial: service tile, name, badge "Trial · 5 days" (lime stroke pill), secondary "then $15.49/mo". Variants: 1 day left (filled lime pill "Tomorrow"), last day ("Ends today", lime fill, slightly bolder), cancelled in Archive ("Trial · cancelled", muted).

03 Dashboard with a "Trials" section between the hero and "Next 7 days": compact rows (service, "5 days left", "then $15.49/mo"), and the hero's secondary line gains "+1 trial" in a muted chip. Include the post-expiry info card: "Netflix trial ended yesterday — it's now $15.49/mo" with "Cancelled it" / "OK" buttons.

04 Lock Screen notifications, three steps, expanded with actions:
   a) 3 days: "Your Netflix trial ends in 3 days" / "Then it's $15.49/mo. Keeping it?" · actions "I cancelled" · "Keeping it" · "Remind me tomorrow"
   b) 1 day: "Tomorrow: Netflix trial ends" / "Cancel today or pay $15.49 tomorrow."
   c) Last day (time-sensitive, breaks through quiet hours): "Last day: Netflix" / "Cancel today or $15.49/mo starts." · only "I cancelled" · "Keeping it". Make this one visibly more urgent than Subly's normal reminders but still on-brand (no red; use the lime fill + heavier type + the time-sensitive badge).
   Turkish variants: "Netflix denemen 3 gün sonra bitiyor" / "Sonra $15.49/ay çekilecek. Devam edecek misin?"; "Yarın: Netflix denemen bitiyor"; "Bugün son gün: Netflix" / "Bugün iptal etmezsen $15.49/ay başlıyor." Actions "İptal ettim" · "Devam ediyorum" · "Yarın hatırlat".

05 Subscription detail for a trial: countdown block at the top ("Trial ends in 5 days · Nov 12"), "After the trial: $15.49 / month", two primary actions "I cancelled this" (ghost) and "Keep it" (lime), and the standard sections below. Cancelled state: outcome banner "You cancelled on Nov 10 · saved $185.88/yr".

06 Widgets: medium Home Screen ring widget where one of the three rings is a trial (white stroked ring instead of lime fill, caption "Trial · 2d"); Lock Screen inline line "Netflix trial · 2 days".

07 Nudges: onboarding card "Don't forget your free trials" (one of the existing onboarding slides' style), and a dismissible Dashboard tip "Track your free trials too" with "Add a trial" link.

08 Recap: a small line/card in the quarterly recap: "2 trials ended · you cancelled 1 · saved $185.88/yr".

Show the trial countdown in days only (no hours). Money in tabular numerals. Keep the calm tone everywhere except 04c, which may be louder.
```

---

---

## Bağımlılıklar

- Tamamen cihaz tarafı; tek sunucu değişikliği katalog `trial_days` sütunu (tek satır migration).
- Deneme bildirimleri mevcut `ReminderContentBuilder`'a ayrı dal olarak eklenir; sessiz saat kuralı bitiş günü için atlanır.
- Özet (`RecapService`) `trialsEnded / trialsCancelled / savedAmount` alanlarını kazanır.
- Uzaktan anahtar: `app_config.trial_nudges_enabled`.
