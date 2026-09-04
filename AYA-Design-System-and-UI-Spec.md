# HESIA — Visual Design System and UI Specification

> Bu belge HESIA iOS uygulamasının çalışan SwiftUI arayüzünü tarif eder. Yeni ekranlar bu sistemi devam ettirmeli; renk, tipografi, boşluk ve bileşen kararları view dosyalarında yeniden tanımlanmamalıdır.
>
> **Son güncelleme:** 17 Ağustos 2026 — tasarım sistemi v3 geçişi.
> Kod ile bu belge çeliştiğinde `AYA/DesignSystem/` altındaki token dosyaları esas alınır.

---

## 1. Ürün ve platform

- Uygulama: **HESIA**
- Platform: iPhone, SwiftUI
- Minimum sürüm: **iOS 17**
- Görünüm: **Light ve Dark Mode** — ikisi de desteklenir ve test edilmelidir
- Diller: Türkçe (lansman), İngilizce kaynakları kodda hazır (`HESIAFeatureFlags.supportsMultipleLanguages`)
- Referans genişlik: 393 pt
- Ölçüler SwiftUI point cinsindendir.
- Kullanıcıya görünen bütün metinler `Localizable.xcstrings` üzerinden gelir.

### Liquid Glass hakkında

iOS 26 Liquid Glass **bilinçli olarak kullanılmamaktadır**. Uygulama iOS 17'yi hedefler ve her ekranda navigation bar gizlidir; Apple'ın rehberi cam efektini navigasyon katmanına ayırır, içerik katmanına değil. Sıcak, editorial bir kimlik için cam malzemenin sağlayacağı bir kazanç yoktur.

---

## 2. Marka hissi

HESIA sakin, sıcak, yetişkin ve editorial bir meditasyon uygulamasıdır.

- Premium ancak gösterişli değil
- Kadın odaklı fakat aşırı pembe değil
- Medikal görünmeyen, anne-bebek mağazası estetiğine kaymayan
- Bol açık yüzey, kontrollü mürdüm vurgu
- Ağır gölge, saf siyah, yüksek doygunluk yok

**Yapılmayacaklar:** rastgele gradient, neon glow, yoğun blur, sert shadow, her elemanı yuvarlak karta çevirmek, her yerde dev başlık, gövde metninde serif.

---

## 3. Renk

Kaynak: `AYA/DesignSystem/AYAColors.swift`. Bütün tokenlar appearance-aware (`Color(light:dark:)`).

### 3.1 Marka paleti

| Token | Light | Dark |
|---|---|---|
| `primary` / `accent` | `#99627A` | `#CE9EB6` |
| `secondary` / `emphasis` | `#6C2645` | `#C98BA6` |
| `tertiary` | `#FEEBC8` | `#5A4A38` |
| `softPink` | `#ECC0D3` | `#5A3B48` |

### 3.2 Semantic roller

| Token | Light | Dark | Kullanım |
|---|---|---|---|
| `backgroundPrimary` | `#F7F3EF` | `#141013` | Ekran zemini |
| `backgroundSecondary` | `#EFE7E0` | `#1C161A` | İkincil zemin, quiet fill |
| `surfaceElevated` | `#FFFFFF` | `#2A222A` | **Bütün kartlar** |
| `textPrimary` | `#241C21` | `#F2EAEE` | Başlık ve gövde |
| `textSecondary` | `#6E616A` | `#B7A8B0` | Açıklama |
| `textTertiary` | `#796B73` | `#968892` | Metadata |
| `onAccent` | `#FFFFFF` | `#1A0F14` | Accent/emphasis üstü |
| `border` | `secondary` %14 | — | Kart konturu |
| `separator` | `secondary` %10 | — | Satır arası hairline |

**Kontrast kuralı.** Her ink tokenı, üzerine düştüğü **en kötü** yüzeye karşı 4.5:1 geçmelidir. `textTertiary` bu yüzden iki appearance'ta da yeniden ölçüldü:

| | Eski | Yeni | En kötü yüzey |
|---|---|---|---|
| light | `#9C8F96` (2.80:1) | `#796B73` | **4.57:1** — `backgroundPrimary` |
| dark | `#8A7C84` (3.89:1) | `#968892` | **4.58:1** — `surfaceElevated` |

