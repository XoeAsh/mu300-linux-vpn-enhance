# mu300-linux-vpn-enhance

<img width="607" height="386" alt="LuCI VPN arayüzünün ekran görüntüsü" src="https://github.com/user-attachments/assets/879cf902-01f0-48b1-ba88-15be7fb3b4a5" />

[简体中文](README.md) · [English](README.en.md) · **Türkçe**

> Bu belge ChatGPT tarafından çevrilmiştir. Çeviri gözden geçirilmemiştir.

MU300 / ZTE F50 cihazlarının orijinal LuCI VPN sayfalarına tam yapılandırma abonelikleri ve düğüm seçimi ekler. **0.2.1** sürümü, orijinal `mu300-vpn v2.0.4` sürümünü temel alır. [mu300-linux](https://github.com/dikeckaan/mu300-linux) · [mu300-linux-vpn](https://github.com/dikeckaan/mu300-linux-vpn)

## Özellikler

- **Tam yapılandırma abonelikleri.** sing-box 1.14 JSON, Mihomo YAML ve paylaşım bağlantılarını destekler. Orijinal abonelik yöneticisi, kayıtlı biçimi ve yenileme ayarlarını kullanarak abonelikleri yeniler.
- **Yerel düğüm seçimi.** VPN Genel Bakış sayfasında Mihomo `select` grupları veya sing-box `selector` grupları içinde düğüm değiştirebilirsiniz. Seçimler profil ve proxy grubu bazında kaydedilir. Mihomo bir Unix soketi, sing-box ise belirteçle korunan bir geri döngü arayüzü kullanır.
- **Üç arayüz dili.** Basitleştirilmiş Çince, İngilizce ve Türkçe için LuCI dil ayarını izler. Diğer dil ayarlarında eklenen arayüz öğeleri İngilizce görüntülenir.

## Sürümler ve test ortamı

| Bileşen | Temel alınan veya test edilen sürüm |
| --- | --- |
| Cihaz ve arayüz | MU300 / ZTE F50, orijinal mu300-linux LuCI |
| VPN modülü | mu300-vpn v2.0.4 |
| Mihomo | v1.19.32 |
| sing-box | v1.14.1 |

Tablo, `mu300-vpn v2.0.4` projesinin derlemelerinde kullanılan motor sürümlerini gösterir. Eklenti, cihaz yazılımının yönettiği mevcut motorları kullanır. Cihazda kurulu olanları görmek için SSH üzerinden `mu300-vpn engines --json` komutunu çalıştırın.

sing-box yapılandırmasını içe aktarma, bağlantı kurma ve düğüm seçimi F50 üzerinde test edilmiştir. Mihomo v1.19.32 ile Unix soketi üzerinden düğümleri okuma, düğüm değiştirme ve yeniden başlatma sonrasında kayıtlı seçimi geri yükleme, Linux x86_64 üzerinde test edilmiştir. Mihomo'nun F50 üzerindeki testi henüz yapılmamıştır.

## Kurulum

Bu adımlar Windows PowerShell içindir. Cihaza USB veya yerel ağ üzerinden bağlanın ve root erişiminizi hazır bulundurun. Cihazınızın yönetim adresi farklıysa komutlardaki `192.168.77.1` adresini değiştirin. Yeniden kurulumdan önce mevcut kurulumun kaldırma betiğini çalıştırın.

### 1. Arşivi indirin

`mu300-linux-vpn-enhance-0.2.1.tar.gz` dosyasını Windows'taki **İndirilenler** klasörüne kaydedin. Arşivi cihazda açacağınız için sıkıştırılmış olarak bırakın. [v0.2.1'i indir](https://github.com/xoeash/mu300-linux-vpn-enhance/archive/refs/tags/v0.2.1.tar.gz) · [Sürüm sayfası](https://github.com/xoeash/mu300-linux-vpn-enhance/releases/tag/v0.2.1)

### 2. Windows'tan yükleyin ve oturum açın

**PowerShell**'i açın ve komutları sırayla çalıştırın. `ssh` ile oturum açmadan önce `scp` aktarımının bitmesini bekleyin.

```powershell
Set-Location "$env:USERPROFILE\Downloads"
scp -O ".\mu300-linux-vpn-enhance-0.2.1.tar.gz" root@192.168.77.1:/tmp/
ssh root@192.168.77.1
```

İstenirse cihazın root parolasını girin. Yazdığınız karakterler ekranda görünmez. SSH sunucu anahtarı hakkında bir uyarı gösterirse önce güvenilir bir cihaz konsolundan anahtar parmak izini doğrulayın. Oturum açınca `root@mu300:~#` benzeri bir komut istemi görürsünüz.

### 3. Cihazda arşivi açın ve kurulumu yapın

Aşağıdaki bloğu SSH terminaline yapıştırın. Her komut, bir önceki başarılı olunca çalışır.

```sh
tar -xzf /tmp/mu300-linux-vpn-enhance-0.2.1.tar.gz -C /tmp &&
cd /tmp/mu300-linux-vpn-enhance-0.2.1 &&
sh install.sh &&
sh audit.sh
```

`Installed version: 0.2.1` mesajını görünce tarayıcıda LuCI VPN sayfasını yeniden açın. Düğüm denetleyicisi, VPN bir sonraki kez başladığında devreye girer. Kurulum betiği önce orijinal dosyaları kontrol eder ve uyumsuz bir sürüm bulursa sistem dosyalarını değiştirmeden çıkar.

## Kullanım

### Abonelikler

Abonelik adresinizi **VPN → Abonelikler → Ekle** bölümüne girin. Yeni aboneliklerde **Otomatik algıla (tam yapılandırmaları tercih et)** önce sing-box JSON, ardından Mihomo YAML ve paylaşım bağlantılarını dener. Kullanılan biçim, sağlayıcının döndürdüğü içeriğe bağlıdır. Mevcut abonelikler algılanan biçimleriyle yenilenmeye devam eder. Bir paylaşım bağlantısı aboneliği için tam yapılandırmayı denemek istiyorsanız yeni bir abonelik oluşturun.

Sağlayıcınız belirli bir biçime ait bağlantı sunuyorsa **Tam sing-box JSON** veya **Tam Clash/Mihomo YAML** seçeneğini kullanın. Tam yapılandırma dosyası, düğümleri ve proxy grupları korunarak tek bir VPN profili olarak içe aktarılır.

### Düğüm seçimi

Profilinizi etkinleştirdikten sonra **VPN → Genel Bakış → Proxy düğümü seçimi** bölümünden elle seçim yapılabilen bir grup ve düğüm seçin. Dosyadan içe aktarılan tam yapılandırmalar da kullanılabilir. Panel elle seçim yapılabilen grup olmadığını bildirirse Mihomo yapılandırmasında bir `select` grubu veya sing-box yapılandırmasında bir `selector` grubu olup olmadığını kontrol edin.

Arayüz dilini değiştirmek için LuCI'de **Sistem → Sistem → Dil ve Stil** bölümüne gidin, seçiminizi kaydedin ve VPN Genel Bakış sayfasını yeniden açın. Düğüm ve proxy grubu adları, yapılandırmada tanımlandığı şekilde gösterilir.

## Denetim ve kaldırma

`sh audit.sh` kurulum durumunu, menü yollarını, abonelik sayılarını, yerel denetim durumunu ve dosya bütünlüğü sonuçlarını gösterir. Çıktıyı paylaşmadan önce abonelik belirteçlerini çıkarın.

Eklentinin düğüm denetleyicisi etkinse LuCI'ye erişebileceğiniz yerel bir bağlantı üzerinden VPN'i durdurun. Ardından kaldırma betiğini SSH üzerinden çalıştırın.

```sh
sh /root/.mu300-linux-vpn-enhance/uninstall.sh
```

Kaldırma işlemi kurulumda değiştirilen orijinal dosyaları geri yükler ve eklentinin arayüzünü, çeviri kataloglarını, düğüm tercihlerini, çalışma dosyalarını ve kurulum kayıtlarını siler. VPN yapılandırmaları ve abonelikler korunur. İçe aktarılan sing-box profilleri kullanılmaya devam edilebilir. Betik, kurulumdan sonra bir orijinal dosyada başka değişiklikler yapıldığını saptarsa dosyayı belirtir ve işlemi duraklatır. Kaldırma kesintiye uğrarsa aynı komutu yeniden çalıştırın.

Yüklenen arşiv ve açılan klasör `/tmp` altında bulunur. Cihaz yeniden başlatıldığında bu dizin temizlenir.

## Geliştirme

Geliştirme bilgisayarınızda `sh tests/run.sh` komutunu çalıştırarak abonelik biçimleri arasındaki geçişi, yamaları, çevirileri, kurulumu ve kaldırmayı sınayabilirsiniz. Testler, cihazı taklit etmek için geçici bir dizin kullanır.

LuCI arayüz öğelerinin kaynak dili İngilizcedir. Basitleştirilmiş Çince ve Türkçe çeviri dosyaları `i18n/` dizinindedir. Çalışma zamanı kataloglarını derlemek için LuCI'nin `po2lmo` aracını kullanın.

```sh
po2lmo i18n/zh-cn.po i18n/mu300-vpn-enhance.zh-cn.lmo
po2lmo i18n/tr.po i18n/mu300-vpn-enhance.tr.lmo
```
