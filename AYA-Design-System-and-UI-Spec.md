# AYA — Visual Design System and UI Specification

> Bu belge, AYA iOS uygulamasının 7 Ağustos 2026 tarihindeki çalışan SwiftUI arayüzünü tarif eden görsel kaynak dokümandır. Yeni ekranlar bu sistemi devam ettirmeli; renk, tipografi ve bileşen kararları view dosyalarında tekrar tanımlanmamalıdır.

## 1. Ürün ve platform

- Uygulama: **AYA Meditation**
- Platform: iPhone, SwiftUI
- Minimum sürüm: iOS 17
- Görünüm: yalnızca Light Mode
- Diller: Türkçe ve İngilizce
- Temel ekran genişliği referansı: 393 pt
- Tasarım ölçüleri SwiftUI point cinsindedir; fiziksel piksel değildir.
- Kullanıcıya görünen bütün metinler String Catalog üzerinden gelmelidir.

## 2. Marka hissi

AYA sakin, sıcak, yetişkin ve editorial bir meditasyon uygulamasıdır.

Arayüz şu özellikleri taşımalıdır:

- Premium ancak gösterişli olmayan
- Kadın odaklı fakat aşırı pembe olmayan
- Sıcak, güvenilir ve yumuşak
- Medikal görünmeyen
- Anne-bebek mağazası estetiğine dönüşmeyen
- Bol açık yüzey kullanan
- Koyu mürdüm rengini kontrollü vurgu olarak kullanan
- Ağır gölge, sert siyah ve yüksek doygunluk kullanmayan

Önerilen genel renk dağılımı:

- %65–75 açık background ve beyaz surface
- %15–25 primary marka tonu
- %5–10 secondary ve sıcak accent tonları

## 3. Ana renk sistemi

### 3.1 Marka renkleri

| Token | Hex | Kullanım |
|---|---:|---|
| `primary` | `#99627A` | Aktif durumlar, seçim, yumuşak marka vurgusu |
| `secondary` | `#6C2645` | Ana metin, güçlü vurgu, koyu CTA, profil dairesi |
| `tertiary` | `#FEEBC8` | Sıcak highlight, hamilelik yüzeyi, seçili detay |
| `softPink` | `#ECC0D3` | Pastel dekorasyon ve lohusalık yüzeyi |
| `background` | `#F9F5F6` | Bütün ekranların ana arka planı |
| `surface` | `#FFFFFF` | Kart, input ve açık panel yüzeyi |

### 3.2 Türetilmiş tokenlar

| Token | Değer |
|---|---|
| `primaryText` | `secondary` |
| `secondaryText` | `secondary` %78 opacity |
| `divider` | `secondary` %12 opacity |
| `border` | `secondary` %14 opacity |
| `overlay` | `secondary` %24 opacity |
| `shadow` | `secondary` %7 opacity |
| `strongShadow` | `secondary` %14 opacity |
| `selectionBackground` | `softPink` %42 opacity |
| `pregnancySurface` | `tertiary` %58 opacity |
| `postpartumSurface` | `softPink` %44 opacity |
| `motherhoodSurface` | `primary` %10 opacity |

### 3.3 SwiftUI kaynak tokenları

```swift
enum AYAColors {
    static let primary = Color(hex: 0x99627A)
    static let secondary = Color(hex: 0x6C2645)
    static let tertiary = Color(hex: 0xFEEBC8)
    static let softPink = Color(hex: 0xECC0D3)
    static let background = Color(hex: 0xF9F5F6)
    static let surface = Color(hex: 0xFFFFFF)

    static let primaryText = secondary
    static let secondaryText = secondary.opacity(0.78)
    static let divider = secondary.opacity(0.12)
    static let border = secondary.opacity(0.14)
    static let overlay = secondary.opacity(0.24)
    static let shadow = secondary.opacity(0.07)
    static let strongShadow = secondary.opacity(0.14)
}
```

Renkleri view içinde hex olarak tekrarlama. Yeni renk ihtiyacı varsa önce semantic token üret.

## 4. Tipografi

### 4.1 Amaçlanan font aileleri

