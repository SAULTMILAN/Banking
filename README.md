# Flutter Simple Banking

A minimal Flutter app that meets the assignment requirements:

- **Welcome screen** with bank logo (icon), welcome message, and today's date.
- **Navigate** from Welcome → Account List → Transactions.
- **Accounts list** uses local JSON assets to display accounts.
- Exactly **one "View Transactions"** button on the Accounts screen which becomes enabled when you select an account.
- **Transactions** screen displays only the transactions for the selected account using the same JSON data.
- **Back navigation** allowed only from Transactions → Accounts and from Accounts → Welcome (standard back button).

## Run locally

```bash
flutter pub get
flutter run
```

## JSON assets (already included)

- `assets/accounts.json`
- `assets/transactions.json`

## Notes

- Assets are declared in `pubspec.yaml`.
- Data is loaded with `rootBundle.loadString` and parsed with `dart:convert`.
