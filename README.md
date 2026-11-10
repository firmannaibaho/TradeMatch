# TradeMatch

**Deskripsi Singkat:**  
TradeMatch adalah aplikasi barter modern yang memungkinkan pengguna untuk saling menukar barang dengan cara yang efisien, aman, dan menyenangkan. Aplikasi ini menggabungkan konsep "match system" layaknya aplikasi dating untuk menemukan pasangan barter yang cocok berdasarkan kebutuhan dan penawaran pengguna.

---

## 👥 Anggota Kelompok
| Nama | NIM |
|------|-----|
| Qhanakin Ahmad Zhavi | 231402071 |
| Firman Karunia Naibaho | 231402074 |
| Alfathin suwailim | 231402096 |
| Muhammad Ilyas Hasibuan | 231402106 |
| Rifki Reysaad Bangun | 231402109 |

---

## 🚀 Rencana Fitur Aplikasi

### 1. Profile
Berisi informasi dasar pengguna seperti nama, lokasi, foto, dan deskripsi singkat.  
Menampilkan daftar barang yang ditawarkan (offer) dan dibutuhkan (requirement).  
Pengguna dapat mengedit profil, menambah atau menghapus barang, serta memperbarui status barter.

### 2. Library
Berfungsi sebagai "gudang pribadi" pengguna.  
Menampilkan semua barang yang dimiliki, baik yang aktif, sudah dibarter, maupun disimpan.  
Pengguna dapat mengatur ulang barang, menandai statusnya ("aktif", "terbuka untuk barter", "selesai"), atau menghapus item.

### 3. Beranda (Home & Explore)
Halaman utama tempat pengguna menemukan dan menjelajahi barang milik pengguna lain.  
Fitur ini menggabungkan fungsi *explore* dan *swipe system* layaknya aplikasi dating untuk menemukan pasangan barter yang cocok.

Fitur utama di halaman ini:
- **Swipe Kanan →** tertarik barter  
- **Swipe Kiri →** lewati  
- **Match System:** jika kedua pengguna sama-sama tertarik, maka akan terjadi *match* dan fitur chat akan terbuka.  
- **Rekomendasi Barang:** menampilkan barang baru di sekitar lokasi pengguna atau sesuai kategori favorit.  
- **Aktivitas Komunitas:** notifikasi match baru dan barter yang berhasil.  

Halaman ini juga dapat menampilkan **update barang terbaru**, **notifikasi**, serta **rekomendasi personal** berdasarkan riwayat barter pengguna.

### 4. Chat
Fitur **Chat** memungkinkan pengguna berkomunikasi langsung setelah terjadi *match* antara dua pengguna.  
Tujuannya untuk memudahkan negosiasi dan memastikan kesepakatan barter berjalan lancar.  

Fitur yang tersedia di dalam Chat:
- **Pesan Teks:** pengguna bisa saling mengirim pesan untuk mendiskusikan detail barter.  


Chat menjadi jembatan penting sebelum melangkah ke fitur **Janji Temu**, karena semua kesepakatan mengenai pertukaran barang biasanya dilakukan di tahap ini.

### 5. Janji Temu (Meet-Up)
Fitur pengaturan pertemuan setelah barter disepakati.  
Pengguna dapat menentukan lokasi pertemuan.  
Fitur integrasi dengan *maps* untuk melihat lokasi barter.


## 🧠 Deskripsi Teknis Project

| Aspek | Detail |
|-------|--------|
| **Jenis Aplikasi** | Cross Platform Mobile |
| **Frontend Framework** | Flutter stable (Dart SDK `^3.9.2`) |
| **Backend Services** | Supabase (PostgreSQL, Edge Functions, Realtime) |
| **Database** | PostgreSQL dengan Row Level Security (RLS) |
| **Autentikasi** | Supabase Auth (JWT) + Google OAuth |
| **Real-time Engine** | Supabase Realtime (Postgres Changes) |
| **Server Logic** | Supabase Edge Functions (TypeScript/Deno) |
| **Maps & Location** | `flutter_map` + OpenStreetMap + `geolocator` |
| **Image Caching** | `cached_network_image` + Hive local storage |
| **Target Platform** | Android |

