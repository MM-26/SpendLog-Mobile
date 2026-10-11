# SpendLog Mobile

A standalone, offline-first mobile expense tracker built using Flutter, Drift ORM, and SQLite.

## Overview

SpendLog Mobile is a mobile application designed to help users track personal expenses with simplicity, speed, and complete privacy. All financial data is stored locally on the device with zero cloud tracking, third-party accounts, or internet connectivity required.

Built with mobile-first principles and Clean Architecture, the application features an intuitive Material 3 user interface with dynamic theme switching, monthly aggregations, categorized expenses, and high-performance local SQLite querying.

## Features

* Add, edit, and delete daily expenses
* 6 spending categories (Food, Transport, Utilities, Entertainment, Health, Shopping)
* Real-time monthly spending summaries with visual totals
* Historical monthly archives with detailed transaction lists
* Date picker with sensible boundary validation
* 100% offline-first architecture with on-device SQLite storage
* Instant Light and Dark mode switching with persistent preferences
* Optimized indexed queries for fast startup and smooth 60 FPS scrolling
* Modern Material 3 mobile UI with custom category badges and hero summary cards

## Tech Stack

### Frontend & UI

* **Flutter** (Channel stable)
* **Material Design 3**
* **intl** (Currency and date formatting)

### State Management & Architecture

* **Flutter Riverpod** (Declarative state management & dependency injection)
* **Clean Architecture** (Separation of UI, Providers, Domain Repositories, and Data Sources)

### Database & Persistence

* **Drift ORM** (Type-safe, reactive SQL client for Dart)
* **SQLite** (via `sqlite3_flutter_libs`)
* **shared_preferences** (Theme preference persistence)

## Project Structure

```text
spendlog_mobile/
├── android/                             # Android native host project & build configurations
├── assets/                              # App assets & launcher icons
│   └── icons/
├── ios/                                 # iOS native project structure
├── lib/
│   ├── core/
│   │   ├── database/                    # Drift SQLite database definition & tables
│   │   │   ├── tables/
│   │   │   │   └── expenses.dart
│   │   │   ├── app_database.dart
│   │   │   └── app_database.g.dart
│   │   ├── theme/                       # Material 3 light & dark theme definitions
│   │   │   └── app_theme.dart
│   │   └── utils/                       # Currency and date utility formatters
│   │       ├── currency_formatter.dart
│   │       └── date_formatter.dart
│   ├── data_sources/                    # Local data persistence
│   │   └── local/
│   │       └── expense_local_data_source.dart
│   ├── models/                          # Domain models (Expense, MonthSummary)
│   │   ├── expense.dart
│   │   └── month_summary.dart
│   ├── providers/                       # Riverpod state notifiers & providers
│   │   ├── expense_provider.dart
│   │   └── theme_provider.dart
│   ├── repositories/                    # Domain repositories (Business logic layer)
│   │   └── expense_repository.dart
│   ├── screens/                         # Application screens & navigation shell
│   │   ├── add_expense/
│   │   │   └── add_expense_screen.dart
│   │   ├── history/
│   │   │   └── history_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── month_detail/
│   │   │   └── month_detail_screen.dart
│   │   ├── settings/
│   │   │   └── settings_screen.dart
│   │   └── main_navigation_shell.dart
│   ├── widgets/                         # Reusable UI widgets
│   │   ├── category_badge.dart
│   │   ├── expense_list_tile.dart
│   │   └── hero_total_card.dart
│   ├── app.dart                         # Root MaterialApp configuration
│   └── main.dart                        # Application entrypoint
├── test/                                # Unit, repository, performance & widget test suite
├── pubspec.yaml                         # Project dependencies & assets configuration
└── README.md
```

## Architecture

The project enforces strict layer isolation. UI components never interact directly with Drift or SQLite database types:

```text
UI Layer (Screens & Widgets)
          ↓ (watches / invokes)
State Management (Riverpod Providers)
          ↓ (calls)
Repository Layer (Domain logic & plain Dart models)
          ↓ (queries)
Local Data Source (Drift queries & entity mappings)
          ↓ (persists)
SQLite Database (`spendlog.db`)
```

## Running the Project

### Prerequisites

* Flutter SDK (3.24+ recommended)
* Java 17 or Java 21 LTS
* Android Studio / Android SDK (or a connected Android device / emulator)

### Setup & Run

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Generate Drift code**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

3. **Run on connected device/emulator**:
   ```bash
   flutter run
   ```

### Running Tests

Execute the automated test suite covering data source, repository, state providers, and UI integration:

```bash
flutter test
```

Execute static analysis:

```bash
flutter analyze
```

### Building Release APK

Build lightweight architecture-specific release APKs:

```bash
flutter build apk --release --split-per-abi
```

Generated APKs will be located in:
`build/app/outputs/flutter-apk/`

## Future Enhancements

* Custom budget limits per category
* Search and transaction filtering
* Spending visual charts and analytics
* CSV / JSON data backup and export
* Biometric authentication lock
* Optional cloud synchronization with desktop SpendLog

## Current Status

Version 1.0.0 completed.

Implemented features include offline SQLite persistence with Drift ORM, full CRUD operations for expenses, automated monthly archiving and summary calculations, category tagging, dynamic light/dark theming, 46/46 passing automated tests, release keystore signing, and architecture-split production APKs.
