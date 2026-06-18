# Comptario Local — Günlük Kullanım Kılavuzu

Bu kılavuz teknik bilgi gerektirmez. Tek yapmanız gereken masaüstündeki
**tek bir simgeye** tıklamaktır. PowerShell, komut yazma veya Docker komutları
**gerekmez.**

> İlk kez mi kuruyorsunuz? Önce [CUSTOMER_INSTALL_GUIDE.md](./CUSTOMER_INSTALL_GUIDE.md)
> kılavuzunu izleyin (Docker Desktop + `ComptarioLocalSetup.exe`). Kurulum
> bitince bu kılavuza dönün.

---

## 🟢 Uygulamayı Kullanma (Günlük)

Masaüstünüzde tek bir simge vardır: **“Comptario Local”**.

1. Masaüstündeki **“Comptario Local”** simgesine çift tıklayın.
2. Küçük bir siyah/mavi pencere açılır ve kısa bir süre çalışır.
   - İlk açılışta birkaç dakika sürebilir. Lütfen bekleyin.
3. Tarayıcınız otomatik olarak **Comptario** ile açılır.
4. Artık uygulamayı kullanabilirsiniz.

> Pencere kendiliğinden kapanırsa sorun yoktur — uygulama arka planda çalışmaya
> devam eder.

Bu tek simge her şeyi sizin için yapar:

- Gerekirse **Docker Desktop’ı** otomatik başlatır.
- Uygulamayı başlatır.
- Hazır olunca tarayıcıyı açar.

Uygulama zaten çalışıyorsa aynı simgeye tekrar tıklamak yalnızca tarayıcıyı açar.
Simgeye birden çok kez tıklamak güvenlidir; **verilerinizi silmez** veya
ayarlarınızı bozmaz.

> Genellikle uygulamayı durdurmanız gerekmez; bilgisayarınızı normal şekilde
> kapatabilirsiniz. Verileriniz güvende kalır.

---

## 🛠️ Destek Araçları (Başlat Menüsü)

Yedekleme, geri yükleme, güncelleme ve durdurma işlemleri **destek/ileri düzey**
araçlardır. Bunlar masaüstünü kalabalıklaştırmamak için **Başlat menüsünde**
toplanmıştır:

**Başlat → Comptario Local → Support Tools**

Bu klasörde şunlar bulunur:

| Araç | Ne işe yarar |
| --- | --- |
| **Uygulamayı Aç** | Çalışan uygulamayı tarayıcıda açar. |
| **Yedek Al** | Veritabanının yedeğini `local-backups` klasörüne alır. |
| **Geri Yükle** | Bir yedekten veritabanını geri yükler. |
| **Güncelle** | Yeni bir sürüm geldiğinde uygulamayı güvenle günceller. |
| **Durdur** | Uygulamayı durdurur (veriler korunur). |
| **Destek Menüsü** | Yukarıdaki işlemlerin hepsini tek pencerede sunan menü. |

> Bu araçlar normal günlük kullanım için **gerekli değildir.** Genellikle
> bunları yalnızca **destek ekibi** kullanır.

---

## 💾 Yedek Alma

Verilerinizin bir kopyasını almak için:

1. **Başlat → Comptario Local → Support Tools → “Yedek Al”** öğesine tıklayın.
2. İşlem bitince pencerede yedeğin oluşturulduğu mesajını görürsünüz.

Yedek dosyaları, uygulama klasörünün içindeki **`local-backups`** klasörüne
kaydedilir. Bu klasörü zaman zaman bir USB belleğe veya başka bir bilgisayara
kopyalamanız önerilir.

---

## ♻️ Yedekten Geri Yükleme

Bir sorun yaşadıysanız ve son yedeğe dönmek istiyorsanız:

1. **Başlat → Comptario Local → Support Tools → “Geri Yükle”** öğesine tıklayın.
2. Pencere sizi uyarır:
   **“Bu işlem mevcut veritabanını yedekten geri yükleyecek. Devam etmek için
   GERIYUKLE yazıp Enter'a basın.”**
3. Devam etmek için **`GERIYUKLE`** yazıp Enter’a basın.
4. İşlem bitince uygulama otomatik olarak yeniden başlar.

> ⚠️ Geri yükleme, mevcut verilerin yerine yedekteki verileri koyar. Yalnızca
> gerçekten geri dönmek istediğinizde kullanın.

---

## ⬆️ Yeni Sürüm Geldiğinde (Güncelleme)

Günlük kullanımda her zaman **“Comptario Local”** simgesini kullanırsınız.
Yalnızca size **yeni bir sürüm** gönderildiğinde (dosyalar güncellendiğinde)
güncelleme yapılması gerekir.

Bu adımı genellikle **destek ekibi** yapar:

1. **Başlat → Comptario Local → Support Tools → “Güncelle”** öğesine tıklayın.
2. Pencere yeni sürümü hazırlar ve uygulamayı yeniden başlatır
   (birkaç dakika sürebilir).
3. İşlem bitince tarayıcı otomatik olarak açılır.

> Güncelleme **verilerinizi silmez.** Veritabanı, yedekler ve ayarlarınız olduğu
> gibi korunur. Emin değilseniz önce **“Yedek Al”** ile yedek alabilirsiniz.

---

## ❓ Uygulama Açılmazsa Ne Yapmalı?

Sırayla deneyin:

1. **Birkaç dakika bekleyin**, sonra tekrar **“Comptario Local”** simgesine
   tıklayın. İlk başlatma yavaş olabilir.
2. Ekranın sağ alt köşesinde **Docker (balina 🐳) simgesini** kontrol edin.
   Üzerine gelince **“Docker Desktop is running”** yazmalıdır. Çalışmıyorsa
   Docker Desktop’ın açılmasını bekleyin.
3. Bilgisayarı **yeniden başlatın** ve tekrar **“Comptario Local”** simgesine
   tıklayın.
4. Hâlâ açılmıyorsa **destek ekibiyle** iletişime geçin.

> Sorun yaşasanız bile verileriniz silinmez. Simgelere tıklamak verilerinizi
> tehlikeye atmaz.
