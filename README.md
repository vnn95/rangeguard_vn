# 🌿 RangerGuard VN

**Hệ thống quản lý tuần tra rừng thông minh** dựa trên chuẩn SMART Conservation Tools.

Built with Flutter 3.24+ · Supabase · PostGIS · Riverpod 2.0

---

## ✨ Tính năng chính

| Module | Tính năng |
|--------|-----------|
| 🔐 Auth | Login/Register, phân quyền 4 cấp (Admin/Leader/Ranger/Viewer) |
| 🗺️ Bản đồ | 4 lớp tile (OSM/Satellite/Terrain/Google), Polyline, Heatmap, Waypoint popup |
| 🥾 Tuần tra | Import SMART GeoJSON, Live GPS tracking, Chụp ảnh bất thường, Offline sync |
| 📅 Lịch | Calendar view, tạo lịch tuần tra, giao nhiệm vụ |
| 📊 Báo cáo | Dashboard thống kê, biểu đồ, export Excel/PDF |
| 📡 Offline | Hive local storage, tự động sync khi có mạng |

---

## 🏗️ Cấu trúc dự án

```
lib/
├── core/
│   ├── constants/   # AppConstants, AppColors
│   ├── theme/       # AppTheme (Material 3, Forest Green)
│   ├── router/      # GoRouter config
│   ├── supabase/    # SupabaseConfig
│   └── utils/       # GeoUtils, DateUtils, OfflineSync
├── models/          # Patrol, Waypoint, Schedule, SmartImport
├── repositories/    # AuthRepository, PatrolRepository
├── providers/       # Riverpod providers
├── screens/
│   ├── auth/        # Login, Register
│   ├── dashboard/   # Dashboard với stats + chart
│   ├── map/         # flutter_map với 4 lớp tile
│   ├── patrol/      # List, Detail, Start, Import
│   ├── schedule/    # Calendar + tạo lịch
│   ├── reports/     # Báo cáo + biểu đồ
│   ├── settings/    # Cài đặt app
│   └── profile/     # Hồ sơ cá nhân
├── widgets/
│   └── common/      # MainScaffold, AppLoading, AppError
└── main.dart
```

---

## 🚀 Hướng dẫn cài đặt

### 1. Clone project

```bash
git clone https://github.com/vnn95/rangeguard_vn.git
cd rangeguard_vn
```

### 2. Cấu hình Supabase

**a. Tạo Supabase project** tại [supabase.com](https://supabase.com)

**b. Chạy migration:**
```bash
# Dùng Supabase CLI
supabase link --project-ref YOUR_PROJECT_REF
supabase db push

# Hoặc copy nội dung file vào SQL Editor trên Dashboard
supabase/migrations/001_initial_schema.sql
```

**c. Tạo Storage buckets:**
Vào Storage > New bucket:
- `avatars` (public: true)
- `patrol-photos` (public: false)

**d. Tạo file `.env`:**
```bash
cp .env.example .env
# Điền SUPABASE_URL và SUPABASE_ANON_KEY từ Settings > API
```

### 3. Cài Flutter dependencies

```bash
flutter pub get
```

### 4. Chạy app

```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios
```

---

## 🌐 Deploy Flutter Web

### Vercel

```bash
# Build web
flutter build web --release

# Deploy
cd build/web
vercel --prod
```

### Firebase Hosting

```bash
flutter build web --release
firebase init hosting  # chọn build/web làm public dir
firebase deploy
```

---

## 📱 Build Mobile

### Android APK

```bash
flutter build apk --release
# File: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
# Mở Xcode để archive và submit
open ios/Runner.xcworkspace
```

---

## 🗄️ Database Schema

```
profiles       → Thông tin tuần tra viên
stations       → Trạm kiểm lâm
patrols        → Chuyến tuần tra (PostGIS LineString)
waypoints      → Điểm GPS (PostGIS Point)
schedules      → Lịch tuần tra (PostGIS Polygon)
mandates       → Mệnh lệnh / nhiệm vụ
```

---

## 📦 Import dữ liệu SMART

File GeoJSON hỗ trợ:
- `NewPatrol` → Thông tin bắt đầu
- `Waypoint` → Điểm GPS tự động
- `Animal` / `Threat` / `Photo` → Quan sát đặc biệt
- `StopPatrol` → Kết thúc chuyến

```bash
# Trong app: Tuần tra > Import SMART > Chọn file
# Hoặc: Import dữ liệu mẫu (patrol2_sample.json)
```

---

## 🔧 Cấu hình môi trường

| Biến | Mô tả | Bắt buộc |
|------|-------|----------|
| `SUPABASE_URL` | URL project Supabase | ✅ |
| `SUPABASE_ANON_KEY` | Anon key Supabase | ✅ |
| `MAPBOX_ACCESS_TOKEN` | Token Mapbox (nếu dùng) | ❌ |

---

## 👥 Phân quyền

| Role | Dashboard | Bản đồ | Tạo Patrol | Import | Lịch | Báo cáo | Admin |
|------|-----------|--------|-----------|--------|------|---------|-------|
| Admin | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Leader | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Ranger | ✅ | ✅ | ✅ | ❌ | 👁️ | 👁️ | ❌ |
| Viewer | ✅ | ✅ | ❌ | ❌ | 👁️ | 👁️ | ❌ |

---

## 🛠️ Tech Stack

- **Flutter 3.24+** - Cross-platform UI
- **Supabase** - Backend (PostgreSQL + PostGIS + Auth + Storage)
- **Riverpod 2.0** - State management
- **GoRouter 14** - Navigation
- **flutter_map 7** - Maps
- **Hive** - Offline storage
- **fl_chart** - Charts
- **table_calendar** - Calendar view
- **geolocator** - GPS tracking

---

## 📄 License

MIT © 2024 RangerGuard VN Team

---

> Dựa trên chuẩn SMART Conservation Tools - https://smartconservation.org
