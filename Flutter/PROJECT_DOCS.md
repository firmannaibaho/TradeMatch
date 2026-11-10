# TradeMatch Documentation

## ARCHITECTURE

### Overview
TradeMatch adalah aplikasi barter/tukar barang berbasis Flutter dengan backend Supabase.

### Tech Stack
| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Dart) |
| Backend | Supabase (PostgreSQL + Auth + Storage) |
| State | StatefulWidget + FutureBuilder |
| Cache | Hive (local storage) |
| Maps | flutter_map + Geolocator |

### Authentication & Data Layer
- **Auth**: Supabase Auth (email/password + Google OAuth)
- **Database**: PostgreSQL via Supabase
- **Storage**: Supabase Storage (bucket: `item-images`)

### Key Schema Changes (Laravel → Supabase)
| Field | Laravel (old) | Supabase (new) |
|-------|---------------|----------------|
| `user_id` | `int` | `UUID (String)` |

### Storage Buckets Required
| Bucket | Access | Purpose |
|--------|--------|---------|
| `item-images` | Public | Item photos |
| `profile-pictures` | Public | User avatars |

---

## DECISION LOG

### 2024-12-17: Supabase Migration Issues

#### Problem 1: "Invalid radix-10 number" in Library Screen
**Context**: After migrating from Laravel to Supabase, Library screen crashed.
**Root Cause**: `Item.userId` was `int`, but Supabase returns UUID strings.
**Solution**: Changed `userId` from `int` to `String` in `models/item.dart`:
```dart
// Before
final int userId;
userId: int.parse(json['user_id'].toString());

// After  
final String userId;
userId: json['user_id'].toString();
```

#### Problem 2: Images uploaded but not linked to items
**Context**: Images uploaded to Supabase Storage successfully, but `item_images` table stayed empty.
**Root Cause**: Dart arrow function syntax issue - `=> {}` creates a Set literal, not a Map.
**Solution**: Use explicit return block:
```dart
// WRONG (creates Set)
.map((entry) => {
  'item_id': id,
  'image_url': url,
})

// CORRECT (creates Map)
.map((entry) {
  return {
    'item_id': id,
    'image_url': url,
  };
})
```

#### Problem 3: Android 13+ Photo Permission Denied
**Context**: Even after user approves permission dialog, `Permission.photos` returns denied.
**Root Cause**: Android 13+ uses new granular media permissions (`READ_MEDIA_IMAGES`), not `Permission.photos`.
**Solution**: Let `image_picker` plugin handle permissions internally.

---

## CODE SNIPPETS

### Dart: Batch Insert with Map (Supabase)
```dart
// Correct way to map list to insert data
final imageInserts = imageUrls.asMap().entries.map((entry) {
  return {
    'item_id': itemId,
    'image_url': entry.value,
    'display_order': entry.key,  // 0, 1, 2...
  };
}).toList();

await supabase.from('item_images').insert(imageInserts);
```

### Flutter: High Accuracy Location
```dart
Position position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
  timeLimit: const Duration(seconds: 15),
);

List<Placemark> placemarks = await placemarkFromCoordinates(
  position.latitude, position.longitude,
);

// Fallback chain for city name
String city = placemarks.first.locality ?? 
              placemarks.first.subAdministrativeArea ?? 
              placemarks.first.administrativeArea ?? 
              'Unknown';
```

### Supabase: UUID User ID Parsing
```dart
// Flexible parsing that works for both int and UUID
userId: json['user_id'].toString(),

// With null safety for optional fields
currency: json['currency'] ?? 'USD',
status: json['status'] ?? 'active',
locationLat: double.parse((json['location_lat'] ?? 0).toString()),
```
