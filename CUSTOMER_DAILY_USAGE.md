# Comptario Local — Günlük Kullanım Kılavuzu

Bu kılavuz teknik bilgi gerektirmez. Tek yapmanız gereken masaüstündeki
simgelere tıklamaktır. PowerShell, komut yazma veya Docker komutları **gerekmez.**

---

## 🟢 Uygulamayı Başlatma

1. Masaüstündeki **“Comptario Local Başlat”** simgesine çift tıklayın.
2. Küçük bir siyah/mavi pencere açılır ve kısa bir süre çalışır.
   - İlk açılışta birkaç dakika sürebilir. Lütfen bekleyin.
3. Tarayıcınız otomatik olarak **Comptario** ile açılır.
4. Artık uygulamayı kullanabilirsiniz.

> Pencere kendiliğinden kapanırsa sorun yoktur — uygulama arka planda çalışmaya
> devam eder.

---

## 🔵 Uygulamayı Açma (zaten çalışıyorsa)

Bilgisayarınızı açık bıraktıysanız ve uygulama zaten çalışıyorsa, baştan
başlatmanıza gerek yoktur:

1. Masaüstündeki **“Comptario Local Aç”** simgesine çift tıklayın.
2. Tarayıcı, Comptario ile açılır.

> Eğer uygulama çalışmıyorsa, bu simge size **“Comptario Local Başlat”**
> simgesine tıklamanızı söyler. Önce onu kullanın.

---

## 🔴 Uygulamayı Durdurma

Genellikle uygulamayı durdurmanız gerekmez; bilgisayarınızı normal şekilde
kapatabilirsiniz. Yine de elle durdurmak isterseniz:

1. Masaüstündeki **“Comptario Local Durdur”** simgesine çift tıklayın.
2. Pencerede “durduruldu” mesajını görünce kapatabilirsiniz.

> Durdurmak **verilerinizi silmez.** Tüm bilgileriniz güvende kalır.

---

## 💾 Yedek Alma

Verilerinizin bir kopyasını almak için:

1. Masaüstündeki **“Comptario Local Yedek Al”** simgesine çift tıklayın.
2. İşlem bitince pencerede yedeğin oluşturulduğu mesajı görünürsünüz.

Yedek dosyaları, uygulama klasörünün içindeki **`local-backups`** klasörüne
kaydedilir. Bu klasörü zaman zaman bir USB belleğe veya başka bir bilgisayara
kopyalamanız önerilir.

---

## ♻️ Yedekten Geri Yükleme

Bir sorun yaşadıysanız ve son yedeğe dönmek istiyorsanız:

1. Masaüstündeki **“Comptario Local Geri Yükle”** simgesine çift tıklayın.
2. Pencere sizi uyarır:
   **“Bu işlem mevcut veritabanını yedekten geri yükleyecek. Devam etmek için
   GERIYUKLE yazıp Enter'a basın.”**
3. Devam etmek için **`GERIYUKLE`** yazıp Enter’a basın.
4. İşlem bitince uygulama otomatik olarak yeniden başlar.

> ⚠️ Geri yükleme, mevcut verilerin yerine yedekteki verileri koyar. Yalnızca
> gerçekten geri dönmek istediğinizde kullanın.

---

## ⬆️ Yeni Sürüm Geldiğinde (Güncelleme)

Günlük kullanımda her zaman **“Comptario Local Başlat”** simgesini kullanırsınız.
Yalnızca size **yeni bir sürüm** gönderildiğinde (dosyalar güncellendiğinde)
güncelleme yapılması gerekir.

Bu adımı genellikle **destek ekibi** yapar:

1. Masaüstündeki **“Comptario Local Güncelle”** simgesine çift tıklayın.
2. Pencere yeni sürümü hazırlar ve uygulamayı yeniden başlatır
   (birkaç dakika sürebilir).
3. İşlem bitince tarayıcı otomatik olarak açılır.

> Güncelleme **verilerinizi silmez.** Veritabanı, yedekler ve ayarlarınız olduğu
> gibi korunur. Emin değilseniz önce **“Comptario Local Yedek Al”** ile yedek
> alabilirsiniz.

---

## ❓ Uygulama Açılmazsa Ne Yapmalı?

Sırayla deneyin:

1. **Birkaç dakika bekleyin**, sonra tekrar **“Comptario Local Başlat”**
   simgesine tıklayın. İlk başlatma yavaş olabilir.
2. Ekranın sağ alt köşesinde **Docker (balina 🐳) simgesini** kontrol edin.
   Üzerine gelince **“Docker Desktop is running”** yazmalıdır. Çalışmıyorsa
   Docker Desktop’ın açılmasını bekleyin.
3. Bilgisayarı **yeniden başlatın** ve tekrar **“Comptario Local Başlat”**
   simgesine tıklayın.
4. Hâlâ açılmıyorsa **destek ekibiyle** iletişime geçin.

> Sorun yaşasanız bile verileriniz silinmez. Simgelere tıklamak verilerinizi
> tehlikeye atmaz.
