# Subly — Yenileme Döngüsü (Roll-Forward) Geliştirme Planı

**Özellik:** Bir abonelik, kullanıcı silene veya arşivleyene kadar döngüde kalır.
Yenileme tarihi geçtiğinde `nextRenewalDate` otomatik olarak bir sonraki döngü
tarihine ilerler; "Önümüzdeki 7 gün", takvim, bildirimler ve widget'lar hep
canlı kalır.

**Durum:** Planlandı — v1.0 sonrası ilk özellik (veya inceleme reddi olursa v1.0'a alınabilir).

---

## 1. Mevcut durumun özeti (neden gerekli)

- `Subly/Domain/UseCases/RenewalDateCalculator.swift` içinde
  `upcomingRenewalDate(from:cycle:relativeTo:)` zaten yazılmış ama **hiçbir
  yerden çağrılmıyor**.
- `nextRenewalDate` yalnızca ekleme/düzenleme sırasında yazılıyor
  (`AddEditSubscriptionViewModel`). Tarih geçince olduğu yerde kalıyor.
- Sonuç: tarih geçtikten sonra abonelik 7 gün listesinden düşüyor, takvimde
  sonraki aylarda görünmüyor, sonraki döngü için bildirim kurulmuyor.
  (Dashboard aylık toplamı etkilenmiyor — o, tarihten bağımsız aylık eşdeğer
  hesabı yapıyor.)

## 2. Davranış kuralları

| Durum | Beklenen davranış |
|---|---|
| Aktif abonelik, tarihi geçti | Tarih, bugünden **sonraki ilk** döngü tarihine ilerler (gerekirse birden çok döngü atlanır — ör. uygulama 3 ay açılmadıysa) |
| Arşivli abonelik | **Dokunulmaz** — tarih ilerletilmez, bildirim kurulmaz |
| Silinen abonelik | Zaten siliniyor; bakım geçişi kapsam dışı |
| Ay sonu tarihleri (31'i gibi) | `Calendar.date(byAdding:)` davranışı korunur (31 Oca → 28/29 Şub → 28/29 Mar…) — mevcut hesaplayıcının davranışı, değiştirilmiyor |
| Bugün yenilenen | Bugün **ilerletilmez**; gün bitene kadar "bugün yenileniyor" görünür (tarih < bugünün başlangıcı olduğunda ilerletilir) |
| `custom` döngü | Hesaplayıcıdaki mevcut karşılık (aylık) kullanılır |

Kur/tutar değişmez; yalnızca tarih ilerler. Ödeme geçmişi tutulmaz (v1'de
history yok — kapsam dışı, §7).

## 3. Tasarım kararı: kalıcı ilerletme (persist), okuma anında değil

İki seçenek vardı:

- **A) Okuma anında hesapla** (görünümler `upcomingRenewalDate` ile "efektif
  tarih" türetir): Store'a dokunmaz ama bildirim/takvim/widget gibi store'dan
  okuyan her tüketicinin ayrı ayrı düzeltilmesi gerekir; tutarsızlık riski
  yüksek.
- **B) Kalıcı ilerletme (SEÇİLEN)**: Uygulama açılışında ve gün değişiminde tek
  bir bakım geçişi tarihi ilerletip repository'ye kaydeder. Repository'nin
  `observe()` akışı zaten tüm ekranları beslediği için Dashboard, Timeline,
  widget hepsi kendiliğinden güncellenir.

## 4. Uygulama adımları

### Adım 1 — `RenewalRolloverService` (yeni, ~1 saat)
`Subly/Domain/UseCases/RenewalRolloverService.swift`:

```swift
/// Aktif aboneliklerin geçmişte kalan yenileme tarihlerini bugünden sonraki
/// ilk döngü tarihine ilerletir. Değişenleri kaydeder ve döndürür.
struct RenewalRolloverService {
    let repository: SubscriptionRepository
    let calculator: RenewalDateCalculator
    let dateProvider: DateProviding

    @discardableResult
    func rollForwardExpired() async throws -> [Subscription] { ... }
}
```

- `fetchAll` → `!isArchived && nextRenewalDate < startOfToday` filtrele.
- Her biri için `calculator.upcomingRenewalDate(from: nextRenewalDate,
  cycle:, relativeTo: startOfToday)` ile yeni tarih; `repository.save(...)`.
- `RenewalDateCalculator`'a `dateProvider.calendar` enjekte edilmeli (şu an
  `.current` varsayıyor — testlerde sabit takvim için init parametresi zaten var).

### Adım 2 — Tetikleme noktaları (~1 saat)
1. **Açılış:** `AppCoordinator.advanceFromSplash()` öncesinde/paralelinde
   (container üzerinden) `Task { try? await rolloverService.rollForwardExpired() }`.
2. **Öne gelme:** `SceneDelegate.sceneDidBecomeActive` — mevcut
   `retryPendingRegistrationIfNeeded()` çağrısının yanına.
