# Subly — Yenileme Döngüsü (Roll-Forward) Geliştirme Planı

**Özellik:** Bir abonelik, kullanıcı silene veya arşivleyene kadar döngüde kalır.
Yenileme tarihi geçtiğinde `nextRenewalDate` otomatik olarak bir sonraki döngü
tarihine ilerler; "Önümüzdeki 7 gün", takvim, bildirimler ve widget'lar hep
canlı kalır.

**Durum:** ✅ Faz 1 UYGULANDI (5 Eyl 2026) — takvime aktarma senkronu (§ Adım 5) hariç;
o v1.1'e ertelendi. Doğrulama: 10 birim testi + simülatörde `-rolloverQA`
launch argümanıyla uçtan uca (dünkü tarih → sonraki döngüye atladı).
**Faz 2 (tamamlama) planı:** aşağıda § 9–13 (12 Eki 2026).

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

- [x] `RenewalDateCalculator`'a takvim enjeksiyonunu bağla (servis `dateProvider.calendar` geçiyor)
- [x] `RenewalRolloverService` + birim testleri (10 test — yeni `SublyTests` target'ı)
- [x] Açılış + öne gelme (`sceneDidBecomeActive`) + gün değişimi (`NSCalendarDayChanged`) tetikleri
- [x] Bildirim yeniden kurma (`schedule` zaten eski bekleyenleri temizliyor)
- [x] `WidgetCenter` reload
- [ ] (Opsiyonel) Takvime aktarma senkronu — v1.1
- [x] Simülatörde uçtan uca doğrulama (`-rolloverQA` launch argümanı ile)

**Tahmini toplam:** ~1 iş günü (takvim senkronu hariç).

---

# Faz 2 — Tamamlama planı (12 Eki 2026)

Faz 1 (Adım 1–4, 6, 7) uygulamada ve testleri geçiyor. Bu bölüm, özelliği
"bitti" diyebilmek için kalan açıkları, kod incelemesinde bulunan boşlukları ve
önerilen sırayı listeler. Her madde bağımsız; sırayla veya seçerek yapılabilir.

## 9. Kod incelemesinde bulunan açıklar

| # | Açık | Etki | Öncelik |
|---|---|---|---|
| A | **Uygulama dışı okuyucular eski tarihi görüyor.** Widget'lar (`SublyWidgets/UpcomingRenewalsWidget.swift`), `NextRenewalIntent` ve `MonthlyTotalWidget`, `SharedSubscriptionProvider.snapshot()` ile store'dan **ham** `nextRenewalDate` okuyor. Bakım geçişi yalnızca uygulama öne gelince çalıştığı için, uygulama birkaç gün açılmazsa widget "No renewals in 14 days", Siri "no upcoming renewals" der — abonelik aslında döngüde. | Kullanıcı görür | **P1** |
| B | **Scheme değişikliği commit edilmemiş.** `Subly.xcscheme` çalışma ağacında `SublyTests` testable'ını ekliyor; `project.yml` zaten `test.targets: [SublyTests]` tanımlıyor ama üretilmiş scheme repoda eski. Temiz klonda `xcodebuild test -scheme Subly` test bulamaz. | CI / ekip | **P1** |
| C | **Ay sonu çapası sürükleniyor.** Tarih, bir önceki `nextRenewalDate` üzerinden zincirleme ilerletiliyor: 31 Oca → 28 Şub → **28 Mar → 28 Nis …** Çapa günü (31) kalıcı olarak kaybolur; ayın 31'inde çekilen bir abonelik sonsuza dek 28'inde görünür. Faz 1'de bilinçli olarak "mevcut davranış korunur" dendi ve `testMonthEndDatesFollowCalendarClamping` bunu belgeliyor; artık düzeltilmeli. | Doğruluk | **P2** |
| D | **Takvime aktarma senkronu yok (Adım 5, v1.1'e ertelenmişti).** Ayrıca mevcut `export` her kayıtta **yeni** etkinlik üretiyor; `CalendarService.remove(eventIdentifier:)` hiçbir yerden çağrılmıyor ve kimlik modelde saklanmıyor → düzenlemede çift etkinlik. Roll-forward bu kanala bağlanırsa her döngüde bir etkinlik daha eklenir. | Takvim kullanıcıları | **P2** |
| E | **Gün değişimi tetiği bir geçişle çakışırsa düşüyor.** `isRunning` koruması ikinci tetiği sessizce atlıyor; tam gece yarısında geçiş sürüyorsa yeni günün eskimiş kayıtları bir sonraki öne gelişe kadar bekler. Nadir, ama ucuz düzeltme. | Kenar durum | P3 |
| F | **Siri ile geçmiş tarihli ekleme.** `AddSubscriptionIntent` tarihi doğrulamadan kaydediyor; A çözülünce okuma anında düzelir, uygulama açılınca kalıcı ilerler. İsteğe bağlı: kayıt öncesi ileri taşı. | Kenar durum | P3 |

## 10. Uygulama adımları

### Adım 8 — Okuma anında projeksiyon: tek yardımcı, iki tüketici (A) — ~1,5 saat

Faz 1'deki "kalıcı ilerletme" kararı (§3) değişmiyor; uygulama içinde store
tek doğruluk kaynağı kalıyor. Ancak **uygulama süreci dışındaki** okuyucular
(widget, intent) store'a yazamaz/yazmamalı; onlar için okuma anında projeksiyon
eklenir.

1. `Subly/Domain/UseCases/RenewalDateCalculator.swift` yanına küçük bir
   uzantı: `Subscription.rolledForward(to today: Date, calendar:) -> Subscription`
   — arşivli değilse ve tarih `startOfDay(today)`'den önceyse
   `upcomingRenewalDate(...)` ile yeni kopya döndürür; aksi hâlde kendisini.
2. `RenewalRolloverService.rollForwardExpired()` bu yardımcıyı kullanacak
   şekilde sadeleştirilir (aynı kural iki yerde yazılmaz).
3. `SharedSubscriptionProvider.snapshot()` sonuçları bu yardımcıdan geçirir.
   Widget'lar ve her iki intent otomatik düzelir; widget/intent koduna
   dokunulmaz.
4. `UpcomingRenewalsProvider.getTimeline` yenileme politikası: 6 saate ek
   olarak **yarının başlangıcı** da entry olarak verilir, böylece widget gece
   yarısı kendiliğinden "bugün yenileniyor" durumuna geçer.
5. Testler (`SublyTests`): yardımcı için — geçmiş tarih ilerler, bugün/ileri
   tarih değişmez, arşivli değişmez; `rollForwardExpired` mevcut 10 test
   kırılmadan geçer.

### Adım 9 — Scheme'i üret ve commit et (B) — ~10 dk

```bash
xcodegen generate
```

Üretilen `Subly.xcscheme` çalışma ağacındaki değişiklikle aynı olmalı
(`git diff` boş ya da yalnızca sıra farkı). Scheme'i commit et;
`UserInterfaceState.xcuserstate` commit edilmez (`.gitignore`'a ekle).

### Adım 10 — Çapa günü koruması (C) — ~2 saat

Kural: döngü tarihi **çapadan n adım** olarak tek seferde hesaplanır,
zincirlenmez. `Calendar.date(byAdding: .month, value: 5, to: 31 Oca)` → 30 Haz
verir; bir sonraki geçişte `value: 6` → 31 Tem. Gün korunur.

- `RenewalDateCalculator.upcomingRenewalDate(from:cycle:relativeTo:)`:
  `n`'i artırarak `date(byAdding: component, value: n * step, to: anchor)`
  ile ilk `>= reference` tarihi bul (mevcut `while` döngüsü ile aynı maliyet).
- Çapa seçimi (`Subscription.rolledForward` içinde):
  `startDate <= nextRenewalDate` **ve** ikisinin ay-günü aynıysa çapa =
  `startDate`; değilse çapa = `nextRenewalDate` (kullanıcı AddEdit'te iki
  tarihi bağımsız seçebiliyor; uyumsuzsa yenileme tarihine güvenilir).
- `SubscriptionDetailViewModel.makePaidSoFar` de zincirliyor; sayım için
  zararsız, dokunulmaz (not düşülür).
- Testler: `testMonthEndDatesFollowCalendarClamping` beklentisi 28 Haz →
  **30 Haz** olarak güncellenir; yeni test: ikinci geçişte (bugün = 5 Tem)
  31 Tem'e döner; 30 Nis başlangıçlı aylık → 30'u korur; yıllık 29 Şub → artık
  olmayan yılda 28 Şub, sonraki artık yılda yine 29 Şub.
- Veri şeması değişmez.

### Adım 11 — Gün değişimi yeniden deneme (E) — ~15 dk

`RenewalRolloverService`: geçiş sürerken gelen tetik `needsRerun = true`
bırakır; `defer` bloğu bayrağı görürse geçişi bir kez daha çalıştırır. Test:
sahte repository `fetchAll` içinde ikinci çağrıyı tetikler → iki geçiş olur,
sonuç idempotent.

### Adım 12 — Takvim senkronu: yineleme kuralı ile (D) — ~3–4 saat, **v1.1**

Önerilen tasarım, roll-forward'u takvime **hiç bağlamamak**: etkinlik bir kez,
döngüye uygun `EKRecurrenceRule` ile aktarılır; döngüyü Takvim uygulaması
kendisi sürdürür.

1. Modele `calendarEventIdentifier: String?` eklenir (`Subscription`,
   `SubscriptionEntity`, Codable anahtarları). Opsiyonel alan → SwiftData
   hafif migration, elle şema sürümü gerekmez; mevcut kayıtlar `nil` okunur.
2. `CalendarService.export` yineleme kuralı ekler: weekly → `.weekly/1`,
   monthly ve custom → `.monthly/1`, quarterly → `.monthly/3`, yearly →
   `.yearly/1`. `isAllDay` zaten açık.
3. `AddEditSubscriptionViewModel.persist`: `calendarExportEnabled` ise önce
   eski kimlik varsa `remove(eventIdentifier:)` (`.futureEvents` span ile),
   sonra `export`, dönen kimliği aboneliğe yazıp tekrar `save`. Bu, bugünkü
   çift etkinlik hatasını da kapatır.
4. Silme ve arşivleme (`SubscriptionDetailViewModel`): kimlik varsa etkinliği
   kaldır. Arşivden çıkarma: yeniden aktar.
5. Ayarlardan "Takvime aktar" kapatılınca: mevcut etkinlikler **kaldırılmaz**
   (kullanıcı verisi); yalnızca yeni aktarım durur. Bu karar ekranda bir
   satırla belirtilir.
6. Testler: `CalendarService` protokol olduğundan spy ile — düzenlemede
   remove→export sırası, kimliğin kaydedildiği, silmede remove çağrısı.
   EventKit'in kendisi simülatörde uçtan uca doğrulanır.

Alternatif (reddedildi): her roll-forward'da yeni tek etkinlik eklemek. Çevrim
dışı/izin hataları ile store ve takvim ayrışır; yineleme kuralı bu sınıfı
tümüyle ortadan kaldırır.

### Adım 13 — Siri girişinde doğrulama (F) — ~15 dk, isteğe bağlı

`AddSubscriptionIntent`: `renewalDate < startOfToday` ise Adım 8'deki yardımcı
ile ileri taşıyıp kaydet; diyalogda taşınan tarihi söyle.

### Adım 14 — Uçtan uca doğrulama — ~45 dk

1. `-rolloverQA` ile dünkü tarihli abonelik ekle, uygulamayı kapat.
2. Simülatörde **Ayarlar → Genel → Tarih ve Saat** otomatikliği kapatıp tarihi
   2 gün ileri al (simctl tarih ayarlayamıyor; cihaz ayarı gerekir).
3. **Uygulamayı açmadan** ana ekrana "Upcoming Renewals" widget'ını ekle →
   abonelik sonraki döngü tarihiyle görünmeli (Adım 8).
4. Uygulamayı aç → 7 gün listesi, takvim ve detayda aynı tarih; bekleyen
   bildirimler yeniden kurulmuş (Ayarlar → Bildirimler).
5. Ayın 31'inde başlayan aylık abonelik ile Adım 10'u gözle doğrula.
6. (v1.1) Takvime aktarım açıkken ekle → Takvim'de yinelenen etkinlik; düzenle
   → tek etkinlik kaldı; sil → etkinlik gitti.

## 11. Sıra, paketleme ve tahmin

| Sıra | Adım | Süre | Sürüm |
|---|---|---|---|
| 1 | 9 — scheme commit | 10 dk | v1.0.1 |
| 2 | 8 — okuma anında projeksiyon | 1,5 sa | v1.0.1 |
| 3 | 10 — çapa günü | 2 sa | v1.0.1 |
| 4 | 11 — gün değişimi yeniden deneme | 15 dk | v1.0.1 |
| 5 | 13 — Siri doğrulama (isteğe bağlı) | 15 dk | v1.0.1 |
| 6 | 14 (1–5) — uçtan uca | 30 dk | v1.0.1 |
| 7 | 12 — takvim yineleme kuralı | 3–4 sa | **v1.1** (şema alanı ekliyor) |
| 8 | 14 (6) — takvim doğrulama | 15 dk | v1.1 |

**v1.0.1 toplamı:** ~yarım iş günü, veri şeması değişmez.
**v1.1 toplamı:** ~yarım iş günü, opsiyonel alan ile hafif migration.

## 12. Karar bekleyenler

1. **Çapa günü (Adım 10):** 31 Oca → 30 Haz → 31 Tem davranışı isteniyor mu,
   yoksa Faz 1'deki "28'e düş ve orada kal" korunsun mu? Öneri: düzelt.
2. **Takvim (Adım 12):** yineleme kuralı (öneri) mi, döngü başına tek etkinlik
   mi? Öneri: yineleme kuralı.
3. **"Takvime aktar" kapatılınca** mevcut etkinlikler kalsın mı? Öneri: kalsın.

## 13. İş listesi (Faz 2)

- [ ] Adım 9 — `xcodegen generate` + scheme commit, `.xcuserstate` ignore
- [ ] Adım 8 — `Subscription.rolledForward` yardımcısı, servis + `SharedSubscriptionProvider` ortak kullanım, widget gece yarısı entry'si, 3 test
- [ ] Adım 10 — çapadan n-adım hesap, çapa seçimi, 4 test, mevcut test güncellemesi
- [ ] Adım 11 — `needsRerun` bayrağı + test
- [ ] Adım 13 — Siri tarih doğrulama (isteğe bağlı)
- [ ] Adım 14 — simülatörde uçtan uca (widget uygulama açılmadan)
- [ ] Adım 12 — `calendarEventIdentifier` + yineleme kuralı + remove/export/sil akışı + spy testleri (v1.1)
