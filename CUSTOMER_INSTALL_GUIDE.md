# Comptario Local — Kurulum Kılavuzu

Bu kılavuz, Comptario Local'i bilgisayarınıza ilk kez kurmak içindir.
Teknik bilgi gerektirmez. Toplam birkaç adımdır.

> Günlük kullanım için ayrı bir kılavuz vardır:
> [CUSTOMER_DAILY_USAGE.md](./CUSTOMER_DAILY_USAGE.md)

---

## Adım 1 — Docker Desktop kurun (yalnızca bir kez)

Comptario Local'in çalışması için **Docker Desktop** gereklidir.

1. <https://www.docker.com/products/docker-desktop> adresine gidin.
2. **Docker Desktop for Windows**'u indirin ve kurun.
3. Bilgisayarı yeniden başlatın (istenirse).
4. Docker Desktop'ı bir kez açın ve sağ alt köşedeki **balina 🐳** simgesinin
   **"Docker Desktop is running"** durumuna gelmesini bekleyin.

> İpucu: Docker Desktop **Settings → General → "Start Docker Desktop when you
> sign in"** seçeneğini işaretlerseniz, bilgisayar her açıldığında Docker
> kendiliğinden başlar. (Kurulum sırasında bu seçeneği sizin için ayarlayan bir
> kutucuk da vardır.)

---

## Adım 2 — `ComptarioLocalSetup.exe` dosyasını çalıştırın

1. Size verilen **`ComptarioLocalSetup.exe`** dosyasına çift tıklayın.
2. Windows yönetici izni isterse **Evet**'e tıklayın.
3. Kurulum sihirbazında **İleri / Kur** diyerek devam edin.
   - Uygulama `C:\ComptarioLocal` klasörüne kurulur.
   - Masaüstüne **tek bir** kısayol eklenir: **Comptario Local**.
4. Son ekranda **"Comptario Local'i şimdi başlat"** seçili kalsın ve
   **Bitir**'e tıklayın.

> Docker Desktop kurulu değilse kurulum sizi uyarır ama yine de devam etmenize
> izin verir. Uygulamayı çalıştırmadan önce Adım 1'i tamamladığınızdan emin olun.

İlk başlatma birkaç dakika sürebilir (uygulama bilgisayarınızda hazırlanır).
Hazır olunca tarayıcınız otomatik olarak açılır.

---

## Adım 3 — Masaüstündeki "Comptario Local" simgesine çift tıklayın

Bundan sonra uygulamayı her açmak istediğinizde tek yapmanız gereken budur:

1. Masaüstündeki **Comptario Local** simgesine çift tıklayın.
2. Küçük bir pencere açılır, gerekirse Docker'ı başlatır ve uygulamayı hazırlar.
3. Tarayıcınız **Comptario** ile açılır.

---

## Adım 4 — İlk kullanıcıyı oluşturun

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
- Aynı simgeye birden çok kez tıklamak güvenlidir; verilerinizi silmez.

Ayrıntılar: [CUSTOMER_DAILY_USAGE.md](./CUSTOMER_DAILY_USAGE.md)

---

## Yedek alma

1. **Başlat → Comptario Local → Support Tools → "Yedek Al"** öğesine tıklayın.
2. Yedek, `C:\ComptarioLocal\local-backups` klasörüne kaydedilir.
3. Bu klasörü zaman zaman bir USB belleğe veya başka bir bilgisayara kopyalayın.

---

## Geri yükleme

1. **Başlat → Comptario Local → Support Tools → "Geri Yükle"** öğesine tıklayın.
2. Pencere sizi uyarır. Devam etmek için **`GERIYUKLE`** yazıp Enter'a basın.
3. İşlem bitince uygulama otomatik olarak yeniden başlar.

> ⚠️ Geri yükleme, mevcut verilerin yerine yedekteki verileri koyar. Yalnızca
> gerçekten geri dönmek istediğinizde kullanın.

---

## Uygulama açılmazsa ne yapmalı?

Sırayla deneyin:

1. **Birkaç dakika bekleyin**, sonra **Comptario Local** simgesine tekrar
   tıklayın. İlk başlatma yavaş olabilir.
2. Sağ alt köşedeki **Docker (balina 🐳)** simgesinin
   **"Docker Desktop is running"** dediğinden emin olun.
3. Bilgisayarı **yeniden başlatın** ve tekrar deneyin.
4. Hâlâ açılmıyorsa **destek ekibiyle** iletişime geçin.

> Sorun yaşasanız bile verileriniz silinmez. Simgelere tıklamak verilerinizi
> tehlikeye atmaz.