**Tek yüzey kuralı.** Kartlar daima `surfaceElevated` kullanır. Eski `cardSurface` aliası kaldırıldı — light modda `surface` ile aynı olduğu için dark modda fark edilmeden iki farklı elevation üretiyordu.

**Tek çizgi kuralı.** Sadece `border` (kart konturu) ve `separator` (satır arası) vardır. Eski `divider` (%12) kaldırıldı.

View içinde `Color(hex:)` yazılmaz; yeni ihtiyaç için önce semantic token üretilir.

---

## 4. Tipografi

Kaynak: `AYA/DesignSystem/AYATypography.swift`.

### 4.1 Tek kural: her metin ölçeklenir

Bütün metinler `.ayaTypography(_ role:)` ile yazılır. Bu modifier `@ScaledMetric` kullanır ve Dynamic Type'a uyar.

`AYATypography.ui(size:)` ve `.editorial(size:)` **ölçeklenmez**. Yalnızca Dynamic Type'ın görseli bozacağı sabit-metrik iki yerde kullanılır: karşılama wordmark'ı ve seek ikonunun içine gömülü rakam. **Metin için asla kullanılmaz.**

### 4.2 Roller

| Rol | Boyut | Weight | Tasarım |
|---|---:|---|---|
| `playerTitle` | 30 | Semibold | Serif |
| `screenTitle` | 26 | Semibold | Serif |
| `homeGreeting` | 26 | Semibold | Serif |
| `stageCardTitle` | 23.25 | Semibold | Serif |
| `homeMetricValue` | 23.25 | Semibold | Serif |
| `stageCardTitleLong` | 21 | Semibold | Serif |
| `homeInsightTitle` | 19 | Semibold | Serif |
| `homeMeditationTitle` | 18.5 | Semibold | Serif |
| `price` | 17 | Semibold | Sans |
| `sectionTitle` / `homeSectionHeading` / `button` | 16 | Semibold | Sans |
| `body` / `settingsRowTitle` | 15 | Regular / Medium | Sans |
| `homeBody` / `homeCTA` | 14 | Regular / Semibold | Sans |
| `metadata` / `settingsRowValue` / `sectionLabel` / `homeSupporting` | 13 | Medium / Regular | Sans |
| `homeMetadata` / `homeLink` | 12 | Medium | Sans |
| `badge` / `homeBadge` | 11 | Semibold | Sans |

**v3'te yükseltilenler:** `homeBody` 12→14, `homeSupporting` 12→13, `homeMetadata` 11→12, life-stage kart rozeti 7.7→11. 12 pt gövde metni uygulamayı sıkışık gösteriyordu; 11 pt altı hiçbir metin kalmamıştır.

Serif yalnızca başlıklarda; gövde, buton ve kontrollerde asla.

---

## 5. Boşluk, radius, elevation

### 5.1 Boşluk — `AYASpacing`

`xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`

Literal padding yazılmaz.

### 5.2 Layout — `AYALayout`

| Token | Değer |
|---|---:|
| `screenHorizontalPadding` | **20** |
| `screenTopPadding` | 16 |
| `screenBottomPadding` | 24 |
| `sectionSpacing` | 24 |
| `readableContentMaxWidth` | 760 |

**Tek gutter kuralı.** Ekran kenar boşluğu her yerde `.hesiaScreenPadding()` ile uygulanır. Eskiden 16/18/20/22/24 olmak üzere beş farklı değer vardı; Home'dan takvime geçerken içerik kenarı gözle görülür şekilde kayıyordu.

### 5.3 Radius — `AYARadius`

| Token | Değer | Kullanım |
|---|---:|---|
| `chip` | 8 | Rozet, küçük çip |
| `control` | 16 | Buton, input, ayar satırı |
| `card` | 22 | **Bütün kartlar** (hero dahil) |
| `hero` | 28 | Ayarlar paneli, tam yükseklikli yüzey |

Literal `cornerRadius:` yazılmaz. v3'te 18 (14 yer) ve 26 (3 yer) tamamen kaldırıldı. Hero kart artık `card` kullanır — eskiden dolgu 26, kontur 28 olduğu için Lohusalık hero kartının köşelerinde görünür bir boşluk vardı.

Daima `.continuous`.

### 5.4 Elevation — `AYAElevation`

