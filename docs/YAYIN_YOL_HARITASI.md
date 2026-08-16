# Subly — App Store Yayın Yol Haritası

Bu doküman üç işi sırasıyla anlatır:
1. Apple Developer hesabı açma (Bireysel)
2. Supabase'i cihaz kaydı (device register) için bağlama
3. Uygulamayı App Store'a gönderme

**Alınan kararlar:**
- Hesap türü: **Bireysel (Individual)**
- v1.0 kapsamı: **sadece cihaz kaydı** — Paywall (IAP) ve Apple ile Giriş v1'de KAPALI
- Supabase güvenlik modeli: **Anonymous Sign-In + RLS**

> Not: `docs/SUPABASE_YOL_HARITASI.md` dosyası kullanıcı hesabı + abonelik senkronu
> senaryosunu anlatır. O, v2 planıdır. v1 için **bu doküman** geçerlidir.

---

## 0. Yayını engelleyen 4 sorun — ✅ ÇÖZÜLDÜ

Aşağıdaki dört sorun tespit edildi ve düzeltildi. Bu bölüm neyin neden
değiştiğinin kaydıdır; yeniden yapılacak bir iş yok.

| # | Sorun | Durum |
|---|---|---|
| 0.1 | Takvim izni açıklaması yok → çökme | ✅ `project.yml` + `*/InfoPlist.strings` (tr/en) |
| 0.2 | `PrivacyInfo.xcprivacy` yok → yükleme reddi | ✅ Hem app hem widget paketinde |
| 0.3 | Kayıt ekranı zorunlu geçit → 2.1 reddi | ✅ `OfflineTolerantRegistrationService` |
| 0.4 | Sürüm 0.1.0 | ✅ 1.0.0 (her iki target) |
| 0.5 | Paywall + Apple ile Giriş v1'de açık | ✅ İkisi de kapatıldı |

**Doğrulama (simülatörde çalıştırılarak):**
- `xcodebuild` → BUILD SUCCEEDED, hata yok.
- Ayarlar ekranı artık GÖRÜNÜM ile başlıyor; PLAN bölümü (Subly Plus + Hesap) yok.
- Sürüm satırı "1.0.0 (1)" gösteriyor.
- Takvim izni sıfırlanıp "Takvime aktar" açıldığında **çökme yok**; iOS izin
  diyaloğu Türkçe metnimizle çıkıyor. "İzin Verme" seçilince uygulama düzgün
  hata veriyor ve anahtar kapalıya dönüyor.

### 0.1 ✅ Takvim izni açıklaması yok → uygulama ÇÖKER
`Subly/Services/Calendar/CalendarService.swift` gerçek EventKit kullanıyor
(`EKEventStore`, abonelik takvime aktarma). Ama `Subly/Resources/Info.plist`
içinde **hiçbir UsageDescription yok** (0 adet).

iOS'ta izin açıklaması olmadan takvim erişimi istemek uygulamayı anında
crash ettirir. Eklenmesi gerekenler (`project.yml` → `targets.Subly.info.properties`):

```yaml
NSCalendarsFullAccessUsageDescription: "Yaklaşan abonelik yenilemelerini takviminize eklemek için takvim erişimi gerekiyor."
NSCalendarsWriteOnlyAccessUsageDescription: "Abonelik yenilemelerini takviminize eklemek için izin gerekiyor."
NSCalendarsUsageDescription: "Abonelik yenilemelerini takviminize eklemek için izin gerekiyor."
```
(iOS 17+ ilk ikisini kullanır; üçüncüsü eski sürümler için geriye dönük uyumluluk.)

### 0.2 🔴 `PrivacyInfo.xcprivacy` yok → yükleme reddedilir
1 Mayıs 2024'ten beri Apple, "required reason API" kullanan uygulamalardan
gizlilik manifest dosyası istiyor. Subly `UserDefaults` kullanıyor (bu listede),
ayrıca cihaz kaydıyla birlikte cihaz kimliği topluyor. Dosya olmadan App Store
Connect yüklemede ITMS uyarısı/reddi alırsın.

`Subly/Resources/PrivacyInfo.xcprivacy` oluşturulmalı — içeriği bölüm 2.7'de.

### 0.3 🟠 Kayıt ekranı zorunlu geçit — çevrimdışı çıkış yolu yok
`AppCoordinator.swift:51` → `isRegistered` false ise kullanıcı kayıt ekranında
kilitleniyor. `RegisteringViewModel` sadece **retry** sunuyor, "atla/çevrimdışı
devam et" yok.

