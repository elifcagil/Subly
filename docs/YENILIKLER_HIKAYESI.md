# Yenilikler (What's New) hikâyesi

Handoff: `CLAUDE_CODE_PROMPT_WHATS_NEW.md`, tasarım: `Subly Whats New.dc.html`, `Subly Monthly Recap.dc.html`.

## Ortak story motoru

Recap ve Yenilikler aynı motoru kullanır (`Subly/Modules/Story/`):

- `StoryPlayer`: kart indeksi, kart başına otomatik ilerleme, duraklatma. `lastCardAutoAdvances = false` → son kart düğmesini bekler. `advance(by:)` testlerde saati ilerletmek için açık.
- `StoryViewController`: parçalı ilerleme çubuğu, başlık, ×, alt ipucu; sağ 2/3 dokunma → ileri, sol 1/3 → geri, basılı tutma → duraklat, aşağı kaydırma / × → kapat. Görünüm değişince `followsAppearance` kartlar 200 ms çapraz geçişle yeniden çizilir.
- `StoryCardView` + `StoryContent` protokolü: her hikâye kartlarını, paletini ve ipucunu sağlar (`RecapStoryContent`, `WhatsNewViewModel`).
- `StoryIntroTheme`: giriş kartları için `.graphite` (koyu) / `.paper` (açık) renk tokenleri. Recap kart 01 ve Yenilikler kart 01 bunu kullanır.

## Sürüm anahtarı (`WhatsNewPayload.isEnabled`)

Hikâye kullanıcıya **bir kez**, güncelleme sonrası ilk açılışta gösterilir. Sürümler arasında `isEnabled = false` tutulur; payload bir sonraki Yenilikler için şablondur. Yeni bir Yenilikler yayınlamak için:

1. Yeni payload'ı yaz (`release101` kopyala), `payloads` sözlüğüne yeni `CFBundleShortVersionString` ile ekle.
2. `isEnabled = true` yap.
3. O sürümden sonra tekrar `false` yap.

`false` iken açılışta hikâye gelmez ve Ayarlar'daki "Yenilikler" satırı görünmez. `-whatsNewQA` argümanı QA için anahtarı geçici olarak açar.

## Ne zaman gösterilir

- Anahtar açıkken sürüm başına bir kez, güncelleme sonrası ilk açılışta, Dashboard'dan önce (`AppCoordinator.presentWhatsNewIfDue`).
- `WhatsNewGate.shouldShow(currentVersion:lastSeenVersion:hasPayload:)`: `CFBundleShortVersionString` > kaydedilen sürüm **ve** bu sürüm için payload varsa.
- Yeni kurulumlar görmez: kayıt tamamlanınca `WhatsNewStore.markSeen(version:)` damgalanır.
- Kapatılınca (düğme, ×, kaydırma) görüldü sayılır; ardından bildirim izni istemi gelir.
- Ayarlar → Güncellemeler → Yenilikler satırından yeniden açılabilir (payload olan sürümlerde görünür).
- Recap ile çakışmaz: Recap yalnızca başlık ikonundan açılır, Yenilikler kapanmadan görünmez.

## İçerik

`WhatsNewPayload.payloads` sürüm anahtarlı (şu an `"1.1.0"`). Yeni sürümde: payload'ı yeni sürüm anahtarıyla ekle, kartları güncelle. Metinler `Strings.WhatsNew` (en/tr).

Kartlar: 01 giriş (tema bağımlı, 5 numaralı satır — her numara gittiği kartın rengi), 02 ana ekran widget'ları, 03 kilit ekranı widget'ları, 04 akıllı hatırlatmalar, 05 sessiz saatler, 06 Recap finali (132 pt `RecapStoryButton(metrics: .hero)`, sürekli döner; ilk özet tarihi `RecapScheduler.nextRecapDate()`).

Kart süresi 10 sn (Recap 8 sn): adım listeleri rahat okunsun diye. Giriş animasyonları: halkalar 0 → değer (0.9 sn), bildirim 12 pt aşağı kayarak belirir, sessiz yay çizilir. Hareketi Azalt açıkken son durum gösterilir.

## Recap kart 01

Lime zemin kalktı; koyu modda grafit `#16181C`, açık modda kağıt `#F3EFE6`. Geçerli ay çubuğu ve karşılaştırma satırı koyu modda lime, açık modda mürekkep / `#5F7F1C`. Paylaşım görselindeki "Toplam" karosu lime kalır (`RecapPalette.limeTotal`).

## QA

`-whatsNewQA`: görülen sürümü unutur; `-seedSampleData -whatsNewQA -recapQA` ile açılışta hikâye gelir.

## Testler

`WhatsNewGateTests`, `StoryPlayerTests`, `StoryIntroThemeTests` (tema çözümü, kart 01 paleti, ilk özet tarihi biçimi). Snapshot testi altyapısı olmadığı için görsel doğrulama simülatör ekran görüntüleriyle yapıldı.