`card` (radius 9, y 5) · `raised` (radius 12, y 5) · `panel` (radius 22, x -8). Sıcak, düşük opaklık; asla siyah.

### 5.5 İkon — `HesiaIconSize`

`sm 14` (chevron, inline metadata) · `md 18` (satır ikonu) · `lg 22` (feature) · `hero 48` (onboarding dairesi).

---

## 6. Paylaşılan bileşenler

Yeni ekran yazarken önce buraya bakılır. Aynı görsel elemanı ikinci kez elle kurmak yasaktır.

### 6.1 Ekran iskeleti

| Bileşen | Görev |
|---|---|
| `HomeScreenScaffold` | Dört Home ekranının kabuğu. Header `safeAreaInset` ile **sabitlenir** — eskiden scroll ile kayboluyor, Ayarlar'a tek giriş noktası erişilemez hâle geliyordu. |
| `HomeHeader` / `HomeHeaderDetail` | Selamlama + alt bilgi + profil düğmesi. |
| `ScreenHeader` | Geri düğmesi + ortalanmış başlık (takvim, timeline). |
| `.hesiaScreenPadding()` | Tek gutter. |
| `.hesiaBottomBar()` | Alt CTA çubuğu: `.thinMaterial` + hairline separator. Eski altı ayrı `backgroundPrimary.opacity(0.96…0.98)` varyantının yerine geçer. |

### 6.2 İçerik

| Bileşen | Görev |
|---|---|
| `LifeStageHeroCard` | Home durum paneli: ring + rozet + başlık + paragraf. |
| `StageProgressRing` | İlerleme halkası. Dinamik payda için `totalLabelText`. |
| `LifeStageOverviewSection` | Bölüm başlığı + link + yatay timeline. |
| `LifeStageHorizontalTimeline` | Gün/hafta şeridi. |
| `DailyMeditationCard` | Günün meditasyonu — **gerçek `Button`**. |
| `LifeStageContinuationCard` | Dönemler arası geçiş. |
| `SectionHeader` | Bölüm başlığı + isteğe bağlı trailing aksiyon. |
| `HesiaBadge` | Tek kapsül rozet (`soft` / `themed` / `neutral`). Eskiden yedi farklı yükseklik vardı; yükseklik artık metinden türer. |
| `ContextualInfoButton` / `ContextualInfoSheet` | Bilgi katmanı. |

### 6.3 Ayarlar

`SettingsGroup` · `SettingsSectionLabel` · `SettingsNavigationRow` · `SettingsToggleRow` · `SettingsLinkRow` · `SettingsStatusRow` · `SettingsRowSeparator` · `SettingsRowIcon` · `SettingsRowValue`.

Tek radius (`control`), tek satır yüksekliği (52 / stacked 62), tek etiket stili. Panelde daha önce üç radius (16/18/22) ve beş satır yüksekliği aynı kolonda alt alta duruyordu.

### 6.4 Buton stilleri

