# Subly — Zam Alarmı (katalog fiyatı yükselince bildirim)

Tasarım dosyası gelince `CLAUDE_CODE_PROMPT_<FEATURE>.md` handoff'u yazılır ve geliştirme ona göre yapılır. Prompt İngilizce (önceki handoff'larla aynı dil), metin örnekleri TR/EN.

Ortak tasarım bağlamı (her prompta kopyalanır):

> Subly is a calm, minimal iOS subscription tracker. UIKit, MVVM-C. Design system: graphite `#16181C` surfaces in dark, warm paper `#F3EFE6` in light; electric-lime accent `#C8F169` with near-black `#141609` content on lime fills (lime text/strokes become olive `#5F7F1C` on light surfaces); SF Pro, heavy headlines with tight tracking, tabular numerals for money; 22pt side gutters; cards with 22pt continuous corners; floating pill tab bar (Home · Subs · Timeline) with a separate lime FAB. Service tiles are rounded squares with the brand letter. Existing references: `Subly v5 (Dark).dc.html`, `Subly v5 (Light).dc.html`, `Subly Reminder Notification.dc.html`. Deliver every screen in dark AND light, iPhone 15/16 Pro frame (393×852), plus states listed below.

---

---

## Zam Alarmı (katalog fiyatı yükselince bildirim)

### Ürün davranışı

- Katalogdaki bir servisin fiyatı yükselince, o servisi takip eden kullanıcıya **tek** bildirim: "Netflix zam yaptı. Planın $15.49'dan $17.99'a çıkacak."
- Bildirime basılı tutunca: **Fiyatı güncelle** (aboneliğin tutarı yeni fiyat olur, eski fiyat geçmişe yazılır), **Değişmedi** (bu zam bu abonelik için bir daha sorulmaz), **İncele** (abonelik detayı açılır).
- Abonelik detayında yeni bir **Fiyat geçmişi** satırı; özetin "Fiyat artışları" kartı artık gerçek veriyle dolar.
- Kullanıcının kendi girdiği tutar katalogdan düşükse ve katalog yükselmişse de alarm gelir (tutarı güncel değilse bile zam haberi anlamlı). Kullanıcı tutarı zaten yeni fiyata eşit ya da yüksek girmişse alarm gelmez.

### Neden iki faz

Sunucu kimin hangi aboneliğe sahip olduğunu bilmiyor (anonim model). Push atabilmek için cihazın takip ettiği **servis adlarını** (tutar değil) sunucuya yansıtması gerekir. Bu küçük bir gizlilik genişlemesi; önce push'suz, cihaz tarafı çözümle çıkılır, push ikinci fazda eklenir.

**Faz 1 — Cihaz tarafı (push yok, hemen çıkabilir).**
Uygulama her ön plana gelişte katalog fiyatlarını zaten çekiyor. Yeni çekilen fiyatlar, önbellekteki son fiyatlarla karşılaştırılır; yükselen her servis için kullanıcının eşleşen aboneliği varsa yerel bildirim planlanır (hemen, ya da sessiz saatlerdeyse sessiz). Gecikme: kullanıcı uygulamayı açana kadar. Bu kabul edilebilir; zam haberi saatlik değil.

**Faz 2 — Push (sunucudan tetikleme).**
`devices.tracked_services text[]` sütunu; cihaz, aktif aboneliklerinin katalog adlarını (eşleşenleri) yansıtır. `catalog_prices` üzerinde `after update` tetikleyici → Edge Function → o servisi içeren cihazlara APNs push. Bu faz APNs altyapısını (token kaydı, sertifika, `device_tokens`) gerektirir; aynı altyapı ileride hatırlatma push'ları için de kullanılır.

### Veri modeli

Sunucu (migration `2026MMDD_catalog_price_history.sql`):