- Primary/UI font: **Satoshi**
- Secondary/editorial font: **Nyght Serif**

Kullanım rolleri:

- Nyght Serif: ekran ana başlıkları, hero başlıkları, büyük editorial kart başlıkları ve meditasyon başlıkları
- Satoshi: gövde, açıklama, input, buton, badge, caption, navigation ve form kontrolleri

### 4.2 Mevcut uygulamadaki gerçek durum

Satoshi ve Nyght Serif font dosyaları şu anda uygulama bundle’ında bulunmamaktadır. PostScript isimleri doğrulanamadığı için uygulama isim tahmini yapmaz ve erişilebilir sistem fallback’i kullanır:

```swift
static func editorial(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .serif)
}

static func ui(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .default)
}
```

Font dosyaları daha sonra eklenirse, yalnızca merkezi `AYATypography` API’si gerçek PostScript isimleriyle güncellenmelidir. View dosyaları değiştirilmemelidir.

### 4.3 Aktif tipografi ölçeği

| Rol | Boyut | Weight | Tasarım |
|---|---:|---|---|
| Karşılama “AYA” wordmark | 62 | Semibold | Editorial/serif, tracking 4 |
| Karşılama başlığı | 29 | Semibold | Editorial/serif |
| Yaşam dönemi ekran başlığı | 26 | Semibold | Editorial/serif |
| Kompakt ekran başlığı | 23 | Semibold | Editorial/serif |
| Dönem detay başlığı | 34 | Semibold | Editorial/serif |
| Ayarlar başlığı | 28 | Semibold | Editorial/serif |
| Kart başlığı | 23.25 | Semibold | Editorial/serif |
| Uzun kart başlığı | 21 | Semibold | Editorial/serif |
| Karşılama açıklaması | 15 | Regular | UI/sans |
| Form label | 15 | Medium | UI/sans |
| Ana input | 17 | Regular | UI/sans |
| Ana CTA | 16 | Semibold | UI/sans |
| Kart açıklaması | 12 | Regular | UI/sans |
| Kart badge | 7.7 | Medium | UI/sans |
| Ayarlar satırı | 14–15 | Medium | UI/sans |
| Ayarlar section label | 13 | Medium, uppercase | UI/sans |
| Profil baş harfi | 19 | Bold | UI/sans |

Kartlarda kullanılan küçük ölçüler mevcut sıkı tek-ekran kompozisyonunun bilinçli parçasıdır. Global olarak büyütülmemelidir.

## 5. Genel yüzey, border ve gölge

- Ana ekran arka planı: `AYAColors.background`
- Açık kart/input yüzeyi: `AYAColors.surface`
- Standart ince border: `AYAColors.divider`, 1 pt
- Kart border: `AYAColors.border`, 1 pt
- Kart köşe yarıçapı: 26 pt continuous
- Form/panel satırı köşe yarıçapı: 18 pt continuous
- Ana input/CTA köşe yarıçapı: 16 pt continuous
- Büyük form container köşe yarıçapı: 24 pt continuous
- Kart gölgesi: secondary %7, radius 9, y 5
- Seçili kart glow: kart accent renginin %28’i, radius 9, x/y 0
- Ayarlar panel gölgesi: secondary %14, radius 22, x -8

Gölge hiçbir zaman siyah veya ağır olmamalıdır.

## 6. Uygulama akışı

```text
İlk açılış
  └─ Karşılama: ad + dil seçimi
      └─ AYA yaşam dönemi seçimi
          ├─ Regl Döngüsü → Yakında ekranı
          ├─ Hamilelik → Yakında ekranı
          ├─ Lohusalık → Yakında ekranı
          └─ Annelik → Yakında ekranı
              └─ Sağ üst profil baş harfi → Ayarlar yan paneli
                  └─ AYA Temaları → yaşam dönemi seçimine dönüş
```

- Geri butonu dönem detay ekranlarında gösterilmez.
- Ayarlar yalnızca dönem detay ekranlarının sağ üstündedir.
- Yaşam dönemi seçimine ayarlardaki “AYA Temaları” üzerinden dönülür.
- Varsayılan seçili yaşam dönemi Regl Döngüsü’dür.
- Seçilen kart, kullanıcı seçim ekranına döndüğünde glow ve checkmark ile seçili görünür.

