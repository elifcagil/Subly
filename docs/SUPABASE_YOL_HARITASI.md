# Subly — Supabase Entegrasyon Yol Haritası

Bu doküman, Subly'nin arka ucuna Supabase bağlamak için gereken temel bilgileri ve
adım adım yol haritasını içerir. Mevcut mimariye (SwiftData + protokol tabanlı DI +
XcodeGen) göre hazırlanmıştır.

---

## 1. Supabase nedir, Subly için hangi parçaları kullanacağız?

Supabase; PostgreSQL veritabanı, kimlik doğrulama (Auth), dosya depolama (Storage),
Edge Functions ve Realtime özelliklerini tek pakette sunan bir "Backend as a Service"
platformudur. Subly için ihtiyacımız olanlar:

| Supabase Özelliği | Subly'de karşılığı |
|---|---|
| **Auth** (Apple provider) | Mevcut `AuthService` / Sign in with Apple akışının gerçek backend'e bağlanması |
| **Postgres (Database)** | `Subscription` verilerinin bulutta saklanması, cihazlar arası senkron |
| **Row Level Security (RLS)** | Her kullanıcının yalnızca kendi aboneliklerini görebilmesi |
| **Realtime** (opsiyonel, sonraya) | Başka cihazda yapılan değişikliğin anlık yansıması |
| **Edge Functions** (opsiyonel, sonraya) | Sunucu taraflı işler (ör. push bildirim tetikleme) |

**Önemli kavram — anon key:** Supabase projesinin bir `URL`'i ve bir `anon key`'i
vardır. Anon key uygulamaya gömülür ve gizli DEĞİLDİR; güvenlik RLS politikalarıyla
sağlanır. Asla uygulamaya gömülmemesi gereken anahtar `service_role` key'dir
(sadece sunucu tarafında kullanılır).

---

## 2. Hedef mimari

Mevcut yapı zaten çok uygun: her şey protokol arkasında (`AuthService`,
`SubscriptionRepository`, `RegistrationService`) ve `AppContainer` üzerinden
enjekte ediliyor. Supabase'i **yeni implementasyonlar** olarak ekleyeceğiz,
mevcut kodu bozmadan.

Önerilen strateji: **Offline-first (lokal öncelikli) + senkron**

```
UI / ViewModel
     │
SubscriptionRepository (mevcut protokol — değişmiyor)
     │
SwiftDataSubscriptionRepository  ←— kaynak-of-truth lokal kalır (widget'lar da buradan besleniyor)
     │
SyncService (YENİ)  ←→  Supabase (Postgres)
```

Neden böyle? Widget'lar App Group üzerinden lokal store'u okuyor; uygulama
internetsizken de çalışmalı. Bu yüzden SwiftData kalır, Supabase "senkron hedefi"
olur. En basit ilk sürümde: uygulama açılışta/foreground'da pull + her yazmada push.

---

## 3. Yol haritası (fazlar)