```sql
create table if not exists public.catalog_price_history (
  id            bigint generated always as identity primary key,
  name          text not null references public.catalog_prices(name) on delete cascade,
  old_amount    numeric(10,2) not null,
  new_amount    numeric(10,2) not null,
  currency_code text not null,
  billing_cycle text not null,
  effective_at  timestamptz not null default now()
);
alter table public.catalog_price_history enable row level security;
create policy "Price history is public" on public.catalog_price_history for select to anon, authenticated using (true);

-- Her fiyat değişikliğini otomatik kaydet (dashboard'dan fiyat güncellenince yeter).
create or replace function public.log_catalog_price_change() returns trigger language plpgsql as $$
begin
  if new.amount <> old.amount then
    insert into public.catalog_price_history (name, old_amount, new_amount, currency_code, billing_cycle)
    values (new.name, old.amount, new.amount, new.currency_code, new.billing_cycle);
    new.updated_at := now();
  end if;
  return new;
end $$;
drop trigger if exists catalog_price_change on public.catalog_prices;
create trigger catalog_price_change before update on public.catalog_prices
  for each row execute function public.log_catalog_price_change();
```

Cihaz (`Subscription`):

```swift
struct PriceChange: Codable, Equatable, Sendable {
    let oldAmount: Decimal
    let newAmount: Decimal
    let currencyCode: String
    let changedAt: Date
    let source: Source            // .catalog | .manual
}
var priceHistory: [PriceChange] = []          // yeni alan, Core Data'da JSON (transformable) ya da ayrı entity
var catalogName: String?                      // katalogdan eklendiyse eşleşme anahtarı (adı değiştirse de eşleşir)
var dismissedPriceAlerts: [String] = []       // "netflix:17.99" — "Değişmedi" denilen alarmlar
```

Özet servisi (`RecapService`) "fiyat artışları" kartını `priceHistory` içinde dönem içine düşen `.catalog`/`.manual` artışlardan hesaplar; `yearlyDelta` = (yeni − eski) × yıllık döngü katsayısı.

### İstemci akışı (Faz 1)

1. `CatalogPriceService.refreshIfNeeded()` yeni fiyatları alınca `PriceAlertService.evaluate(old:new:subscriptions:)` çağrılır.
2. Her `name` için: `new.amount > old.amount` ve kullanıcının `catalogName == name` (yoksa ad eşleşmesi, küçük harf) olan aktif aboneliği var ve `subscription.amount < new.amount` ve alarm `dismissedPriceAlerts`'ta değil → aday.
3. Aday başına bir `UNNotificationRequest`, identifier `price.<subscriptionID>.<newAmount>` (idempotent; aynı zam iki kez bildirilmez). Trigger: 1 saniye sonra; sessiz saatlerdeyse `.passive` + ses yok. Kategori `PRICE_ALERT`, aksiyonlar: `price.update` (arka planda tutarı güncelle, `priceHistory`'ye `.catalog` kaydı), `price.dismiss` (`dismissedPriceAlerts`'a ekle), `price.review` (uygulamayı aç, detaya git).
4. Uygulama ön plandayken aynı olay için bildirim yerine Dashboard'un üstünde **Zam kartı** gösterilir (kapatılabilir, aynı üç aksiyon).
5. Abonelik detayında **Fiyat geçmişi** bölümü: tarih · eski → yeni · kaynak etiketi ("Katalog" / "Sen").
6. Kullanıcı tutarı elle değiştirince `.manual` kaydı eklenir (özet kartı için).

Bildirim metni (TR/EN):
- Başlık: "Netflix zam yaptı" / "Netflix raised its price"
- Gövde: "Planın $15.49'dan $17.99'a çıkacak. Yılda +$30." / "Your plan goes from $15.49 to $17.99. That's +$30 a year."
- Aksiyonlar: "Fiyatı güncelle" / "Update price", "Değişmedi" / "Not for me", "İncele" / "Review"

### Kenar durumları