## 7. Karşılama ekranı

### 7.1 Kompozisyon

- ScrollView kullanılır; küçük ekran ve klavye güvenliği korunur.
- İçerik yatay padding: 24 pt
- İçeriğin maksimum genişliği: 560 pt
- Üst minimum boşluk: 54 pt
- Marka grubu ile form arası: 42 pt
- Form ile CTA arasında esnek alan, minimum 28 pt
- CTA alt boşluğu: 22 pt

### 7.2 Dekoratif arka plan

- Ana zemin: `background`
- Sağ üst: `softPink` %28, 280×280 daire, 2 pt blur, offset x 150 / y -310
- Sol alt: `tertiary` %34, 230×230 daire, offset x -170 / y 330
- Dekoratif öğeler accessibility ağacından gizlenir.

### 7.3 Marka grubu

- “AYA”: 62 pt editorial semibold, secondary, tracking 4
- Grup spacing: 12 pt
- Karşılama başlığı: 29 pt editorial semibold
- Açıklama: 15 pt UI regular, secondaryText
- Bütün metinler ortalıdır.

### 7.4 Form kartı

- Surface: white %82 opacity
- Padding: 20 pt
- İç bölüm spacing: 26 pt
- Radius: 24 pt
- Border: secondary %12, 1 pt
- Shadow: semantic shadow, radius 16, y 8

Ad input:

- Yükseklik: minimum 52 pt
- Horizontal padding: 16 pt
- Radius: 16 pt
- Normal border: divider
- Focus border: primary
- Font: 17 pt UI regular
- Bütün input yüzeyi dokunulabilir olmalıdır; yalnızca placeholder/metin alanı hit target olmamalıdır.

Dil seçimi:

- İki eşit genişlikte buton
- Aralık: 10 pt
- Yükseklik: minimum 46 pt
- Radius: 14 pt
- Seçili: primary yüzey + beyaz metin + filled checkmark
- Seçili değil: beyaz yüzey + primaryText + boş circle

Devam CTA:

- Tam genişlik
- Minimum yükseklik: 52 pt
- Radius: 16 pt
- Arka plan: secondary
- Metin: surface, 16 pt semibold
- Ad boşken disabled ve %45 opacity

## 8. Yaşam dönemi seçim ekranı

### 8.1 Sayfa yerleşimi

- Navigation bar gizlidir.
- Background: `#F9F5F6`
- Yatay sayfa padding: 8 pt
- Normal dikey padding: 16 pt
- Kompakt dikey padding: 12 pt
- Başlık ile ilk kart arası: normal 20 pt, kompakt 18 pt
- Kart aralığı: normal 10 pt, kompakt 8 pt
- Yükseklik 730 pt’den küçükse compact metrics kullanılır.
- Başlık ve bütün kart grubu, içerik ekrana sığıyorsa sayfada dikey olarak ortalanır.
- İçerik sığmıyorsa ScrollView doğal olarak kaydırılır.
- Alt bilgi paneli kullanılmaz.

Başlık:

- Ortalanmış
- Normal 26 pt, kompakt 23 pt
- Editorial semibold
- Tracking: -0.5
- Line spacing: -4
- Yatay kart sınırlarıyla aynı hizada

### 8.2 Ortak kart ölçüleri

| Özellik | Değer |
|---|---:|
| Normal yükseklik | 132 pt |
| Kompakt yükseklik | 120 pt |
| Accessibility Dynamic Type yüksekliği | 258 pt |
| Köşe yarıçapı | 26 pt continuous |
| Yatay iç padding | 20 pt |
| Üst padding | 14 pt |
| Alt padding | 15 pt |
| Kart başlığı maksimum genişliği | 240 pt |
| Açıklama genişliği | Kart genişliğinin %50’si |
| Başlık–açıklama spacing | 3 pt |
| Açıklama line spacing | 1 pt |

