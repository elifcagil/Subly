# Subly — 3 Aylık Özet (Recap) Hikâyesi

**Durum:** ✅ Uygulandı (12 Eki 2026). 13 yeni test (kadans, servis, paylaşım görseli); toplam 59 geçiyor.
Kaynak: `design_handoff_subly_v5 3/CLAUDE_CODE_PROMPT_RECAP.md`, `Subly Monthly Recap.dc.html`.

## Davranış
- **Kadans:** **ilk aboneliğin eklendiği günden** (`Subscription.createdAt`, en eski) itibaren her 3 takvim ayı (`RecapCadence`); abonelik yoksa cihaz kayıt tarihi (`registeredAt`) kullanılır. Yani ilk abonelik 14 Mart'ta eklendiyse ilk özet 14 Haziran'da gelir ve 14 Mart–14 Haziran dönemini kapsar. Ay sonu kayıtları ayın son gününe kırpılır. Dönem n = `[recapDate(n−1), recapDate(n))`.
- **İlk özet** için dönemin tamamında var olan en az bir abonelik gerekir; yoksa atlanır.
- **Veri:** ödeme geçmişi olmadığından tutarlar başlangıç tarihi + döngüden projekte edilir (`PaymentProjector`). Kur çevrilmez; en çok aboneliği olan para birimi kullanılır.
- **Kartlar:** Toplam · En pahalı · (Fiyat artışları — modelde fiyat geçmişi olmadığı için her zaman atlanır) · En uzun süredir · Özet. Veri yoksa kart düşer, üst çubuktaki segment sayısı buna göre azalır.
- **Girişler:** "Özetin hazır" bildirimi (09:00, sessiz saatlere duyarlı, `RECAP` kategorisi → `subly://recap`), Dashboard'da 7 gün görünen lime kart, Takvim → ay görünümü → "Özeti gör" (geçmiş dönemler).
- **Etkileşim:** kart başına 8 sn otomatik ilerleme (üst çubuk dolar), sağ 2/3 dokun → ileri, sol 1/3 → geri, basılı tut → duraklat (chrome 0.4), aşağı kaydır → kapat. "Bitti"/kapat → görüldü işaretlenir.
- **Animasyon:** sayılar 1,5 sn ease-out ile yukarı sayar; halka/çubuk aynı sürede dolar; en uzun süredir kartında kareler ~2,2 sn+ soldan sağa; özet kartında diğer döşemeler Toplam döşemesinden çıkar (1,7 sn, spring). Reduce Motion: 200 ms crossfade, son değerler.
- **Paylaş:** 1080×1920 PNG (`RecapShareRenderer`) → `UIActivityViewController`.

- **Dönem etiketi:** tam ay adlarıyla ("Temmuz–Eylül", yıl aşımında "Kasım 2026–Ocak 2027").

## Dosyalar
`Subly/Domain/UseCases/RecapCadence.swift`, `PaymentProjector.swift`, `RecapService.swift`, `Subly/Domain/Models/Recap.swift`,
`Subly/Services/Recap/RecapScheduler.swift`, `Subly/Modules/Recap/*` (ViewModel, ViewController, Coordinator, Support, Cards/*),
`Subly/Modules/Dashboard/Views/RecapBannerView.swift`, `supabase/migrations/20261012_device_registered_at.sql`.

## QA
`-seedSampleData -recapQA`: kayıt tarihini 3 ay + 2 gün geriye alır, örnek aboneliklerin başlangıcını 8 ay geriye çeker, görülme bayrağını siler → Dashboard'da kart çıkar.

## Sapmalar
- "Review subscriptions" fiyatı artan aboneliklere filtre uygulamıyor (filtre altyapısı ve fiyat geçmişi yok) — Abonelikler sekmesine geçer.
- `registered_at` backend'e kayıt payload'ı yerine ayrı best-effort güncellemeyle gönderilir (migration uygulanmadan kayıt bozulmasın diye).

## Başlık story ikonu (`CLAUDE_CODE_PROMPT_RECAP_STORY_ICON.md`) — ✅ 12 Eki 2026
- Dashboard başlığı sağda `[RecapStoryButton] — 10pt — [Ayarlar]`. Lime "özet hazır" kartı kaldırıldı; ikisi birlikte gösterilmez.
- `RecapStoryButton` (DesignSystem): 40×40, 44 vuruş alanı; 30pt koyu karo + 2pt arka plan rengi boşluk + 24pt stack mark; halka r18, 2,5pt, %72 accent yay (`#C8F169` koyu / `#8CB33A` açık), 1,6 sn/tur doğrusal sonsuz dönüş (`transform.rotation.z`). `didMoveToWindow` ve `willEnterForeground`'da yeniden eklenir; Dashboard görünmezken durur. Reduce Motion: dönüş yok, tam halka.
- Durumlar: `.ready` (dönen yay) · `.seen` (görsel olarak `.ready` ile aynı: halka dönmeye devam eder, simge sönmez — ürün kararı; handoff'taki ince halka/%45 uygulanmadı; yalnızca VoiceOver etiketi "görüldü" der) · gizli (fade + 0,8 ölçek, 200 ms). Hesap saf `RecapStoryState.resolve` (5 test): recapDate'ten 7 gün görünür, açılınca seen, sonraki recap'te yeniden ready.
- Dokunma → hafif haptik → ikonun çerçevesinden zoom geçişi (`RecapZoomTransition`, 0,35 sn spring, köşe 20→0); kapanış geri zoom'lar. Kapandıktan sonra ikon 250 ms'de ready→seen.
- Ayarlar avatarı: baş harf yok; 34pt daire, avatar yüzeyi + 1pt kontrol çizgisi, 16pt semibold "person" simgesi, VoiceOver "Ayarlar".
- VoiceOver: "Özet hazır, {Tem–Eyl}" / "Özet, {Tem–Eyl}, görüldü", ipucu "3 aylık özetini açar".
- Snapshot testleri yazılmadı (projede snapshot altyapısı yok); durum mantığı birim testli.

## Güncelleme: ortak story motoru ve kart 01 teması

`RecapViewController` kaldırıldı; Recap artık `StoryViewController` + `RecapStoryContent` ile çalışır (bkz. `docs/YENILIKLER_HIKAYESI.md`). Kart 01 görünüme göre grafit / kağıt temasını kullanır; diğer kartlar ve paylaşım görseli değişmedi.
