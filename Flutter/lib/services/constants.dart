// Centralized constants for local development
// Replace the placeholders below with your development values.

/// Example: http://192.168.1.100:8000
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000',
);

/// After login, set this to the token returned from the backend
/// (or wire it to your auth service). Keep empty for anonymous requests.
String AUTH_TOKEN = 'REPLACE_WITH_TOKEN';

/// Current authenticated user id as string (used by chat UI placeholders)
String AUTH_USER_ID = 'REPLACE_WITH_USER_ID';

// Google Web Client ID (from Google Cloud Console > Credentials > Web application)
const String GOOGLE_CLIENT_ID = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue:
      '915200574896-1lfrh6hosfvi5l8ds74c457dfeg88kpe.apps.googleusercontent.com',
);

// Supabase Configuration
const String SUPABASE_URL = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://trlzvzkmuklhnkxaqhsv.supabase.co',
);
const String SUPABASE_ANON_KEY = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: _SUPABASE_ANON_KEY_DEFAULT,
);
const String _SUPABASE_ANON_KEY_DEFAULT =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRybHp2emttdWtsaG5reGFxaHN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMDgzMjgsImV4cCI6MjEwODU4NDMyOH0.8wTXf-p8buEbrwTzt0um-rVWLKhAZeqt6Nti3UKPCzM';