- Kartın tamamı butondur; ayrı CTA bulunmaz.
- Açıklama en fazla 2 satırdır.
- Başlık tek satır hedefler, minimum scale factor 0.9’dur.
- Premium kartlar disabled veya gri görünmez.
- Badge kartın sağ altındadır.
- Seçili kartın sağ üstünde checkmark dairesi vardır.

### 8.3 Badge

| Özellik | Değer |
|---|---:|
| Yükseklik | 19.8 pt |
| Yatay padding | 6.6 pt |
| İçerik spacing | 4.4 pt |
| Radius | 6.05 pt |
| Metin | 7.7 pt medium |
| Premium kilit | 8.25 pt medium |

- Badge sağ-alt hizalanır ve tabandan 8 pt yukarı offset alır.
- Free badge kilit kullanmaz.
- Premium badge küçük `lock` SF Symbol kullanır.

### 8.4 Seçili durum

- Border normalde 1 pt semantic border’dır.
- Seçiliyken border 2 pt ve kartın accent rengidir.
- Accent renginde %28 opacity, radius 9 glow kullanılır.
- Sağ üstte 24×24 pt accent daire içinde 11 pt bold checkmark bulunur.
- Checkmark container kart kenarından 11 pt içeridedir.
- Animasyon zorunlu değildir; rahatsız edici pulse kullanılmaz.

## 9. Yaşam dönemi kart temaları

### 9.1 Regl Döngüsü / Menstrual Cycle

- Koyu ve baskın karttır.
- Background gradient: `secondary (#6C2645)` → `primary (#99627A)`, yukarıdan aşağı
- Başlık: surface
- Açıklama: surface %88
- Accent/seçim: tertiary
- Border: surface %14
- Badge surface: primary
- Badge foreground: surface
- Asset: `stage_cycle_orbit`
- Asset rendering: resizable + scaledToFill
- Scale: x 1.05 / y 1.15
- Runtime color blend: secondary %72 → primary %58 gradient, `.blendMode(.color)`

### 9.2 Hamilelik / Pregnancy

- Background: tertiary %58
- Secondary background: tertiary
- Başlık: secondary
- Açıklama: secondary %88
- Accent: primary
- Badge surface: tertiary %88
- Badge foreground: secondary
- Asset: `stage_pregnancy_sprout`
- Scale: x 1.05 / y 1.15

### 9.3 Lohusalık / Postpartum

- Background: softPink %44
- Secondary background: softPink
- Başlık: secondary
- Açıklama: secondary %88
- Accent: primary
- Badge surface: softPink %76
- Badge foreground: secondary
- Asset: `stage_postpartum_rest`
- Scale: x 1.11 / y 1.21

### 9.4 Annelik / Motherhood

- Background: primary %10
- Secondary background: primary %16
- Başlık: secondary
- Açıklama: secondary %88
- Accent: primary
- Badge surface: primary %16
- Badge foreground: secondary
- Asset: `stage_motherhood_blocks`
- Scale: x 1.11 / y 1.21

### 9.5 Asset kuralları

- Kart assetleri değiştirilmemeli, yeniden çizilmemeli veya farklı isimle kopyalanmamalıdır.
- SVG yerine mevcut PNG assetleri kullanılmalıdır.
- Asset isimleri, scaleEffect değerleri, opacity ve rendering yöntemi ekran bazında keyfi değiştirilmemelidir.
- Kart assetleri dekoratiftir; hit testing ve accessibility kapalıdır.

## 10. Dönem detay / “Yakında” ekranı

- Background: main background
- İçerik ekran merkezindedir.
- Başlık: 34 pt editorial semibold, primaryText
- Başlık altı spacing: 9 pt
- “Yakında / Coming soon”: 16 pt UI medium, secondaryText
- Yatay içerik padding: 24 pt
- Sistem geri butonu ve navigation bar gizlidir.

Profil düğmesi:

