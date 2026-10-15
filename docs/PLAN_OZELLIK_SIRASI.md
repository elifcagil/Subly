# Subly — Üç özellik: önerilen sıra

Ayrıntılar: `PLAN_DENEME_SURESI.md`, `PLAN_ZAM_ALARMI.md`, `PLAN_SIRI_KISAYOLLAR.md`.

1. **Deneme süresi takibi** — tamamen cihaz tarafı, yeni sunucu altyapısı gerektirmez, en yüksek kullanıcı değeri. Katalog `trial_days` tek satır migration.
2. **Zam alarmı Faz 1** — `catalog_price_history` migration + istemci karşılaştırması; `priceHistory` alanı özetin boş kalan kartını da doldurur. `catalogName` alanı Siri'nin ekleme intent'iyle ortak.
3. **Siri & Kısayollar** — mevcut üç intent'in üstüne; en az risk, App Store'da iOS 26 vitrinine girer.
4. **Zam alarmı Faz 2 (push)** — APNs altyapısı; sonrasında hatırlatma push'ları ve "özet hazır" push'u aynı yoldan gelir.

Her özellik için tasarım dosyası gelince: `CLAUDE_CODE_PROMPT_<FEATURE>.md` yazılır, migration'lar `supabase/migrations/` altına eklenir, uzaktan anahtarlar `app_config`'e eklenir (`price_alerts_enabled`, `trial_nudges_enabled`, `siri_tip_enabled`).