Şu an backend sahte (`MockRegistrationService`) olduğu için hep başarılı oluyor.
**Supabase'i bağladığın anda bu gerçek bir ağ çağrısı olur.** App Review'daki
inceleyicinin ağı sorunluysa ya da Supabase o an yanıt vermezse uygulama hiç
açılmaz → Guideline 2.1 (Performance) reddi.

Çözüm: `register()` ağ hatası aldığında lokal olarak başarılı say (cihaz ID'si
zaten Keychain'de), arka planda sonra tekrar dene. Uygulama internetsiz de çalışmalı.

### 0.4 🟠 Sürüm numarası 0.1.0
`project.yml` içinde `MARKETING_VERSION: "0.1.0"`. İlk yayın için **1.0.0**
olmalı. `CURRENT_PROJECT_VERSION` (build) her yüklemede artmalı.

### 0.5 ✅ v1 kapsam temizliği — paywall + Apple ile Giriş kapatıldı
Ayarlar'daki **PLAN** bölümü iki satır içeriyordu: "Subly Plus" (paywall) ve
"Hesap" (Apple ile Giriş). İkisi de v1'de kapalı:

- `FeatureFlag.paywall` **hiçbir yerde kontrol edilmiyordu** — ölü bir bayraktı.
  Artık `SettingsViewModel` PLAN bölümünü bu bayrağın arkasına alıyor ve
  `AppContainer`'da `DefaultFeatureFlagService(enabledFlags: [.insights])` ile
  kapalı. Bölüm hiç oluşturulmuyor, boş başlık kalmıyor.
- `AppleAuthService` → `NoOpAuthService`, `com.apple.developer.applesignin`
  entitlement'ı kaldırıldı.
- QA kısayolları (`-previewPaywall`) duruyor; kullanıcıya ulaşan yol yok.

**v2'de geri açmak için:** `AppContainer`'da `enabledFlags`'e `.paywall` ekle,
`NoOpAuthService()` → `AppleAuthService()` yap, entitlement'ı geri koy, App ID'de
capability'yi aç ve hesap silme akışını yaz.

---

## 1. Apple Developer hesabı (Bireysel) — 1-2 gün

Bu adımlar **herhangi bir bilgisayardan** yapılabilir, projeyle ilgisi yok.
Onay beklerken Supabase işine paralel devam edebilirsin.

1. **Apple ID hazırla.** Kendi Apple ID'nde **iki faktörlü doğrulama (2FA) açık
   olmalı** — zorunlu. Uygulamayı yıllarca yöneteceğin hesap bu; şirket/okul
   hesabı değil, kalıcı erişimin olan kişisel bir Apple ID kullan.

2. **Kaydol:** [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/)
   → "Start your enrollment". iPhone'daki **Apple Developer** uygulamasından
   yapmak genelde daha hızlı (kimlik doğrulaması yerleşik).

3. **Individual / Sole Proprietor** seç.
   - İstenenler: yasal ad-soyad, adres, telefon, resmî kimlik (ehliyet/pasaport).
   - Apple kimliğini fotoğrafla doğrulatabilir.
   - ⚠️ App Store'da **satıcı adı olarak kendi ad-soyadın** görünür. Şirket adı
     görünmesini istiyorsan Organization'a geçmen gerekir (D-U-N-S numarası şart).

4. **Öde:** 99 USD / yıl. Kredi kartı Apple ID'deki isimle uyumlu olmalı.

5. **Onayı bekle.** Bireysel başvurular genelde birkaç saat–2 gün. Onay maili
   gelince [App Store Connect](https://appstoreconnect.apple.com) erişimin açılır.

6. **Sözleşmeleri kabul et:** App Store Connect → **Business** → Apple Developer
   Program License Agreement'ı onayla. (Ücretsiz uygulama için Paid Apps
   sözleşmesine gerek yok — IAP'yi v1'de kapattığımız için banka/vergi bilgisi de
   istenmiyor. Bu, süreci ciddi şekilde kısaltıyor.)

7. **🇪🇺 Trader Status (DSA):** AB ülkelerinde yayınlamak istiyorsan App Store
   Connect → Business → Trader Status kısmında ad, adres, telefon, e-posta
   girmen gerekiyor **ve bunlar App Store'da herkese açık gösterilir.**
   Vermezsen uygulaman AB mağazalarında yayınlanmaz. Bireysel geliştiriciler için
   ev adresinin görünmesi anlamına gelebilir — istemiyorsan AB ülkelerini
   yayın bölgelerinden çıkarabilirsin.

---

## 2. Supabase'i cihaz kaydına bağlama

### Nasıl çalışacak (mimari)

```
Uygulama ilk açılış
   │
   ├─ KeychainDeviceIdentity → cihaz UUID'si (zaten var, değişmiyor)
   │
   ├─ supabase.auth.signInAnonymously()   ←— cihaz için anonim Supabase kullanıcısı
   │      └─ session Keychain'de saklanır, sonraki açılışlarda tekrar kullanılır
   │
   └─ devices tablosuna upsert (user_id = anonim kullanıcı)
          └─ RLS: auth.uid() = user_id → kimse başkasının satırını göremez
```

**Neden anonim giriş?** Cihaz kaydında kullanıcı hesabı yok, dolayısıyla
`auth.uid()` de yok. `auth.uid()` olmadan RLS yazamazsın; `anon key` uygulamaya
gömülü olduğu için tablo herkese açık kalır ve **isteyen tüm cihaz kayıtlarını
okuyup silebilir.** Anonim giriş, hiçbir kullanıcı bilgisi istemeden her cihaza
gerçek bir `auth.users` kimliği verir; RLS böylece normal şekilde çalışır.

**anon key gizli değildir**, uygulamaya gömülebilir — güvenlik RLS'ten gelir.
`service_role` key **asla** uygulamaya veya repoya girmez.

### 2.1 Supabase projesi oluştur
1. [supabase.com](https://supabase.com) → ücretsiz hesap.
2. New project → Region: **eu-central-1 (Frankfurt)** (Türkiye'ye en yakın).
3. Veritabanı şifresini bir parola yöneticisine kaydet.
4. Project Settings → API → **Project URL** ve **anon public key**'i not al.

### 2.2 Anonim girişi aç
Dashboard → **Authentication → Sign In / Providers → Anonymous sign-ins → Enable**.

Aynı sayfada **Rate limits** bölümünden anonim giriş limitini makul bir değerde
tut (kötüye kullanıma karşı). Ayrıca Auth → Settings'te CAPTCHA'yı v1'de kapalı
bırakabilirsin.

### 2.3 Tabloyu ve RLS'i kur
SQL Editor'de çalıştır:

```sql
create table public.devices (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  device_id    text not null,
  platform     text not null default 'ios',
  app_version  text,
  os_version   text,
  locale       text,
  registered_at timestamptz not null default now(),
  last_seen_at  timestamptz not null default now()
);

create index devices_device_id_idx on public.devices (device_id);

alter table public.devices enable row level security;

create policy "own device row: select"
  on public.devices for select
  using (auth.uid() = user_id);

create policy "own device row: insert"
  on public.devices for insert
  with check (auth.uid() = user_id);

create policy "own device row: update"
  on public.devices for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

**Tasarım notları:**
- Birincil anahtar `user_id` (device_id değil). Böylece `upsert` her zaman
  idempotent olur. Uygulama silinip yeniden kurulur ve Keychain oturumu kaybolursa
  yeni bir anonim kullanıcı doğar; `device_id` üzerinde unique kısıtı olsaydı
  insert RLS'e takılıp kalıcı olarak patlardı. Bu yüzden `device_id` unique DEĞİL,
  sadece indeksli.
- `delete` policy'si bilerek yok — cihaz kendi kaydını silemesin.
- Tabloya **kişisel veri koyma.** device_id rastgele bir UUID (IDFA/IDFV değil),
  bu haliyle kimliğe bağlanamaz. Böyle kalmalı.

### 2.4 SDK'yı ekle (XcodeGen ile)
⚠️ Xcode'dan elle SPM eklersen `xcodegen generate` sonrası silinir. `project.yml`'e yaz:

```yaml
packages:
  Supabase:
    url: https://github.com/supabase/supabase-swift
    from: 2.0.0

targets:
  Subly:
    dependencies:
      - target: SublyWidgets
      - package: Supabase
        products:
          - Supabase
```

Sonra: `xcodegen generate`

> Widget target'ına Supabase EKLEME — widget'lar lokal SwiftData'dan okuyor,
> ağa çıkmaları gerekmiyor.

### 2.5 Konfigürasyon
```swift
// Subly/Core/Config/SupabaseConfig.swift
enum SupabaseConfig {
    static let url = URL(string: "https://XXXX.supabase.co")!
    static let anonKey = "eyJ..."   // anon public key — gizli değil
}
```
Client'ı `AppContainer` içinde tek instance olarak üret.

### 2.6 `SupabaseRegistrationService`
Mevcut `RegistrationService` protokolü **değişmiyor**; sadece yeni bir
implementasyon yazılıp `AppContainer`'da `MockRegistrationService` yerine bağlanıyor.
ViewModel'lere dokunulmaz.

```swift
import Foundation
import Supabase

private struct DeviceRow: Encodable {
    let userId: UUID
    let deviceId: String
    let platform: String
    let appVersion: String?
    let osVersion: String
    let locale: String
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceId = "device_id"
        case platform
        case appVersion = "app_version"
        case osVersion = "os_version"
        case locale
        case lastSeenAt = "last_seen_at"
    }
}

final class SupabaseRegistrationService: RegistrationService {

    private let client: SupabaseClient
    private let deviceIdentity: DeviceIdentityProviding

    init(client: SupabaseClient, deviceIdentity: DeviceIdentityProviding) {
        self.client = client
        self.deviceIdentity = deviceIdentity
    }

    var isRegistered: Bool { deviceIdentity.isRegistered() }

    func register(deviceId: String) async throws -> RegistrationResult {
        // 1. Var olan oturumu kullan, yoksa cihaz için anonim kullanıcı aç.
        let session: Session
        if let existing = try? await client.auth.session {
            session = existing
        } else {
            session = try await client.auth.signInAnonymously()
        }

        // 2. Cihaz satırını upsert et (user_id birincil anahtar → idempotent).
        let row = DeviceRow(
            userId: session.user.id,
            deviceId: deviceId,
            platform: "ios",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            osVersion: UIDevice.current.systemVersion,
            locale: Locale.current.identifier,
            lastSeenAt: Date()
        )
        try await client.from("devices").upsert(row).execute()

        deviceIdentity.setRegistered(true)
        return RegistrationResult(deviceID: deviceId, registeredAt: Date())
    }
}
```

### 2.7 Çevrimdışı dayanıklılık — altyapı hazır
`OfflineTolerantRegistrationService` zaten devrede (bölüm 0.3). Supabase'e
geçerken yapman gereken tek şey `AppContainer`'da sarmalanan servisi
değiştirmek:

```swift
self.registrationService = OfflineTolerantRegistrationService(
    wrapping: SupabaseRegistrationService(client: supabase, deviceIdentity: deviceIdentity),
    deviceIdentity: deviceIdentity,
    logger: logger
)
```

✅ **Test edildi.** Supabase SDK ağ hatalarını `URLError` olarak fırlatıyor, yani
dekoratör bunları doğru yakalıyor. Ulaşılamaz bir adrese yönlendirilip temiz
kurulumla denendi: kullanıcı kilitlenmedi, uygulamaya girdi.

⚠️ **Timeout kritik çıktı.** `URLSession.shared` varsayılan 60 saniye bekliyor;
ölçüldü, kullanıcı kayıt ekranında tam bir dakika kilitli kaldı. Bu yüzden
`SupabaseConfig.makeClient()` 8 saniyelik istek timeout'u olan özel bir
`URLSession` enjekte ediyor ve `waitsForConnectivity = false` yapıyor. Ayrıca
`SupabaseRegistrationService` önce ağa çıkmayan `currentSession`'a bakıyor —
doğrudan `session` çağırmak ilk açılışta boşuna bir timeout daha harcıyordu.
Sonuç: 60+ saniye → ~12-15 saniye.

Bu ayarları gevşetirsen (timeout'u büyütmek, `waitsForConnectivity = true`)
kilitlenme geri gelir.

### 2.8 Gizlilik manifestosu — hazır
`Subly/Resources/PrivacyInfo.xcprivacy` ve `SublyWidgets/PrivacyInfo.xcprivacy`
mevcut. Ana manifest `DeviceID` toplandığını (kimliğe bağlı değil, takip yok,
amaç: App Functionality) beyan ediyor — bu, cihaz kaydı için doğru beyandır ve
App Store Connect'teki App Privacy anketiyle **birebir aynı** olmalı.

### 2.9 Durum: entegrasyon bağlandı
`SupabaseConfig.swift` + `SupabaseRegistrationService.swift` yazıldı,
`AppContainer`'da `OfflineTolerantRegistrationService` ile sarmalanıp bağlandı,
SPM paketi `project.yml`'e eklendi (supabase-swift 2.55.1). Derlendi ve
simülatörde kayıt akışı iki kez başarıyla çalıştı.

⚠️ **Xcode 16 Debug build'lerinde uygulama kodu ana binary'de değil,
`Subly.debug.dylib` içindedir.** `strings Subly.app/Subly` boş döner ve
"kod eklenmemiş" yanılgısına yol açar — doğrulama yaparken `Subly.debug.dylib`
dosyasına bak.

### 2.10 Test
- Yeni cihaz/simülatör → uygulamayı aç → Supabase Table Editor'de `devices`
  tablosunda 1 satır belirmeli.
- Aynı cihazda tekrar aç → **yeni satır oluşmamalı** (upsert idempotent).
- Uçak modunda temiz kurulum → uygulama yine de açılmalı, kayıt ekranında takılmamalı.
- RLS testi: ikinci bir cihazdan kayıt yap, ilk cihazın satırını `select` etmeyi
  dene → boş dönmeli.

---

## 3. App Store'a gönderme

### 3.1 Projeyi yeni bilgisayara taşı
⚠️ **Bu klasör şu an bir git deposu değil.** Yeni bilgisayara taşımadan önce
sürüm kontrolü altına al (yoksa tek bir yanlış kopyalamada her şey gider):

```bash
cd /Users/user/Desktop/Subly
git init && git add -A && git commit -m "Initial commit"
# sonra private bir GitHub reposuna push et
```
`.gitignore` ekle: `.DS_Store`, `xcuserdata/`, `build/`, `DerivedData/`.

Yeni bilgisayarda gerekenler: **Xcode 16+**, **XcodeGen** (`brew install xcodegen`),
Apple ID'nin Xcode → Settings → Accounts'a eklenmesi.

### 3.2 Bundle ID ve yeteneklerin kaydı
[developer.apple.com](https://developer.apple.com/account) → Certificates,
Identifiers & Profiles:

| Ne | Değer |
|---|---|
| App ID | `com.subly.app` |
| Widget App ID | `com.subly.app.widgets` |
| App Group | `group.com.subly.app` |

- App Group **her iki** App ID'de de etkin olmalı — widget'lar veriyi bu grup
  üzerinden okuyor (`PersistenceStack.swift:5`).
- ⚠️ Bundle ID ve App Group **global olarak benzersizdir.** `com.subly.app`
  başkası tarafından alınmışsa değiştirmen gerekir — o zaman `project.yml`,
  entitlements ve `PersistenceStack.swift` birlikte güncellenmeli.
- İmzalama `Automatic` ayarlı, Xcode sertifika/profilleri kendisi üretir.

### 3.3 App Store Connect'te uygulamayı oluştur
[App Store Connect](https://appstoreconnect.apple.com) → Apps → **+** → New App:
- Platform: iOS
- **Name:** App Store genelinde benzersiz olmalı. "Subly" alınmış olabilir —
  yedek isim düşün (ör. "Subly — Abonelik Takibi"). Ad 30 karakterle sınırlı.
- **Primary Language:** Elindeki ekran görüntüleri Türkçe (`AppStore/tr/`), o yüzden
  **Türkçe** seçmek en hızlısı. (Uygulama `en` + `tr` destekliyor; İngilizce'yi
  sonradan lokalizasyon olarak ekleyip İngilizce ekran görüntüsü yükleyebilirsin.)
- Bundle ID: `com.subly.app`
- SKU: serbest, ör. `subly-ios-001`

### 3.4 Mağaza sayfası içeriği
- **Ekran görüntüleri:** `AppStore/tr/` altındakiler **1320×2868** — bu 6.9"
  (iPhone 16 Pro Max) boyutu, güncel zorunlu boyut. ✅ Hazır. En fazla 10 adet.
- **Uygulama ikonu:** `subly-icon-rounded-1024.png` mevcut ✅ — ama **1024×1024,
  alfa kanalı YOK, saydamlık YOK, köşeleri kendin yuvarlama** kurallarına
  uyduğunu doğrula. Dosya adında "rounded" geçiyor; Apple köşeleri kendi
  yuvarlar, önceden yuvarlatılmış ikon reddedilebilir.
- **Açıklama, anahtar kelimeler (100 karakter), tanıtım metni**
- **Kategori:** Finance (ikincil: Productivity)
- **Support URL:** zorunlu, çalışan bir sayfa olmalı
- **Privacy Policy URL:** **zorunlu** — cihaz kimliği topluyorsun. Ücretsiz
  çözüm: GitHub Pages'te basit bir sayfa.
- **Yaş sınırı (Age Rating)** anketini doldur → muhtemelen 4+

### 3.5 App Privacy anketi
Cihaz kaydı sebebiyle şunu beyan et:
- **Identifiers → Device ID**: Toplanıyor ✅
- Purpose: **App Functionality**
- Linked to user: **Hayır** (kimliğe bağlı değil)
- Used for tracking: **Hayır**

Bu, bölüm 2.8'deki `PrivacyInfo.xcprivacy` ile **tutarlı olmalı** — çelişki reddedilme sebebidir.

### 3.6 Sürüm ayarları ve arşivleme
1. `project.yml`: `MARKETING_VERSION` → `1.0.0`, `CURRENT_PROJECT_VERSION` → `1`
   (hem Subly hem SublyWidgets target'ında; ikisi de Info.plist'e yazılıyor).
2. İhracat uyumluluğu sorusunu her yüklemede sormasın diye Info.plist'e ekle:
   ```yaml
   ITSAppUsesNonExemptEncryption: false
   ```
   (Sadece standart HTTPS kullanıyorsun, muafiyet kapsamında.)
3. `xcodegen generate`
4. Xcode → hedef cihaz **Any iOS Device (arm64)** → **Product → Archive**
   (Release konfigürasyonu, scheme'de zaten ayarlı ✅)
5. Organizer → **Distribute App → App Store Connect → Upload**

### 3.7 TestFlight'ta gerçek cihazda dene
Yükleme sonrası işlenmesi 15–60 dk sürer. **Kesinlikle App Store'a doğrudan
göndermeden önce TestFlight'tan kendi telefonuna kur ve dene** — özellikle:
- Temiz kurulumda kayıt akışı (Supabase'e gerçekten satır düşüyor mu)
- Uçak modunda açılış
- Widget'ların çalışması
- Takvime aktarma (izin diyaloğu artık çıkmalı, çökmemeli)

### 3.8 İncelemeye gönder
App Store Connect → sürüm sayfası → build seç → **Add for Review** → Submit.

**App Review Notes'a şunu yaz** (inceleyicinin kafası karışmasın):
> Subly, aboneliklerinizi takip eden yerel bir uygulamadır. Açılışta anonim bir
> cihaz kaydı yapılır; kullanıcı hesabı, giriş ekranı veya kişisel veri talebi
> yoktur. Toplanan tek veri, cihazda üretilen rastgele bir tanımlayıcıdır.
> Uygulamanın tüm özellikleri giriş yapmadan kullanılabilir.

- Release seçeneği: "Manually release this version" (onay gelince yayın anını sen seçersin).
- İnceleme süresi genelde 24–48 saat.

---

## 4. Sıralama (paralel yürüyecek işler)

| # | İş | Nerede | Bekletiyor mu? |
|---|---|---|---|
| 1 | Developer hesabı başvurusu | Web | Hayır — hemen başlat, onay beklerken diğerleri sürsün |
| 2 | ~~Bölüm 0'daki 4 düzeltme~~ | Kod | ✅ Tamamlandı |
| 3 | Supabase projesi + tablo + RLS | Web | Hayır |
| 4 | Supabase SDK + servis kodu | Kod | 3'ü bekler |
| 5 | Gizlilik politikası sayfası | Web | Hayır |
| 6 | Bundle ID / App Group kaydı | Web | 1'i bekler |
| 7 | Arşiv + yükleme | Xcode | 1, 2, 4, 6'yı bekler |
| 8 | Mağaza sayfası + privacy anketi | Web | 1'i bekler |
| 9 | TestFlight testi | Cihaz | 7'yi bekler |
| 10 | İncelemeye gönder | Web | Hepsini bekler |

---

## 5. Güvenlik kontrol listesi
- [ ] `service_role` key ASLA uygulamada/repoda yer almıyor
- [ ] `devices` tablosunda RLS **açık** ve üç policy de `auth.uid() = user_id` temelli
- [ ] Anonim giriş için rate limit ayarlandı
- [ ] Tabloda kişisel veri yok (device_id rastgele UUID, IDFA/IDFV değil)
- [ ] `PrivacyInfo.xcprivacy` ile App Privacy anketi birbiriyle tutarlı
- [ ] Gizlilik politikası, toplanan cihaz kimliğinden açıkça bahsediyor