- Sağ üst safe area içinde özel overlay olarak yer alır; navigation toolbar içine konmaz.
- Sağ padding: 16 pt
- Safe area üstünden padding: 8 pt
- Ölçü: tam 44×44 pt
- Shape: gerçek Circle; üstten/alttan kırpılmamalıdır.
- Surface: secondary
- Baş harf: surface, 19 pt bold
- Kullanıcının trim edilmiş adının ilk harfi ve uppercase değeri gösterilir.
- Accessibility label: Ayarlar/Settings
- Ayarlar açılınca profil düğmesi tamamen kaybolur.

## 11. Ayarlar yan paneli

### 11.1 Panel kabuğu

- Sağdan açılır.
- Genişlik: `min(336 pt, ekran genişliğinin %88’i)`
- Background: main background
- Sol üst ve sol alt radius: 28 pt
- Horizontal padding: 20 pt
- Üst padding: `max(safeAreaTop + 14, 72)`
- Alt padding: `max(safeAreaBottom + 16, 24)`
- Ana dikey spacing: 22 pt
- Arka scrim: secondary %24
- Geçiş: sağdan move + genel opacity, 0.22 sn easeOut
- Reduce Motion açıksa animasyon kapatılır.
- Dış alana dokunmak paneli kapatır.
- Panel klavye safe area değişiminde yerinden oynamamalıdır.

Header:

- Başlık: 28 pt editorial semibold
- Kapatma: 44×44 beyaz daire
- X icon: 14 pt bold
- Border: divider, 1 pt
- Profil baş harfi panel açıkken görünmez.

### 11.2 AYA Temaları satırı

- 52 pt minimum yükseklik
- Surface card
- 18 pt radius
- 16 pt yatay padding
- Icon alanı 22 pt
- İç spacing 12 pt
- Metin 15 pt medium
- Sağda 12 pt semibold chevron
- Seçim ekranına geri döndürür.

### 11.3 Profil/ad alanı

- Section label: 13 pt medium uppercase, secondaryText
- Section label ile kart arası: 9 pt
- Kart radius: 18 pt
- Kart horizontal padding: 16 pt
- Kart vertical padding: 11 pt
- Label: 12 pt medium
- TextField: 15 pt regular, minimum 32 pt
- Kullanıcı adı `AppStorage("user.name")` ile canlı ve kalıcı güncellenir.
- Submit sırasında baştaki/sondaki whitespace temizlenir.
- Panel kapatıldığında sağ üst profil baş harfi yeni adı yansıtır.

### 11.4 Dil accordion

- Kapalı satır yüksekliği: minimum 52 pt
- Seçenek satırı: minimum 46 pt
- Ana metin: 15 pt medium
- Seçenek metni: 14 pt regular
- Globe ve checkmark/circle SF Symbols kullanılır.
- Chevron açıldığında 180 derece döner.
- Animasyon: 0.18 sn easeInOut; Reduce Motion’da kapalı.

### 11.5 Support bağlantıları

- Grup radius: 18 pt
- Satır yüksekliği: minimum 50 pt
- Horizontal padding: 16 pt
- Icon alanı: 22 pt
- İç spacing: 12 pt
- Metin: 14 pt medium
- Separator: divider, 1 pt; soldan 50 pt inset
- Sağda küçük `arrow.up.right`

## 12. Etkileşim ve durum yönetimi

- İlk açılış tamamlandı durumu: `AppStorage("onboarding.completed")`
- Dil: `AppStorage("app.language")`
- Kullanıcı adı: `AppStorage("user.name")`
- Ad whitespace ile normalize edilir; boş adla onboarding tamamlanamaz.
- Dil seçimi anında SwiftUI locale ortamını günceller.
- Yaşam dönemi kartının tamamı minimum erişilebilir dokunma alanıdır.
- Kart seçimi view model içinde tutulur ve kullanıcı tema ekranına döndüğünde görünür kalır.
- Premium kartlar şimdilik ödeme sheet’i açmaz; kendi “Yakında” ekranlarına gider.

## 13. Localization

- Kaynak: `Localizable.xcstrings`
- Source language: English
- Desteklenen diller: `en`, `tr`
- Swift dosyalarında kullanıcı metni hardcode edilmez.
- Semantic key yaklaşımı kullanılır.

Temel key grupları:

```text
welcome.*
life_stage.*
stage.coming_soon
settings.*
common.*
```

