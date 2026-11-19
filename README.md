# SpendLog Mobile

A standalone, offline-first mobile expense and income tracker built using Flutter, Drift ORM, and SQLite.

## Overview

SpendLog Mobile is a mobile application designed to help users track personal expenses and income with simplicity, speed, and complete privacy. All financial data is stored locally on the device with zero cloud tracking, third-party accounts, or internet connectivity required.

Built with mobile-first principles and Clean Architecture, the application features an intuitive Material 3 user interface with dynamic theme switching, monthly aggregations, categorized transactions, income and expense tracking, and high-performance local SQLite querying.

## Features

* Add, edit, and delete expenses and income entries
* Expense / Income toggle with dynamic category switching
* 6 expense categories (Food, Transport, Shopping, Bills, Stationery, Other)
* 3 income categories (Salary, Allowance, Other)
* 3-in-1 Hero Summary Card — Net Balance with Income and Spent breakdown
* GPay-style amount colors (green `+` for income, neutral for expenses)
* Real-time monthly summaries with visual totals
* Historical monthly archives — zero-expense months shown so you can always add retroactive entries
* Smooth swipe navigation between tabs with preserved scroll state
* JSON backup export via native Save-As dialog (SAF) with date-stamped filenames
* JSON import with strict validation and atomic SQLite rollback on failure
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

* **Drift ORM** (Type-safe, reactive SQL client for Dart) — `schemaVersion 2`
* **SQLite** (via `sqlite3_flutter_libs`)
* **shared_preferences** (Theme preference persistence)
* **file_picker** (SAF-based JSON backup export & import)

## Project Structure

```text
spendlog_mobile/
├── android/                             # Android native host project & build configurations
├── assets/                              # App assets & launcher icons
│   └── icons/
├── ios/                                 # iOS native project structure
├── lib/
│   ├── core/
│   │   ├── database/                    # Drift SQLite database definition & tables (schemaVersion 2)
│   │   │   ├── tables/
│   │   │   │   └── expenses.dart
│   │   │   ├── app_database.dart
│   │   │   └── app_database.g.dart
│   │   ├── theme/                       # Material 3 light & dark theme definitions
│   │   │   └── app_theme.dart
│   │   └── utils/                       # Currency, date formatters & backup service
│   │       ├── backup_service.dart
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

* Flutter SDK (3.44+ recommended)
* Java 21 LTS (Microsoft OpenJDK 21 recommended)
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
* Biometric authentication lock
* Optional cloud synchronization with desktop SpendLog

## Current Status

Version 2.0.0 completed.

Implemented features include offline SQLite persistence with Drift ORM (schemaVersion 2), full CRUD operations for expenses and income entries, expense/income toggle with dynamic categories, 3-in-1 Hero Summary Card (Net Balance, Income, Spent), GPay-style amount colors, continuous monthly history (empty months preserved), SAF-based JSON backup export and import with atomic rollback on failure, tab swipe navigation, automated monthly archiving and summary calculations, category tagging, dynamic light/dark theming, 58/58 passing automated tests, release keystore signing, and architecture-split production APKs.
