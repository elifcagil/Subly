# Subly — Sessiz Saatler (Quiet Hours)

**Durum:** ✅ Uygulandı (12 Eki 2026). 9 yeni test (`QuietHoursTests`) + güncellenen üretici testleri; toplam 73 geçiyor. Simülatörde Ayarlar → Sessiz saatler ekranı, ön ayar ve zaman seçici doğrulandı.
Kaynak: `design_handoff_subly_v5 5/CLAUDE_CODE_PROMPT_QUIET_HOURS.md`, `Subly Quiet Hours.dc.html`.

## ⚠ Davranış değişikliği
Önceki kural (09:00 sessiz saate düşerse pencere bitimine ertele) **kaldırıldı**. Yeni kural:
- Her hatırlatıcı **zamanında** teslim edilir.
- Teslimat sessiz pencerenin içindeyse **sessiz**: `sound = nil`, `interruptionLevel = .passive` (banner/ses/ekran yok, Bildirim Merkezi'ne düşer), `threadIdentifier = "renewals"` korunur.
- Pencere dışında: normal (`.default` ses, `.active`); aynı gün hatırlatıcısı `.timeSensitive`.
- **"Yenileme günü uyarıları"** (varsayılan kapalı): açıksa sessiz saatlerdeki aynı-gün hatırlatıcıları ses + `.timeSensitive` kalır; diğer sapmalar sessiz.
- Pencere **zamanlama anında** hesaplanır (`QuietHours.deliveryStyle`). Ayar değişince `ReminderSyncService` tüm bekleyen istekleri aynı kimliklerle yeniden kurar (`startObservingQuietHours`).
- Pencere matematiği: `start > end` → gece yarısını aşar (`t >= 22:00 || t < 08:00`); `start == end` → pencere yok; gün filtresi pencerenin **başladığı güne** göre (Cum 22:00 → Cmt 08:00 Cuma'ya aittir).

## Model / servis
- `QuietHours` (`Subly/Domain/Models/QuietHours.swift`): `isEnabled`, `start/end: DateComponents`, `weekdays: Set<Int>` (1=Pazar…7=Cumartesi), `renewalDayAlertsWithSound`; `isQuiet(at:calendar:)`, `deliveryStyle(for:isSameDay:calendar:)`, `durationMinutes`, ön ayarlar.
- `DeliveryStyle`: `.normal / .silent / .timeSensitive`.
- `QuietHoursService` + `QuietHoursStore` (App Group UserDefaults, JSON) — widget/uzantı aynı pencereyi okuyabilir.
- Recap bildirimi ve "Yarın hatırlat" ertelemesi de aynı kuralı uygular.
- Backend: `devices.quiet_hours jsonb` + `time_zone text` (`supabase/migrations/20261012_device_quiet_hours.sql`), best-effort güncelleme. Uzak push gelirse: görünür push, `interruption-level: passive`, `thread-id: renewals`, sessiz teslimatta `sound` yok; `content-available` arka plan push'u **kullanılmaz**.

## Ekranlar (`Subly/Modules/Settings/QuietHours/`)
- **01 Sessiz saatler:** büyük başlık + nav bar ana anahtarı (kapalıyken halka kartı %40 ve etkileşimsiz). 200pt 24 saatlik halka: iz 18pt, 24 tik (6 saatlikler r54/2pt, diğerleri r58/1,2pt), 00/06/12/18 etiketleri r44, sessiz yay (`#C8F169` koyu / `#8CB33A` açık), ay/güneş tutamaçları (26pt), ortada süre ("10s" / "9s 30dk"). Tutamaçlar sürüklenir: 5 dk kilitleme, adım başına `.selection`, saat geçişinde hafif haptik. Altında Başlangıç/Bitiş karoları (dokun → sheet), 4 ön ayar çipi (tam eşleşmede lime), Günler satırı (çok seçimli hafta günü listesi; "Her gün / Hafta içi / Hafta sonu / kısa gün listesi"), Yenileme günü uyarıları anahtarı, vurgulu dipnot.
- **02 Zaman seçici sheet:** medium detent + grabber, İptal / "Başlangıç saati" / Ayarla, Başlangıç|Bitiş segmentleri, tekerlek `UIDatePicker` 5 dk adım, "24 saat biçimi cihaz ayarını izler" notu. Ayarla → halka yaya spring animasyonuyla geçer.
- Ayarlar listesinde "Sessiz saatler · 22:00 – 08:00 / Kapalı" satırı; değişiklikte satır anında güncellenir.
- Erişilebilirlik: halka tek `adjustable` eleman ("Sessiz saatler, 22:00 – 08:00, 10s."), artır/azalt seçili tutamacı 15 dk oynatır, özel eylemlerle tutamaç seçimi.

## Sapmalar
- Seçim bandı rengi (accent tint) `UIDatePicker` tekerleğinde özelleştirilemiyor; sistem bandı kullanılıyor.
- Gün listesi inset-grouped tablo (handoff ayrıntı vermiyor).