- Türkçe karakterler korunmalıdır: `İ, ı, ş, Ş, ğ, Ğ, ü, Ü, ö, Ö, ç, Ç`.
- İngilizce metinlerin daha uzun olabileceği hesaba katılmalıdır.

## 14. Accessibility ve responsive kurallar

- Minimum dokunma alanı 44×44 pt’dir.
- Dekoratif assetler ve arka plan şekilleri accessibility ağacından gizlenir.
- Kartlar anlamlı title, hint ve selected trait taşır.
- Ayarlar ve kapatma düğmeleri lokalize accessibility label kullanır.
- Dynamic Type büyüdüğünde kart yüksekliği 258 pt expanded düzene geçer.
- Kart açıklaması iki satıra kırılabilir.
- Kart başlığı truncation yerine en fazla 0.9 scale kullanır.
- Sayfalar küçük ekranda ScrollView ile kaydırılır.
- Klavye input veya panel kontrollerinin üzerini kapatmamalıdır.
- Reduce Motion açıkken zorunlu olmayan animasyon uygulanmaz.
- Yalnız opacity ile anlatılan disabled state oluşturma; onboarding CTA’sında ayrıca gerçek `.disabled` kullanılır.
- Light Mode zorunludur: `.preferredColorScheme(.light)`.

## 15. Yeni ekran üretme kuralları

Yeni bir AYA ekranı hazırlanırken:

1. Ana zeminde `AYAColors.background` kullan.
2. Açık içerik gruplarında `surface` kullan.
3. Başlığı editorial, gövde ve kontrolleri UI rolüyle oluştur.
4. Primary/secondary rengini ekranın tamamına yayma; vurgu için kullan.
5. Container radius için öncelikle 18, 24 veya 26 pt ölçeklerinden birini seç.
6. Border’ı 1 pt semantic divider/border ile sınırla.
7. Ağır siyah shadow veya saf siyah metin kullanma.
8. Kontrolleri en az 44 pt hit target ile oluştur.
9. Türkçe ve İngilizce preview ekle.
10. Bütün görünür metinleri String Catalog’a koy.
11. Dynamic Type ve küçük iPhone ekranında yatay taşmayı kontrol et.
12. Mevcut kart PNG assetlerini değiştirme veya başka amaçla yeniden kullanma.

## 16. Yapılmaması gerekenler

- Eski mavi/sage/lavender paleti ana marka rengi olarak geri getirilmemeli.
- Bütün açık kartlar aynı pembe tona dönüştürülmemeli.
- Premium kartlar disabled/gri gösterilmemeli.
- Body veya buton metninde editorial serif kullanılmamalı.
- Font dosyası bulunmadan Satoshi/Nyght PostScript adı tahmin edilmemeli.
- View içinde tekrar tekrar `Color(hex:)` yazılmamalı.
- Büyük insan illüstrasyonu, medikal ikonografi veya bebek mağazası estetiği kullanılmamalı.
- Ağır gradient, neon glow, yoğun blur ve sert shadow kullanılmamalı.
- Profil baş harfi navigation toolbar içine konmamalı; iOS toolbar clipping uygulanabilir.
- Parent container’a accessibility identifier vererek alt kontrollerin kimlikleri ezilmemeli.

## 17. Kaynak dosyalar

Tasarımın uygulamadaki kaynakları:

```text
AYA/DesignSystem/AYAColors.swift
AYA/DesignSystem/AYATypography.swift
AYA/DesignSystem/View+Extensions.swift
AYA/App/WelcomeView.swift
AYA/Features/LifeStageSelection/LifeStageSelectionView.swift
AYA/Features/LifeStageSelection/LifeStageCardView.swift
AYA/Features/LifeStageSelection/LifeStageTheme.swift
AYA/Features/LifeStageSelection/StageMotifs/*.swift
AYA/Resources/Assets.xcassets
AYA/Resources/Localizable.xcstrings
```

Bu belge ile kod arasında uyuşmazlık oluşursa çalışan merkezi design token dosyaları renk ve tipografi için son teknik kaynak kabul edilmelidir.