---

## Menjalankan di Windows

Pastikan Flutter stable yang mendukung Dart `^3.9.2`, Android Studio/Android SDK,
dan Android Emulator atau perangkat Android terhubung. Java 17 atau lebih baru
dibutuhkan untuk build Android; gunakan JDK bawaan Android Studio bila tersedia.

1. Periksa setup dan terima lisensi Android:

   ```powershell
   flutter doctor -v
   flutter doctor --android-licenses
   ```

2. Dari folder `Flutter`, ambil dependency dan jalankan aplikasi:

   ```powershell
   cd Flutter
   flutter pub get
   flutter run
   ```

   Alternatifnya, jalankan `..\run_tradematch.bat` dari folder root repository.
   Skrip akan memakai device Android yang terhubung atau menyalakan AVD pertama
   yang tersedia. Flutter membuat `android/local.properties` sesuai SDK di
   komputer; file itu bersifat lokal dan tidak perlu disalin dari komputer lain.

3. Koneksi Supabase dan Google OAuth memakai nilai proyek bawaan. Untuk
   menggantinya saat menjalankan build, berikan compile-time defines:

   ```powershell
   flutter run `
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co `
     --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY `
     --dart-define=GOOGLE_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID
   ```

   `API_BASE` juga dapat diganti dengan `--dart-define=API_BASE=...`.
   Gunakan hanya Supabase anon/publishable key di aplikasi; jangan masukkan
   service-role key ke build Flutter.

Build iOS memerlukan macOS dan Xcode. Google OAuth di Android juga perlu
dikonfigurasi pada Supabase/Google Cloud untuk package ID `com.example.project`.

---

## 🔗 Arsitektur Sistem

TradeMatch menggunakan arsitektur **Serverless Modern** dengan Supabase sebagai backend:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter Client                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │   Screens   │  │   Widgets   │  │   Services  │  │   Models    │ │
│  └─────────────┘  └─────────────┘  └──────┬──────┘  └─────────────┘ │
└──────────────────────────────────────────┬──────────────────────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Supabase Platform                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │    Auth     │  │  Database   │  │  Realtime   │  │   Storage   │ │
│  │   (JWT)     │  │ (PostgreSQL)│  │ (WebSocket) │  │   (Bucket)  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │
│                           │                                          │
│  ┌────────────────────────┴────────────────────────────────────────┐ │
│  │                     Edge Functions (Deno)                        │ │
│  │  process-swipe │ get-explore-feed │ confirm-trade │ create-review│ │
│  └──────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Komponen Utama

#### 1. Flutter Client
- **SupabaseService** (`lib/services/supabase_service.dart`): Layer komunikasi tunggal ke Supabase
- **State Management**: StatefulWidget + setState untuk reaktivitas UI
- **Secure Storage**: `flutter_secure_storage` untuk token JWT
- **Local Cache**: Hive untuk offline-first experience

#### 2. Supabase Backend

| Service | Fungsi |
|---------|--------|
| **Auth** | Registrasi, login email/password, Google OAuth, JWT management |
| **Database** | PostgreSQL dengan RLS untuk keamanan data per-user |
| **Realtime** | Push notification messages via WebSocket subscription |
| **Storage** | Upload dan serve gambar profil & item |
| **Edge Functions** | Business logic serverless (matching, trade, dll) |

#### 3. Edge Functions

| Function | Deskripsi |
|----------|-----------|
| `process-swipe` | Handles like/dislike, creates swap on mutual match, prevents race conditions |
| `get-explore-feed` | Generates personalized feed, filters own/swiped items, sanitizes data |
| `confirm-trade` | Validates dual confirmation, updates swap status to 'completed' |
| `suggest-location` | Stores meetup location proposal in swap record |
| `accept-location` | Confirms agreed meetup location between both parties |
| `create-review` | Creates post-trade review, enforces one-review-per-user rule |

---

## 📊 Database Schema

### Tabel Utama

| Tabel | Deskripsi |
|-------|-----------|
| **users** | Profil pengguna (name, email, phone, location, profile_picture_url) |
| **items** | Barang barter (title, description, category, condition, location, status) |
| **item_images** | Multiple images per item dengan display order |
| **item_wants** | Kategori yang diinginkan sebagai tukar (trade preferences) |
| **categories** | Daftar kategori barang (Electronics, Fashion, Books, dll) |
| **swipes** | Riwayat swipe (like/skip) per user-item pair |
| **swaps** | Matched trades antara dua item/user |
| **messages** | Chat messages dalam swap, termasuk location sharing |
| **notifications** | System notifications (new_swap, new_message, status_change) |

### Status Flow

```
Swipe Like ─→ Mutual Match ─→ Swap Created (active)
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            location_suggested  negotiating    cancelled
                    │
                    ▼
            location_agreed
                    │
                    ▼
            trade_complete ─→ Review Submitted
