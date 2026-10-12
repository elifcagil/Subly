# Subly — Bildirim İzni ve Yenileme Hatırlatmaları

**Durum:** ✅ Uygulandı (12 Eki 2026). 24 yeni birim testi (toplam 33) geçiyor;
simülatörde giriş popup'ı → sistem izni → Ayarlar'da anahtar açık / "İzin: Etkin"
doğrulandı. Tasarım kaynağı: `design_handoff_subly_v5/CLAUDE_CODE_PROMPT_REMINDER_NOTIFICATION.md`.

## 1. Davranış

| Durum | Ne olur |
|---|---|
| Kullanıcı ana ekrana ilk girdiğinde (kayıt/onboarding sonrası) ve iOS izni henüz sorulmamışsa | Önce açıklayıcı popup ("Haberin olsun"), "Bildirimlere İzin Ver" → sistem diyaloğu. Bir kez sorulur; "Şimdi değil" bir daha sormaz. Onboarding'den "ilk aboneliğini ekle" ile gelindiyse popup, ekleme formu kapandıktan sonra çıkar. |
| İzin verildi | Ayarlar → Bildirimler anahtarı **açılır**, 60 günlük hatırlatma seti kurulur, backend'deki `devices.notifications_enabled` = true. |
| İzin reddedildi | Anahtar kapalı kalır; kısa bir "Hatırlatıcılar kapalı — Ayarlar'ı Aç" uyarısı. Uygulama "iOS Ayarlar'dan izin bekliyor" bayrağını tutar. |
| Kullanıcı iOS Ayarlar'dan izni açıp geri döner | Öne gelişte bayrak kontrol edilir; izin varsa anahtar **kendiliğinden açılır**, hatırlatmalar kurulur, backend güncellenir. |
| Ayarlar → "İzin" satırına dokunma | Sorulmamışsa sistem diyaloğu; sorulmuşsa iOS Ayarlar → Subly → Bildirimler sayfası açılır. |
| Ayarlar → Bildirimler anahtarını açma (iOS'ta kapalıyken) | Anahtar geri kapanır, "Ayarlar'ı Aç" uyarısı. |
| Abonelik ekleme/düzenleme/arşiv/silme, roll-forward, saat değişimi, öne geliş | Hatırlatma seti **tek yerden** yeniden kurulur (`ReminderSyncService.resync`). |

## 2. Hatırlatma içeriği (handoff'a göre)

- Her abonelik için "Hatırlat" sapması N (aynı gün / 1 / 3 / 7 gün önce; birden
  çok seçilebilir). Yenilemeden N gün önce **09:00**'da bir yerel bildirim.
- Sessiz saatler (varsayılan 22:00–08:00; henüz ayar ekranı yok) içine düşen
  teslimat, pencere bitimine kaydırılır.
- N "aynı gün" değilse yenileme günü ayrıca **aynı gün** bildirimi (time-sensitive).
  "Aboneliği tut" denmişse o yenileme için gönderilmez.
- Aynı teslimat gününe denk gelen 2+ abonelik → **tek gruplanmış** bildirim
  ("2 yenileme yarın · Netflix ve Spotify · toplam $25"). Farklı kurlar
  toplanmaz, ayrı yazılır.
- Metin tablosu `Strings.Reminders` (en + tr). Kategoriye göre fiil: Streaming →
  "watching", Music → "listening", diğer → "using it".
- `threadIdentifier = "renewals"`, `userInfo`: subscriptionId, renewalDate, amount,
  currency, offsetDays, name, categoryId.
- Ufuk 60 gün, iOS'un 64 bekleyen isteği sınırı için en yakın tarihler öncelikli
  (smart/awareness istekleri düşüldükten sonra).
- Kimlikler: `reminder.<id>.<yyyy-MM-dd>`, `sameday.<id>.<date>`,
  `grouped.<teslimat-günü>`, `snoozed.<id>.<date>`. Eski `renewal.*` /
  `subscription.*` kayıtları ilk yeniden kurulumda temizlenir.

### Aksiyonlar
| Kategori | Aksiyonlar |
|---|---|
| `RENEWAL_REMINDER` (yenilemeye ≥ 2 gün) | Aboneliği tut · Yarın hatırlat · Subly'de incele |
| `RENEWAL_REMINDER_IMMINENT` (bugün/yarın) | Aboneliği tut · Subly'de incele |
| `RENEWAL_REMINDER_GROUPED` | Subly'de incele |

"Subly'de incele" ve bildirime dokunma → Abonelikler sekmesinde ilgili detay
ekranı (uygulama kapalıyken açılırsa bağlantı ana kabuk kurulunca işlenir).

## 3. Dosyalar

| Dosya | Görev |
|---|---|
| `Subly/Services/Notifications/ReminderContentBuilder.swift` | Saf plan üretici: metin, zaman, gruplama, sessiz saat, sınır |
| `Subly/Services/Notifications/ReminderScheduler.swift` | `UNUserNotificationCenter` cephesi, kategoriler, "tut" kayıtları |
| `Subly/Services/Notifications/ReminderSyncService.swift` | Tek yeniden kurma noktası + `significantTimeChange` |
| `Subly/Services/Notifications/NotificationPermissionService.swift` | İzin durum makinesi (giriş sorusu, verildi/reddedildi, Ayarlar'dan dönüş) |
| `Subly/Services/Notifications/NotificationActionHandler.swift` | Tut / yarın hatırlat / incele yönlendirmesi |
| `Subly/Services/Registration/DeviceProfileService.swift` | Supabase `devices` satırına bayrak yazma (best-effort) |
| `Subly/Modules/TabBar/TabBarCoordinator.swift` | Giriş popup'ı, red uyarısı, derin bağlantı |
| `Subly/Modules/Settings/*` | İzin satırı tıklanabilir, anahtar izinle bağlı, öne gelişte yenileme |
| `SublyTests/ReminderContentBuilderTests.swift` (17) · `NotificationPermissionServiceTests.swift` (7) | Birim testleri |

## 4. Backend

`supabase/migrations/20261012_device_notifications.sql` çalıştırılmalı:
`devices.notifications_enabled boolean` + `notifications_updated_at` sütunları ve
kendi satırını güncelleme politikası. Migration uygulanana kadar yazma denemesi
loglanıp yutulur; uygulama etkilenmez.

## 5. Handoff'tan bilinçli sapmalar / ertelenenler

- **İzin ne zaman sorulur:** handoff "ilk abonelik eklendikten sonra" diyor;
  istek üzerine **girişte** soruluyor (ilk-ekleme akışında form kapanınca).
- **Sessiz saatler ayar ekranı** yok; varsayılan 22–08 sabit.
- **Notification Content Extension** (uzun basınca açılan geri sayımlı kart,
  D2/L2) ayrı bir Xcode hedefi + App Group paylaşımı gerektiriyor; bu turda
  yapılmadı. Kategori kimlikleri ve `userInfo` o hedefin ihtiyacına göre
  hazır.
- `.timeSensitive` kesinti seviyesi için
  `com.apple.developer.usernotifications.time-sensitive` entitlement'ı eklenmedi;
  eklenene kadar iOS aynı gün bildirimini normal (`.active`) teslim eder.
- "Aboneliği tut" aksiyonunda hafif haptik: arka plan aksiyonunda cihaz titreşimi
  çalışmadığı için atlandı.

## 6. QA

- `-resetNotificationPrompt` launch argümanı giriş popup'ını yeniden gösterir.
- Simülatörde reddetme senaryosu: popup'ta "İzin Verme" → "Hatırlatıcılar kapalı"
  uyarısı → "Ayarlar'ı Aç" → iOS Ayarlar'da izni aç → uygulamaya dön →
  Ayarlar'da anahtar açık olmalı.
- Bekleyen bildirimleri görmek için: abonelik ekleyip Xcode → Debug →
  `UNUserNotificationCenter.current().pendingNotificationRequests()` (ya da
  cihaz tarihini ileri alıp teslimatı izle).
