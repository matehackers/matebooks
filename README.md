# MateBooks

ISBN Barcode Scanner & Book/Magazine Catalog — a cross-platform Flutter app for scanning ISBN barcodes, looking up book and magazine metadata from online APIs, and managing your personal catalog in a cloud database.

## Features

- **Barcode scanning** — scan ISBN barcodes with the device camera using MLKit/AVFoundation
- **Auto lookup** — fetches title, author, publisher, cover art, description, and more from Open Library, Google Books, Crossref, and DOAJ
- **Cloud sync** — stores your entire catalog in a [Turso](https://turso.tech) (libSQL) database accessible from all your devices
- **Full CRUD** — add, edit, delete items; mark them as "book" or "magazine"
- **Cover photos** — attach camera photos for front and back covers (stored as base64)
- **Search & filter** — search by title, author, or ISBN; filter by book/magazine type
- **Material 3** — light and dark theme support via `ThemeMode.system`

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart 3.11+) |
| State management | [Provider](https://pub.dev/packages/provider) (ChangeNotifier) |
| Database | [Turso](https://turso.tech) (libSQL) via HTTP pipeline API |
| Barcode scanning | [mobile_scanner](https://pub.dev/packages/mobile_scanner) |
| Image caching | [cached_network_image](https://pub.dev/packages/cached_network_image) |
| Camera/photos | [image_picker](https://pub.dev/packages/image_picker) |
| HTTP client | [http](https://pub.dev/packages/http) |
| Fonts | [google_fonts](https://pub.dev/packages/google_fonts) |

## Project Structure

```
matebooks/
├── lib/
│   ├── main.dart                        # App entry point, MaterialApp, Provider setup
│   ├── config.dart                      # Turso DB credentials
│   ├── models/
│   │   └── catalog_item.dart            # CatalogItem data model
│   ├── services/
│   │   ├── turso_service.dart           # Turso/libSQL CRUD operations
│   │   ├── data_lookup_service.dart     # Unified online lookup with fallback chain
│   │   └── open_library_service.dart    # Open Library API client
│   ├── screens/
│   │   ├── library_screen.dart          # Main grid view + LibraryProvider
│   │   ├── scan_screen.dart             # Barcode scanner screen
│   │   ├── edit_screen.dart             # Add/edit item form
│   │   └── detail_screen.dart           # Item detail view
│   └── widgets/
│       ├── catalog_card.dart            # Grid card widget
│       └── empty_state.dart             # Empty-state placeholder
├── test/
│   └── widget_test.dart                 # Smoke test
├── android/                             # Android platform files
├── ios/                                 # iOS platform files
├── macos/                               # macOS platform files
├── linux/                               # Linux platform files
├── windows/                             # Windows platform files
├── web/                                 # Web platform files
├── pubspec.yaml
├── pubspec.lock
└── analysis_options.yaml
```

## Architecture

```
main.dart
  └── ChangeNotifierProvider<LibraryProvider>
       └── MaterialApp (Material 3, indigo seed, system theme)
            └── LibraryScreen (home)
                 ├── GridView of CatalogCard widgets
                 ├── SearchBar + type filter
                 ├── FAB → ScanScreen
                 │          └── EditScreen (fallback for manual entry)
                 ├── CatalogCard tap → DetailScreen
                 │                     └── EditScreen (edit)
                 └── Pull-to-refresh → reload from Turso
```

### Data Flow

1. **App starts** → `LibraryProvider.loadItems()` → `TursoService.initializeDatabase()` (creates/upgrades schema) → `TursoService.getAllItems()` → UI renders grid
2. **Scan ISBN** → `mobile_scanner` detects barcode → validates ISBN format (10-13 digits) → checks Turso for existing entry → runs `DataLookupService.fetchByIsbn()`:
   - **Books:** Open Library → Google Books → Crossref
   - **Magazines:** DOAJ → Crossref
   - Auto-inserts found data into Turso and returns the item
   - Falls back to `EditScreen` for manual entry if no data found
3. **EditScreen saves** → `TursoService.insertItem()` / `updateItem()` → pops with `CatalogItem`
4. **Delete** → `TursoService.deleteItem()` → `LibraryProvider.loadItems()` refreshes

### Lookup Fallback Chain

```
Books:    Open Library API → Google Books API → Crossref API
Magazines: DOAJ API → Crossref API
```

All services are singletons. No API keys are required for any of the lookup sources.

## Database Schema (Turso/libSQL)

```sql
CREATE TABLE books (
  id                  TEXT PRIMARY KEY,
  isbn                TEXT UNIQUE NOT NULL,
  title               TEXT NOT NULL,
  authors             TEXT,
  publisher           TEXT,
  published_date      TEXT,
  page_count          INTEGER,
  cover_url           TEXT,
  cover_image_base64  TEXT,
  back_image_base64   TEXT,
  description         TEXT,
  categories          TEXT,
  notes               TEXT,
  type                TEXT DEFAULT 'book',
  created_at          TEXT,
  updated_at          TEXT
);
```

> `authors` and `categories` are stored as comma-separated strings. `type` is `'book'` or `'magazine'` (the `CatalogType` enum values).

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.11+)
- A physical device or emulator with a camera (for barcode scanning)
- A [Turso](https://turso.tech) account and database (see below)

### Setup

1. **Clone and install dependencies:**

   ```bash
   git clone <repo-url> matebooks
   cd matebooks
   flutter pub get
   ```

2. **Configure Turso credentials:**

   Pass them as `--dart-define` arguments when running or building:

   ```bash
   flutter run --dart-define=TURSO_DB_URL=https://your-db.turso.io --dart-define=TURSO_AUTH_TOKEN=your-token
   ```

   Or create a `.env` file (don't commit it) and use:

   ```bash
   # .env
   TURSO_DB_URL=https://your-db.turso.io
   TURSO_AUTH_TOKEN=your-token
   ```

   ```bash
   flutter run --dart-define-from-file=.env
   ```

   > **Security note:** Never commit your actual Turso credentials. The `.env` file is not tracked by git.

3. **Run the app:**

   ```bash
   flutter run
   ```

### Available Commands

| Command | Purpose |
|---------|---------|
| `flutter pub get` | Install dependencies |
| `flutter run` | Run on a connected device/emulator |
| `flutter build apk` | Build Android APK |
| `flutter build ios` | Build iOS app |
| `flutter build web` | Build for web |
| `flutter build macos` | Build for macOS |
| `flutter build linux` | Build for Linux |
| `flutter build windows` | Build for Windows |
| `flutter test` | Run the smoke test in `test/widget_test.dart` |
| `flutter analyze` | Run static analysis (flutter_lints) |

### Target Platforms

Android, iOS, Web, macOS, Linux, Windows

> Barcode scanning uses `mobile_scanner` which wraps MLKit (Android) and AVFoundation (iOS). Desktop/web builds may have limited or no scanning support.

## Navigation Flow

```
LibraryScreen (home)
  ├── push → ScanScreen
  │            └── push → EditScreen (if manual entry needed)
  │            └── pop → CatalogItem (back to LibraryScreen)
  └── push → DetailScreen
               └── push → EditScreen (edit existing item)
               └── pop → back to LibraryScreen (after delete)
```

## Areas for Improvement

1. **Test coverage** — Only one smoke test exists. Add unit tests for `CatalogItem.fromJson`/`toJson`, service methods, and widget tests for each screen.

3. **Error handling** — Print-based logging throughout the codebase (`// ignore: avoid_print`). Replace with a proper logging framework or remove debug prints.

4. **Offline support** — The app requires a network connection for all operations. Consider local caching with SQLite as a fallback.

5. **Image storage** — Cover photos are stored as base64 strings in the database row. This will cause performance issues with large catalogs. Consider uploading to cloud storage (S3/R2) and storing URLs instead.

6. **Empty `google_fonts` usage** — The `google_fonts` package is a dependency but the code uses the default `TextTheme` from `ThemeData` without explicit `GoogleFonts.*` calls. Either use it or remove the dependency.

7. **Android CAMERA permission** — The `AndroidManifest.xml` does not declare `<uses-permission android:name="android.permission.CAMERA"/>` (though `mobile_scanner` may merge it automatically). Add it explicitly to be safe.

8. **Desktop barcode scanning** — `mobile_scanner` has limited support on desktop platforms. Consider a manual ISBN entry fallback for desktop users.

9. **Provider placement** — `LibraryProvider` is defined in `library_screen.dart` but registered at the app root. It would be cleaner to move the provider class to a separate file (e.g., `lib/providers/library_provider.dart`).

10. **Error states** — The `TursoService` error handling could be improved. Currently errors throw generic exceptions; structured error types would help the UI display more useful messages.

## License

_Add license information here._

---

Built with [Flutter](https://flutter.dev) and [Turso](https://turso.tech).