3. **Gece yarısı geçişi:** `NotificationCenter` `.NSCalendarDayChanged`
   dinleyicisi (uygulama açıkken gün değişirse).

Not: Aynı anda iki tetik çakışırsa ikinci geçiş "değişecek bir şey yok" bulur —
idempotent olduğu için kilit gerekmez; yine de servis içinde basit bir
`isRunning` koruması eklenebilir.

### Adım 3 — Bildirimlerin yeniden kurulması (~1-2 saat)
- İlerletilen her abonelik için mevcut hatırlatma tercihine göre
  (`NotificationManager.schedule(for:leadDays:)`) bildirimi yeniden kur.
- Önce o aboneliğin eski bekleyen bildirimleri kaldırılmalı
  (`removePendingNotificationRequests` — id şeması `NotificationManager`'da
  nasılsa ona uy).
- AddEdit akışında bildirimin nasıl kurulduğuna bak, aynı yolu yeniden kullan
  (kod tekrarı yapma — gerekirse ortak bir yardımcıya çıkar).

### Adım 4 — Widget yenileme (~15 dk)
- Bakım geçişi bir şey değiştirdiyse `WidgetCenter.shared.reloadAllTimelines()`
  çağır (uygulama tarafında; widget'lar paylaşılan store'dan okuyor).

### Adım 5 — Takvime aktarma (v1.1'e ertelenebilir)
- "Takvime aktar" açık olan kullanıcıda yeni döngü tarihi için EventKit
  etkinliği ekleme işi ayrı bir iş kalemi. `CalendarService`'in mevcut aktarma
  akışı incelenip aynı kanaldan tetiklenecek. Bu adım riskliyse (izin/çift
  kayıt), özelliğin ilk sürümüne almadan çıkarılabilir — çekirdek değer
  1–4'te.

### Adım 6 — Testler (~2 saat)
`RenewalRolloverServiceTests` (in-memory/fake repository ile):
- Tarihi geçmiş aylık abonelik → bir sonraki aya ilerler.
- 3 ay açılmamış uygulama → tek geçişte bugünden sonraki ilk tarihe atlar
  (3 kez değil, döngüyle doğru sonuca).
- Bugün yenilenen → dokunulmaz.
- Arşivli → dokunulmaz.
- 31 Ocak başlangıçlı aylık → Şubat'ta 28/29'a düşer (takvim davranışı belgelenir).
- Haftalık/3 aylık/yıllık/custom döngüler.
- İkinci çağrı (idempotency) → değişiklik yok.

### Adım 7 — Simülatörde uçtan uca doğrulama (~30 dk)
1. Yenilemesi yarın olan abonelik ekle.
2. Simülatör tarihini 2 gün ileri al (cihaz ayarından veya `simctl` ile
   uygulamayı yeniden başlatarak).
3. Aç: 7 gün listesi ve takvimde tarihin bir sonraki döngüye atladığını,
   bildirimin yeniden kurulduğunu (Ayarlar → Bildirimler bekleyenler) doğrula.

## 5. Sürüm/dağıtım notu

- Veri şeması değişmiyor (yalnızca mevcut alan güncelleniyor) → migration yok.
- App Store sürümü incelemedeyken build değiştirilemez; bu özellik ya v1.0.1
  olarak ayrı gönderilir ya da (henüz gönderilmediyse / ret gelirse) v1.0
  build'ine dahil edilir.

## 6. Riskler

| Risk | Önlem |
|---|---|
| Açılışta store'a yazma yarışı (ekranlar aynı anda okuyor) | Repository `observe()` zaten değişiklikte yeniden yayınlıyor; geçiş idempotent |
| Bildirim id çakışması / çift bildirim | Yeniden kurmadan önce aboneliğin bekleyenlerini kaldır |
| Kullanıcı tarihi elle geçmişe düzenlerse | AddEdit kaydı sonrası da aynı servis çağrılabilir (tek doğruluk noktası) |
| Saat dilimi/gün sınırı | Tüm karşılaştırmalar `dateProvider.calendar.startOfDay` üzerinden |

## 7. Kapsam dışı (bilinçli)

- Ödeme geçmişi kaydı (geçmiş döngüleri arşivleme) — ayrı özellik.
- Kur çevirisi — §8.6 "honest aggregation" kararı değişmiyor.
- Deneme süresi (trial) bitiş akışı — katalogda yok, v2.

## 8. İş listesi (özet)

- [ ] `RenewalDateCalculator`'a takvim enjeksiyonunu bağla
- [ ] `RenewalRolloverService` + birim testleri
- [ ] Açılış + öne gelme + gün değişimi tetikleri
- [ ] Bildirim yeniden kurma (eski bekleyenleri temizleyerek)
- [ ] `WidgetCenter` reload
- [ ] (Opsiyonel) Takvime aktarma senkronu
- [ ] Simülatörde tarih ilerletme senaryosu ile uçtan uca doğrulama

**Tahmini toplam:** ~1 iş günü (takvim senkronu hariç).
