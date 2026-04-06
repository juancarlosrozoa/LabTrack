class AppConstants {
  AppConstants._();

  // Stock alert thresholds (days before expiration)
  static const int expiryAlertDays30 = 30;
  static const int expiryAlertDays60 = 60;
  static const int expiryAlertDays90 = 90;

  // Inventory count
  static const String weeklyCountDay = 'Monday';

  // API
  static const String apiBasePath = '/api';

  // Google Sheets sheet names
  static const String sheetStock = 'Stock';
  static const String sheetExpiringSoon = 'Expiring Soon';
  static const String sheetMovements = 'Movements';
  static const String sheetRestockNeeded = 'Restock Needed';
}