```

---

## 🎨 Design System & UI/UX

TradeMatch menggunakan design system modern dengan pendekatan **Glassmorphism**:

### Visual Style
- **Typography**: Inter font family (Google Fonts) dengan 10 text style variants
- **Color Palette**: Primary Orange (#FD7E14), semantic colors (success, error, warning)
- **Spacing**: 4px grid system (xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48)
- **Effects**: Glassmorphism (backdrop blur), gradient accents, elevation shadows

### Responsive Layout
| Device | Breakpoint | Layout |
|--------|------------|--------|
| Mobile | < 600px | Bottom navigation, single column |
| Tablet | 600-1024px | Side rail navigation, 2-column grid |
| Desktop | > 1024px | Full side navigation, multi-column |

### Component Library (`lib/widgets/`)
- **GlassContainer/GlassCard**: Frosted glass effect dengan backdrop blur
- **GradientButton**: Gradient buttons dengan loading states dan shadows
- **AnimatedListItem**: Staggered animations untuk list items
- **Skeleton Loading**: Shimmer placeholders saat loading data

### Micro-Interactions
- **Swipe Gestures**: Scale dan opacity feedback saat drag, haptic feedback
- **Match Notification**: Full-screen overlay dengan confetti animation
- **Pull-to-Refresh**: Custom indicator dengan spring bounce
- **Hero Transitions**: Shared element transitions antar screen

---

## 🛠️ Development Setup

### Prerequisites
- Flutter SDK 3.35.2+
- Android Studio / VS Code
- Supabase project (database, auth, storage, edge functions)

### Installation
```bash
# Clone repository
git clone https://github.com/your-repo/TradeMatch.git
cd TradeMatch/Flutter

# Install dependencies
flutter pub get

# Configure Supabase credentials
# Edit lib/services/supabase_service.dart with your project URL and anon key

# Run application
flutter run
```

### Environment Configuration
```dart
// lib/services/supabase_service.dart
static const String supabaseUrl = 'https://your-project.supabase.co';
static const String supabaseAnonKey = 'your-anon-key';
```

---

## 📱 Implementasi Layout Dasar

1. **Halaman Beranda (Home):** menampilkan barang terbaru dan rekomendasi barter.  
2. **Halaman Explore (Swipe):** tempat pengguna menemukan potensi barter dengan sistem *match*.  
3. **Halaman Profil (Profile):** menampilkan identitas dan daftar barang pengguna.  

> Layout ini merupakan dasar tampilan utama yang akan dikembangkan lebih lanjut menjadi aplikasi barter interaktif.

---

## 📚 Kesimpulan

TradeMatch membentuk ekosistem barter digital yang efisien dan menyenangkan.  
Dengan fitur-fitur yang terintegrasi (Profile, Library, Swipe, Chat, dan Meet-Up), serta arsitektur modern berbasis Supabase yang scalable, pengguna dapat menemukan pasangan barter yang cocok dan melakukan pertukaran barang secara aman dan transparan.
