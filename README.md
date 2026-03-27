# Smart Kirana App

A Flutter + Firebase app for small kirana stores to manage:
- billing
- daily credit ledger
- customer-wise borrow/deposit tracking
- customer bill history

## Tech Stack

- Flutter (Material 3)
- Dart
- Firebase Core
- Cloud Firestore
- Speech to Text (item search input support)

## Main Screens

- `lib/main.dart`
  - Home dashboard
  - Navigation to Billing, Customers, and Daily Ledger
- `lib/billing_screen.dart`
  - Create bills
  - Supports `Paid` and `Credit` mode
  - Stores bill in Firestore `bills`
  - For credit bills, creates a pending entry in Firestore `ledger`
- `lib/ledger_screen.dart`
  - Daily ledger view (today only)
  - Add manual credit entries
  - Mark pending entries as received/paid
- `lib/customer_screen.dart`
  - Customer list with remaining balance
  - Search customers
- `lib/customer_report_screen.dart`
  - Per-customer Borrow and Deposit view
  - Manual borrow/deposit entries
- `lib/customer_history_screen.dart`
  - Bill history for a customer
  - Date range filtering
- `lib/bill_detail_screen.dart`
  - Bill item-level detail view

## Firestore Collections (Current Data Model)

### 1) `bills`
Saved from `BillingScreen` for every bill.

Typical fields:
- `customer` (String)
- `items` (List of item maps)
- `subtotal` (num)
- `discount` (num)
- `extra` (num)
- `finalTotal` (num)
- `paymentType` (`Paid` or `Credit`)
- `date` (String timestamp)

### 2) `ledger`
Used for credit and customer balance flow.

Typical fields:
- `customer` (String)
- `billAmount` (num)
- `pendingAmount` (num)
- `status` (`pending`, `paid`, `manualBorrow`, `manualDeposit`)
- `date` (String timestamp)
- Optional: `isManual`, `paidAt`, `paidSameDay`, `paidAmount`, `note`

### 3) `customers`
Customer master list.

Typical fields:
- `name` (String)
- `createdAt` (String timestamp)

### 4) `items`
Item master list and pricing metadata.

Typical fields:
- `name` (String)
- `lastPrice` (num)
- `unitType` (`count` or `weight`)
- `defaultUnit` (e.g., `pcs`, `packet`, `kg`, `g`)
- `updatedAt` (String timestamp)

## Credit vs Borrow Behavior

Current implemented flow:

When a credit bill is created:
- Save bill to `bills` immediately
- Save credit entry to `ledger` immediately
- Do not show it in customer Borrow on the same day

End-of-day behavior:
- If paid the same day in Daily Ledger: it does not appear in customer Borrow
- If not paid: it appears in customer Borrow from the next day

The same rule applies to manual credit entries added in Daily Ledger.

## Prerequisites

- Flutter SDK installed (`flutter --version`)
- Dart SDK (comes with Flutter)
- Firebase project configured
- Android Studio or VS Code (recommended)

## Setup

1. Clone repo
   - `git clone <your-repo-url>`
   - `cd smart_kirana_app`
2. Install dependencies
   - `flutter pub get`
3. Firebase setup
   - Ensure `lib/firebase_options.dart` is present and valid
   - Ensure platform config files exist:
     - `android/app/google-services.json`
     - iOS/macOS config as needed
4. Run app
   - `flutter run`

## Development Commands

- Analyze:
  - `flutter analyze`
- Run tests:
  - `flutter test`
- Build debug APK:
  - `flutter build apk --debug`

## Project Structure

```text
lib/
  main.dart
  billing_screen.dart
  ledger_screen.dart
  customer_screen.dart
  customer_report_screen.dart
  customer_history_screen.dart
  bill_detail_screen.dart
  firebase_options.dart
```

## Notes

- This repo may generate local build artifacts (`build/`, `.dart_tool/`, Gradle files). These should typically not be committed.
- Firestore security rules should be configured before production use.
- Add indexes in Firestore if query performance warnings appear.