- Fiyat düşerse alarm yok; ama geçmişe `.catalog` kaydı düşer ve detayda görünür ("İndirim" etiketi).
- Para birimi farklıysa (katalog USD, kullanıcı TRY) alarm **gösterilmez**; kur çevirimi yokken yanlış rakam vermek zararlı.
- Aynı servisin birden fazla planı olabilir (Netflix Standard/Premium); katalog tek fiyat tuttuğu için metin "Netflix fiyatlarını güncelledi" olur ve tutar kıyası yalnızca kullanıcının tutarı katalogdan düşükse yapılır. Katalog ileride plan bazlı olursa (`plan` sütunu) metin netleşir.
- Önbellek yoksa (ilk kurulum) karşılaştırma yapılmaz; sadece önbellek yazılır.
- 64 bekleyen bildirim sınırı: zam bildirimleri hatırlatmalarla aynı havuzda; planlayıcıdaki `unrelatedPendingCount` bunu zaten sayar.

### Testler

- `PriceAlertServiceTests`: yükselen/düşen/eşit fiyat, eşleşmeyen ad, farklı para birimi, kullanıcı tutarı zaten yüksek, dismissed, idempotent identifier.
- `RecapServiceTests`: `priceHistory` ile "fiyat artışları" kartı dolu/boş.
- Migration kontrol sorgusu: `catalog_prices` güncelle → `catalog_price_history` satırı.

### Claude Design promptu

```
[Ortak tasarım bağlamı]

Feature: "Price Alert" — Subly tells the user when a service they track raises its catalog price, and lets them update their subscription in one tap.

Design these screens, each in dark and light:

01 Lock Screen notification (expanded, long-press state). Title "Netflix raised its price", body "Your plan goes from $15.49 to $17.99. That's +$30 a year." App icon = Subly mark. Three actions below: "Update price" (primary feel), "Not for me", "Review". Show the collapsed banner variant too. Turkish copy variant: "Netflix zam yaptı" / "Planın $15.49'dan $17.99'a çıkacak. Yılda +$30." / "Fiyatı güncelle" · "Değişmedi" · "İncele".

02 Dashboard with a "Price alert" card at the top of the scroll, above "Next 7 days": service tile (N), headline "Netflix raised its price", old → new amount with a small up-arrow, yearly delta "+$30/yr", two buttons "Update price" (lime) and "Not for me" (ghost), a subtle close ×. Show the same card for TWO alerts stacked (second collapsed to one line "Spotify · $10.99 → $11.99").

03 Subscription detail with a new "Price history" section under the amount: rows "Oct 2026 · $15.49 → $17.99 · Catalog", "Jan 2025 · $12.99 → $15.49 · You". The most recent increase gets a lime chip "+$30/yr". Include the empty state ("No price changes yet").

04 Recap story card "Price increases" (existing card in Subly Monthly Recap.dc.html) now populated with real data: "2 of your subscriptions got pricier" headline, total "+$42/yr", list of the two services with old → new. Match the existing recap card style (radial indigo background, white ink).

05 Settings → Notifications: a new toggle row "Price alerts" with footer "We'll tell you when a service you track raises its price." Default ON.

States: single alert, two alerts, alert while quiet hours (notification shown silent, no sound glyph), currency mismatch (no alert — nothing to design, just note it). Use tabular numerals for money. Keep everything calm: one accent (lime) per screen, no red.
```

---

---

## Bağımlılıklar

- Faz 1 yeni sunucu altyapısı istemez: `catalog_price_history` migration + istemci karşılaştırması.
- `priceHistory` alanı özetin boş kalan "fiyat artışları" kartını doldurur.
- `catalogName` alanı Siri'nin ekleme intent'iyle ortak (bkz. `PLAN_SIRI_KISAYOLLAR.md`).
- Faz 2 (push) APNs altyapısı ister; aynı yol ileride hatırlatma ve "özet hazır" push'ları için kullanılır.
- Uzaktan anahtar: `app_config.price_alerts_enabled`.