### Faz 0 — Hazırlık (kod yok)
1. [supabase.com](https://supabase.com) üzerinde ücretsiz hesap aç.
2. Yeni proje oluştur (bölge: `eu-central-1` Frankfurt mantıklı — Türkiye'ye yakın).
3. Dashboard'u tanı: **Table Editor**, **SQL Editor**, **Authentication**, **API Settings**.
4. `Project Settings → API`'den `Project URL` ve `anon public` key'i not al.

### Faz 1 — SDK kurulumu
`supabase-swift` resmi SDK'sını SPM ile ekle. Proje XcodeGen kullandığı için
`project.yml`'e eklenir (Xcode'dan elle eklersen `xcodegen generate` sonrası silinir):

```yaml
# project.yml — en üst seviyeye
packages:
  Supabase:
    url: https://github.com/supabase/supabase-swift
    from: 2.0.0

# Subly target'ının altına
targets:
  Subly:
    dependencies:
      - target: SublyWidgets
      - package: Supabase
        products:
          - Supabase   # Auth + PostgREST + Realtime + Storage hepsi içinde
```

Sonra `xcodegen generate` çalıştır.

Konfigürasyon için basit bir dosya (URL ve anon key gizli olmadığı için gömülebilir,
ama düzenli olması adına tek yerde tut):

```swift
// Subly/Core/Config/SupabaseConfig.swift
enum SupabaseConfig {
    static let url = URL(string: "https://XXXX.supabase.co")!
    static let anonKey = "eyJ..."
}
```

Client'ı `AppContainer`'da tek instance olarak oluştur ve servislere enjekte et.

### Faz 2 — Auth (Sign in with Apple → Supabase)
Şu an `AppleAuthService` Apple'dan dönen kimliği yalnızca UserDefaults'a yazıyor.
Supabase'e bağlanınca Apple'dan alınan **identityToken** Supabase'e verilecek ve
Supabase gerçek bir kullanıcı (`auth.users` tablosunda) oluşturacak.

Adımlar:
1. Dashboard → **Authentication → Providers → Apple**'ı aç. Bundle ID olarak
   `com.subly.app` gir (native iOS akışında Service ID/secret gerekmez, bundle ID yeterli).
2. Yeni bir `SupabaseAuthService: AuthService` implementasyonu yaz. Mevcut
   `ASAuthorizationController` akışı korunur; tek fark, token'ın Supabase'e iletilmesi:

```swift
// ASAuthorizationController delegate'inde, credential alındıktan sonra:
let session = try await supabase.auth.signInWithIdToken(
    credentials: .init(
        provider: .apple,
        idToken: identityTokenString   // credential.identityToken'dan
    )
)
// session.user.id → artık gerçek kullanıcı ID'si (UUID)
```

3. Oturum kalıcılığını SDK kendisi yönetir (Keychain). `currentState()` artık
   `supabase.auth.currentSession`'dan okur; UserDefaults anahtarları kalkar.
4. `signOut()` → `try await supabase.auth.signOut()`.
5. `AppContainer`'da `AppleAuthService` yerine `SupabaseAuthService` bağla.
   Protokol aynı kaldığı için ViewModel'lere dokunulmaz.

> Not: Apple, `fullName`/`email`'i yalnızca İLK girişte verir. İlk girişte bunları
> yakalayıp Supabase `user metadata`'ya yazmak iyi pratiktir.

### Faz 3 — Veritabanı şeması + RLS
SQL Editor'de çalıştırılacak başlangıç şeması (`Subscription` modeliyle birebir):

```sql
create table public.subscriptions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  amount numeric(12, 2) not null,
  currency_code text not null,
  billing_cycle text not null,
  start_date timestamptz not null,
  next_renewal_date timestamptz not null,
  category_id text,
  notes text,
  is_archived boolean not null default false,
  reminder_lead_days int[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz          -- soft delete: senkron için silinenler de iz bırakmalı
);

alter table public.subscriptions enable row level security;

create policy "Users manage own subscriptions"
  on public.subscriptions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index subscriptions_user_id_idx on public.subscriptions (user_id);
create index subscriptions_updated_at_idx on public.subscriptions (user_id, updated_at);
```

Kilit noktalar:
- **RLS açık + policy**: anon key uygulamada gömülü olsa bile herkes yalnızca
  kendi satırlarını görür/yazar. Bu satır olmadan tablo herkese kapalıdır
  (RLS açık ama policy yoksa kimse erişemez).
- `amount` için `numeric` — `Decimal` ile birebir uyumlu, float kullanma.
- `deleted_at` (soft delete) — cihazlar arası senkronda "silindi" bilgisini taşımak için.
- `updated_at` — "son değişen kazanır" senkron stratejisinin temeli.

`updated_at`'i otomatik güncelleyen trigger:

```sql
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();
```

### Faz 4 — DTO + Remote data source
Supabase satırlarıyla konuşan bir Codable DTO ve ince bir remote katman:

```swift
struct SubscriptionDTO: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let amount: Decimal
    let currencyCode: String
    let billingCycle: String
    // ... CodingKeys ile snake_case eşlemesi (SDK'nın encoder'ı bunu otomatik de yapabilir)
}

// Örnek çağrılar:
let rows: [SubscriptionDTO] = try await supabase
    .from("subscriptions")
    .select()
    .is("deleted_at", value: nil)
    .execute().value

try await supabase.from("subscriptions").upsert(dto).execute()
```

`user_id`'yi client'ta doldur (`supabase.auth.session.user.id`); RLS zaten yanlış
değeri reddeder.

### Faz 5 — Senkron servisi (ilk sürüm basit)
Yeni bir `SyncService` protokolü + `SupabaseSyncService`:

- **Push:** `SubscriptionRepository.save/archive/delete` sonrası ilgili kaydı upsert et
  (delete → `deleted_at` set et).
- **Pull:** uygulama foreground'a gelince `updated_at > lastSyncedAt` olan satırları çek,
  SwiftData'ya uygula, `lastSyncedAt`'i güncelle.
- **Çakışma:** iki taraf da değiştiyse `updated_at`'i büyük olan kazanır (ilk sürüm için yeterli).
- Kullanıcı giriş yapmamışsa senkron tamamen devre dışı — uygulama bugünkü gibi
  salt lokal çalışmaya devam eder.

Entegrasyon noktası: `AppContainer`'da repository'yi bir "senkron tetikleyen"
dekoratörle sarmak (`SyncedSubscriptionRepository: SubscriptionRepository`),
böylece ViewModel'ler yine hiçbir şey bilmez.

### Faz 6 — RegistrationService'in gerçeklenmesi (opsiyonel)
`MockRegistrationService` anonim cihaz kaydı yapıyor. Supabase Auth gelince iki seçenek:
- **Basit:** Auth zaten kullanıcı kaydı demek; registration akışını Supabase signup'a bağla.
- **Anonim kullanım isteniyorsa:** Supabase'in **Anonymous Sign-in** özelliğini aç;
  cihaz önce anonim kullanıcı olur, Apple ile giriş yapınca hesap yükseltilir
  (`linkIdentity`). Böylece giriş yapmadan da senkron mümkün olur.

### Faz 7 — Test ve sağlamlaştırma
- İki ortam: `Subly-Dev` ve `Subly-Prod` diye iki ayrı Supabase projesi;
  Debug/Release konfigürasyonuna göre URL/key seç.
- RLS testi: SQL Editor'de `select auth.uid()` senaryolarıyla ya da ikinci bir test
  hesabıyla başka kullanıcının verisini görememeyi doğrula.
- Uçtan uca: cihaz A'da abonelik ekle → cihaz B'de (veya silip yeniden kurulan
  uygulamada) görünmesini doğrula.
- Ağ yokken ekleme/silme → sonra bağlanınca push edilmesini doğrula.

### Faz 8 — Sonrası (şimdilik kapsam dışı)
- **Realtime:** başka cihazdaki değişikliğin anlık gelmesi (`supabase.channel(...)`).
- **Edge Functions + push:** sunucudan yenileme hatırlatmaları (şu an lokal bildirim var, gerek olmayabilir).
- **Kategori/katalog tablolarını** sunucuya taşıma.
- Hesap silme (App Store zorunluluğu: Apple girişi varsa hesap silme de sunulmalı —
  `supabase.auth.admin` yerine bir Edge Function ile yapılır).

---

## 4. Güvenlik kontrol listesi
- [ ] `service_role` key ASLA uygulamada/repo'da yer almaz.
- [ ] Tüm tablolarda RLS açık ve policy'ler `auth.uid() = user_id` temelli.
- [ ] Anon key gömülü olabilir; yine de repo public olacaksa xcconfig'e taşınabilir.
- [ ] Apple provider'da bundle ID doğru: `com.subly.app`.
- [ ] Hesap silme akışı (App Store Guideline 5.1.1(v)) plana dahil.

## 5. Faydalı kaynaklar
- Supabase Swift SDK: https://github.com/supabase/supabase-swift
- Swift dokümantasyonu: https://supabase.com/docs/reference/swift
- Apple ile giriş (native): https://supabase.com/docs/guides/auth/social-login/auth-apple
- RLS rehberi: https://supabase.com/docs/guides/database/postgres/row-level-security