- `.buttonStyle(.appPrimary)` — tam genişlik plum CTA, min 52 pt.
- `HesiaCardButtonStyle` — tam kart butonları için ölçülü press geri bildirimi (Reduce Motion'da kapalı).

---

## 7. Uygulama akışı

```text
İlk açılış
  └─ Karşılama (ad)
      └─ Tanıtım (6 adım)
          └─ Çevrimdışı dinleme
              └─ Face ID
                  └─ Yaşam dönemi seçimi
                      ├─ Regl Döngüsü  → onboarding → Home
                      ├─ Hamilelik     → paywall → setup → Home
                      ├─ Doğum Anı     → paywall → Home
                      ├─ Lohusalık     → paywall → kişiselleştirme → Home
                      └─ Annelik       → (feature flag ile gizli)
```

- Tab bar yoktur: aynı anda tek bir aktif yaşam dönemi vardır.
- Navigation bar her ekranda gizlidir; geri hareketleri `hesiaInteractivePopGesture` / `hesiaRootEdgeBack` ile korunur.
- Ayarlar sağdan açılan özel bir drawer'dır; Temalar'a yalnızca buradan dönülür.

---

## 8. Durumlar

Veri gösteren her ekran dördünü de karşılamalıdır.

| Durum | Kural |
|---|---|
| **Loading** | Nihai yerleşimle örtüşen placeholder. `DailyMeditationCard` metadata beklerken metadata satırını iskeletle doldurur — böylece içerik zıplamaz. Shimmer kullanılmaz. |
| **Empty** | Davet, özür değil. |
| **Error** | Ne olduğu + tekrar dene. Player'da tam ekran hata durumu, Home'da kart içi `meditation.card.offline_notice` şeridi. |
| **Loaded** | Tek öğe, çok öğe, uzun isim, eksik görsel. |

---

## 9. Hareket ve haptik

- Ekran geçişi 0.30 sn, player 0.35 sn (`HESIAMotion`).
- **Reduce Motion** açıkken hareket opaklıkla değiştirilir, sadece kısaltılmaz.
- Sayaçlarda `.contentTransition(.numericText())`.
- Haptik: yaşam dönemi seçimi ve onboarding adımı (`.selection`), player oynat/duraklat (`.selection`), bitiş (`.success`). Ölçülü kullanılır.

---

## 10. Accessibility

- Minimum dokunma alanı **44×44 pt**.
- Bütün metinler Dynamic Type ile ölçeklenir; XXL ve accessibility boyutlarında test edilir.
- Hero kart ve ayar satırları büyük boyutlarda dikey yerleşime geçer.
- Dekoratif görseller accessibility ağacından gizlenir.
- **`onTapGesture` ile buton yapılmaz.** Tıklanabilir her şey `Button`'dır. `DailyMeditationCard` bu yüzden yeniden yazıldı: eski hâli tap gesture + `PreferenceKey` hit-exclusion kullanıyordu, bu yüzden VoiceOver kullanıcıları kartı hiç etkinleştiremiyordu.
- Ayarlar drawer'ı `.accessibilityAddTraits(.isModal)` taşır.
- Renk tek başına anlam taşımaz.

---

## 11. Localization

- Kaynak: `Localizable.xcstrings`, semantic key yaklaşımı.
- Swift dosyalarında kullanıcı metni hardcode edilmez.
- Türkçe karakterler korunur: `İ ı ş Ş ğ Ğ ü Ü ö Ö ç Ç`.
- İngilizce metinlerin daha uzun olabileceği hesaba katılır.

---

## 12. Yeni ekran kontrol listesi

1. Zemin `AYAColors.backgroundPrimary`, kartlar `surfaceElevated`.
2. Gutter `.hesiaScreenPadding()`.
3. Bütün metinler `.ayaTypography(_:)`.
4. Radius yalnızca `AYARadius`'tan.
5. Boşluk yalnızca `AYASpacing` / `AYALayout`'tan.
6. Önce paylaşılan bileşene bak; yoksa üret ve buraya ekle.
7. Tıklanabilir her şey `Button`, min 44 pt.
8. Dört durum da ele alınmış.
9. Light + Dark, TR + EN, Dynamic Type XXL preview'ları eklenmiş.
10. Kontrast en kötü yüzeye karşı ölçülmüş.

---

## 13. Kaynak dosyalar

```text
AYA/DesignSystem/AYAColors.swift
AYA/DesignSystem/AYATypography.swift
AYA/DesignSystem/AYASpacing.swift
AYA/DesignSystem/AYARadius.swift
AYA/DesignSystem/AYAElevation.swift
AYA/DesignSystem/HesiaLayout.swift        // AYALayout, hesiaScreenPadding, hesiaBottomBar, ScreenHeader
AYA/DesignSystem/HesiaBadge.swift
AYA/DesignSystem/HesiaIcon.swift          // HesiaIcon, HesiaIconSize
AYA/DesignSystem/SettingsRow.swift
AYA/DesignSystem/SectionHeader.swift
AYA/DesignSystem/AppPrimaryButton.swift
AYA/DesignSystem/LifeStageDetailTheme.swift
AYA/DesignSystem/View+Extensions.swift    // HESIAMotion, geçişler
AYA/Features/Shared/HomeScreenScaffold.swift
AYA/Features/Shared/LifeStageHeroCard.swift
AYA/Features/Shared/LifeStageOverviewSection.swift
AYA/Features/Shared/StageProgressRing.swift
AYA/Features/Meditation/DailyMeditationCard.swift
AYA/Features/Settings/SettingsPanel.swift
AYA/Resources/Assets.xcassets
AYA/Resources/Localizable.xcstrings
```
