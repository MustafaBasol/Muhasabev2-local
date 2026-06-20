# Comptario Local (Native) — Kurulum Kılavuzu

Bu kılavuz, Comptario Local'in **Docker gerektirmeyen** sürümünü bilgisayarınıza
ilk kez kurmak içindir. Teknik bilgi gerektirmez.

> Bu sürüm için Docker Desktop, WSL, PostgreSQL, Redis, internet üzerinden
> Node.js/npm kurulumu veya Git **gerekmez**. Kurulum dosyası, uygulamanın
> çalışması için gereken her şeyi kendi içinde getirir.

---

## Adım 1 — `ComptarioLocalNativeSetup.exe` dosyasını çalıştırın

1. Size verilen **`ComptarioLocalNativeSetup.exe`** dosyasına çift tıklayın.
2. Windows yönetici izni isterse **Evet**'e tıklayın.
3. Kurulum sihirbazında **İleri / Kur** diyerek devam edin.
   - Uygulama `C:\ComptarioLocal` klasörüne kurulur.
   - Masaüstüne **tek bir** kısayol eklenir: **Comptario Local**.
4. Son ekranda **"Comptario Local'i şimdi başlat"** seçili kalsın ve
   **Bitir**'e tıklayın.

İlk başlatma birkaç saniye sürebilir. Hazır olunca tarayıcınız otomatik
olarak açılır.

---

## Adım 2 — Masaüstündeki "Comptario Local" simgesine çift tıklayın

Bundan sonra uygulamayı her açmak istediğinizde tek yapmanız gereken budur:

1. Masaüstündeki **Comptario Local** simgesine çift tıklayın.
2. Küçük bir pencere açılır ve uygulamanın hazır olmasını bekler.
3. Tarayıcınız `http://127.0.0.1:3000` adresiyle açılır.

> Docker Desktop kurmanıza **gerek yoktur**. Bu sürüm kendi içinde getirdiği
> Node.js ve SQLite veritabanı ile çalışır.

---

## Adım 3 — İlk kullanıcıyı oluşturun

Uygulama tarayıcıda açıldığında:

1. **Kayıt Ol / Register** ekranından ilk kullanıcınızı oluşturun.
2. Bu ilk kullanıcı sizin yönetici hesabınız olur.
3. Giriş yapıp uygulamayı kullanmaya başlayın.

> Hazır bir kullanıcı **yoktur** — ilk hesabı siz oluşturursunuz. E-posta
> doğrulama ve dış e-posta gönderimi yerel kurulumda kapalıdır.

---

## Günlük kullanım

- Uygulamayı açmak için her zaman **yalnızca masaüstündeki "Comptario Local"**
  simgesini kullanın.
- Bilgisayarınızı normal şekilde kapatabilirsiniz; uygulamayı durdurmanız
  gerekmez. **Verileriniz korunur.**
- Aynı simgeye birden çok kez tıklamak güvenlidir; ikinci bir kopya açmaz,
  verilerinizi silmez.

---

## Yedek alma

1. **Başlat → Comptario Local → Support Tools → "Yedek Al"** öğesine tıklayın.
2. Yedek, `C:\ComptarioLocal\backups` klasörüne kaydedilir.
3. Bu klasörü zaman zaman bir USB belleğe veya başka bir bilgisayara kopyalayın.

---

## Geri yükleme

1. **Başlat → Comptario Local → Support Tools → "Geri Yükle"** öğesine tıklayın.
2. Pencere sizi uyarır. Devam etmek için **`RESTORE`** yazıp Enter'a basın.
3. İşlem bitince uygulama otomatik olarak yeniden başlar.

> ⚠️ Geri yükleme, mevcut verilerin yerine yedekteki verileri koyar. Yalnızca
> gerçekten geri dönmek istediğinizde kullanın. İşlem öncesinde mevcut
> verilerinizin otomatik bir güvenlik yedeği alınır.

---

## Uygulamayı durdurma

Genellikle gerekmez (bilgisayarı kapatmak yeterlidir). Gerekirse:

**Başlat → Comptario Local → Support Tools → "Durdur"** öğesine tıklayın.
Verileriniz korunur.

---

## Tüm destek işlemleri tek pencerede

**Başlat → Comptario Local → Support Tools → "Destek Menüsü"** öğesi;
başlatma, yedekleme, geri yükleme ve durdurma işlemlerini tek bir pencereden
sunar.

---

## Verileriniz nerede saklanır?

```text
C:\ComptarioLocal\data           → veritabanı ve yüklenen dosyalar
C:\ComptarioLocal\backups        → yedek arşivleri
C:\ComptarioLocal\logs           → uygulama günlükleri
C:\ComptarioLocal\config         → bu bilgisayara özel ayarlar
```

Bu klasörler; uygulamayı güncellerken veya kaldırırken **otomatik olarak asla
silinmez**.

---

## Uygulama açılmazsa ne yapmalı?

Sırayla deneyin:

1. **Birkaç saniye bekleyin**, sonra **Comptario Local** simgesine tekrar
   tıklayın.
2. `C:\ComptarioLocal\logs\backend-error.log` dosyasını destek ekibinizle
   paylaşın.
3. Hâlâ açılmıyorsa **destek ekibiyle** iletişime geçin.

> Sorun yaşasanız bile verileriniz silinmez. Simgelere tıklamak verilerinizi
> tehlikeye atmaz.
