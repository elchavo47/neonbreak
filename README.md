# NeonBreak iOS v5.12.0

Yeni API adresi, bloklara gömülü güçler (41+), yeni çark ve büyük ödül, davet basamakları, e-posta teklifi, lig mesajı 7 dilde. Ayrıntılar: `UPDATE_v5.12.0.txt`. Backend v1.14.0 ile birlikte çıkar.

# NeonBreak iOS v5.11.0

Hız topları, reklam doğrulaması, rıza/izin, davet, hesap silme, ayarlar sayfaları, skor kartı, 7 dil. Ayrıntılar: `UPDATE_v5.10.0.txt`. Backend v1.12.0 gerektirir.

# NeonBreak iOS v5.9.0

Reklamla coin/güç kazanma ve 5 yeni dil. Ayrıntılar: `UPDATE_v5.9.0.txt`. Backend v1.11.0 gerektirir.

# NeonBreak iOS v5.8.0

AdMob ödüllü reklam ve uygulama içi dil seçimi. Ayrıntılar: `UPDATE_v5.8.0.txt`.

# NeonBreak iOS v5.7.0

Cila paketi: kırılma efektleri, kombo, ağır çekim, tehlike nabzı, sayarak gelen oyun sonu, coin uçuş animasyonu, tüm ekranlarda aynı yazı stili. Ayrıntılar: `UPDATE_v5.7.0.txt`.

# NeonBreak iOS v5.6.0

Ana ekran yenilendi, alt menü, kaydırarak top değiştirme, canlı sıralama. Ayrıntılar: `UPDATE_v5.6.0.txt`. Backend v1.10.0 gerektirir.

# NeonBreak iOS v5.5.0

Lig sistemi, kariyer hedefleri, çerçeve/unvan, bildirim izni hatırlatması, skor paylaşma, puanlama penceresi. Ayrıntılar: `UPDATE_v5.5.0.txt`. Backend v1.9.0 gerektirir.

# NeonBreak iOS v5.4.0

Engelli hesap itirazı ve trafik izleme koruması. Ayrıntılar: `UPDATE_v5.4.0.txt`. Backend v1.8.0 gerektirir.

# NeonBreak iOS v5.3.0

Blok boyutu düzeltmesi, kolaylaştırılmış 10-24, bildirim tıklaması ve tercihleri, yeni destek merkezi. Ayrıntılar: `UPDATE_v5.3.0.txt`. Backend v1.7.0 gerektirir.

# NeonBreak iOS v5.2.0

Performans, küçük bloklar, eski coin sistemi, 24 sonrası kolaylık, fotoğraf limiti, push altyapısı. Ayrıntılar: `UPDATE_v5.2.0.txt`. Backend v1.6.0 gerektirir.

# NeonBreak iOS v5.1.0

Coin'e vurarak kazanma, günlük görevler, kaldığın yerden devam, ödüllü reklam altyapısı, yerel bildirimler, İngilizce. Ayrıntılar ve reklam kurulumu: `UPDATE_v5.1.0.txt`. Backend v1.5.0 gerektirir.

# NeonBreak iOS v5.0.0

Oyun ekranı yeniden yazıldı, mağaza genişletildi. Ayrıntılar: `UPDATE_v5.0.0.txt`. Backend v1.4.0 gerektirir.

# NeonBreak iOS v4.5.2 BUILD FIX

- Xcode 26.6 notification center compile fixes
- Home notification button initializer fix
- Duplicate FPS settings card removed
- Notification center now uses existing reward/announcement/support state and works offline from cached state

# Neon Break iOS v4.5.0

Bildirim merkezi + gerçek SpriteKit FPS seçimi güncellemesi.

# Neon Break iOS v4.2.3 — Runtime Fix

This package is based on v4.2.2 and focuses on avatar upload reliability, haptics, runtime performance and long straight aiming.

# Neon Break iOS v4.2.0 PREMIUM

v4.1.0 PERFORMANCE tabanından; kasma düzeltmeleri + sıfırdan üretilmiş premium görsel/ses paketi.

## Performans
- Bloklar `SKShapeNode + glowWidth` yerine önceden çizilmiş texture'lı `SKSpriteNode` (glow texture'a pişirildi).
- Oyun içi arka plan: 50-100 animasyonlu shape node yerine tek sprite (tema PNG'si) + tek ambient glow.
- Top izi: top başına `SKEmitterNode` yerine tek additive kuyruk sprite'ı.
- Partikül / halka / balon / flaş efektleri sprite tabanlı.
- Nişan çizgisinde glow kapatıldı, launcher ve tehlike çizgisi sprite.
- Skor güncellemesi birikimli (~8 Hz) yayınlanıyor; UserDefaults her vuruşta yazılmıyor.
- HUD'daki canlı blur (`ultraThinMaterial`) oyun sırasında düz yarı saydam zeminle değiştirildi.
- `HapticsManager.supportsPerHitHaptics` her vuruşta `uname()` çağırmak yerine bir kez hesaplanıyor.

## Görseller / Sesler
- 7 top, 6 dünya arka planı, uygulama ikonu (kare, maskesiz) ve logo yeniden üretildi.
- 14 SFX yeniden sentezlendi (aynı dosya adları).
