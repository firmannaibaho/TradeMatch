# Supabase Edge Functions Deployment Guide

## Prerequisites

1. **Node.js** (v18+) - You likely have this already
2. **Supabase CLI** - We'll install this
3. **Supabase Account** - Create at [supabase.com](https://supabase.com)

---

## Step 1: Install Supabase CLI

Open PowerShell and run:

```powershell
# Option A: Using npm (recommended if you have Node.js)
npm install -g supabase

# Option B: Using Scoop (Windows package manager)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

Verify installation:
```powershell
supabase --version
```

---

## Step 2: Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in
2. Click "New Project"
3. Choose organization, name it "BarterSwap"
4. Set a strong database password (save it!)
5. Choose region closest to you (e.g., Singapore for Indonesia)
6. Click "Create new project"
7. Wait ~2 minutes for setup

---

## Step 3: Link Your Local Project

```powershell
# Navigate to your project
cd "d:\College\Semester 5\Pemrograman Mobile\TradeMatch"

# Login to Supabase (opens browser)
supabase login

# Link to your project (get project ref from dashboard URL)
# Dashboard URL looks like: https://supabase.com/dashboard/project/abcdefghijk
# The "abcdefghijk" part is your project ref
supabase link --project-ref YOUR_PROJECT_REF
```

When prompted for database password, enter the one you set during project creation.

---

## Step 4: Run the Database Migration

```powershell
# Push the schema to your Supabase database
supabase db push
```

Or manually in Supabase Dashboard:
1. Go to SQL Editor
2. Copy contents of `supabase/migrations/001_initial_schema.sql`
3. Paste and click "Run"

---

## Step 5: Deploy Edge Functions

```powershell
# Deploy all functions at once
supabase functions deploy process-swipe
supabase functions deploy get-explore-feed
supabase functions deploy confirm-trade
supabase functions deploy suggest-location
supabase functions deploy accept-location
supabase functions deploy create-review
```

Or deploy all with a single command:
```powershell
# Deploy all functions in the functions directory
supabase functions deploy
```

---

## Step 6: Get Your Project Credentials

Go to Supabase Dashboard → Project Settings → API

You'll need:
- **Project URL**: `https://YOUR_PROJECT_REF.supabase.co`
- **Anon Key**: Public key for client-side use
- **Service Role Key**: Secret key (only for server-side, never in Flutter!)

---

## Step 7: Configure Flutter

Add to `pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.3.0
```

Run:
```powershell
cd Flutter
flutter pub get
```

Update `main.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT_REF.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );
  
  runApp(const MyApp());
}
```

---

## Step 8: Configure Google OAuth (Optional)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create OAuth 2.0 credentials (Web Application type)
3. Add authorized redirect URI: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
4. In Supabase Dashboard → Authentication → Providers → Google
5. Enable and paste Client ID and Secret

---

## Quick Reference Commands

```powershell
# Check function logs
supabase functions logs process-swipe

# Test a function locally
supabase functions serve process-swipe

# View all deployed functions
supabase functions list

# Delete a function
supabase functions delete function-name
```

---

## Troubleshooting

**"supabase: command not found"**
→ Close and reopen PowerShell after installing

**"Project not linked"**
→ Run `supabase link --project-ref YOUR_PROJECT_REF`

**"Function deployment failed"**
→ Check for TypeScript errors in the function code

**"Database password incorrect"**
→ Reset in Dashboard → Project Settings → Database → Reset Password
