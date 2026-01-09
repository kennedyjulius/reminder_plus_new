class ApiKeys {
  // Keys provided by client; replace with secure storage in production.
  static const String calendarific = 'i9BAKsjbhoLgblLJTNyIzzVi8NSsoJKt';
  // NOTE: This Finnhub key was provided for development use.
  // In production, NEVER commit API keys to source control; use secure storage or env vars.
  static const String finnhub = 'd4rjqbpr01qgts2oid80d4rjqbpr01qgts2oid8g';
  
  // Microsoft OAuth Client ID for Outlook/Microsoft Graph API
  // To get your client ID:
  // 1. Go to https://portal.azure.com/
  // 2. Navigate to "Azure Active Directory" > "App registrations"
  // 3. Create a new app registration or select existing one
  // 4. Copy the "Application (client) ID"
  // 5. Configure redirect URI: com.reminder.reminderplus://auth
  // 6. Add API permissions: Mail.Read, User.Read
  static const String microsoftClientId = 'c1704611-f589-43e4-9ebc-c3f301fc1bc3'; // Replace with your Azure App Client ID
}

