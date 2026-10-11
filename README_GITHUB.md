# SpendLog Mobile

A sleek, lightweight, offline-first personal expense tracker built with Flutter.

SpendLog Mobile is designed with mobile-first principles and strict clean architecture, ensuring total privacy, fast performance, and a delightful user experience with zero external dependencies.

---

## ✨ Features

- 🔒 **100% Offline & Private** — All data remains strictly on your device using a local SQLite database powered by Drift ORM. No internet access, account creation, or cloud tracking required.
- 📐 **Clean Architecture** — Top-down unidirectional data flow: UI Widgets &rarr; Riverpod Providers &rarr; Repository Layer &rarr; Local Data Source.
- 🎨 **Modern Material 3 Design** — Thoughtfully crafted UI with smooth transitions, custom hero summary cards, dynamic category badges, and instant Light/Dark theme switching.
- 📅 **Smart Monthly Tracking** — Expenses are automatically grouped by month with real-time totals, category breakdowns, and detailed monthly views.
- ⚡ **Optimized Performance** — Indexed database queries for instant searches and smooth 60 FPS scrolling even with extensive transaction histories.
- 🏷️ **Core Categories** — Pre-configured with 6 essential spending categories: Food, Transport, Utilities, Entertainment, Health, and Shopping.

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Stable channel) |
| **Language** | Dart |
| **State Management** | Flutter Riverpod |
| **Database ORM** | Drift |
| **Database Engine** | SQLite (via `sqlite3_flutter_libs`) |
| **Platform Target** | Android |
| **Typography & Formatting** | `intl` |

---

## 🏗 Architecture Overview

The app enforces strict layer isolation. UI components never communicate directly with the database or ORM types:

```
UI Layer (Screens & Widgets)
          ↓ (watches / calls)
State Management (Riverpod Providers)
          ↓ (interacts with)
Repository Layer (Domain logic & plain Dart models)
          ↓ (calls)
Local Data Source (Drift queries & schema mappings)
          ↓ (persists to)
SQLite Database (`spendlog.db`)
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.24+ recommended)
- Java 17 or Java 21 LTS
- Android SDK with platform tools (or a connected physical Android device / emulator)

### Setup & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/spendlog_mobile.git
   cd spendlog_mobile
   ```

2. **Install Flutter packages:**
   ```bash
   flutter pub get
   ```

3. **Generate Drift database code:**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## 🧪 Testing & Code Quality

Run the automated test suite (including unit tests, repository tests, validation checks, and UI shell integration tests):

```bash
flutter test
```

Run static code analysis:

```bash
flutter analyze
```

---

## 📦 Building Production Release

To generate lightweight, architecture-optimized release APKs:

```bash
flutter build apk --release --split-per-abi
```

The split APKs will be output to:
`build/app/outputs/flutter-apk/` (e.g. `app-arm64-v8a-release.apk` for modern Android devices).

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
