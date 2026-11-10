param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectUrl,

  [Parameter(Mandatory = $true)]
  [string]$AnonKey,

  [Parameter(Mandatory = $true)]
  [string]$AccessToken
)

$ErrorActionPreference = 'Stop'

# Extract project ref from https://<ref>.supabase.co
if ($ProjectUrl -match 'https?://([a-z0-9-]+)\.supabase\.co') {
  $ProjectRef = $Matches[1]
} else {
  throw "Invalid ProjectUrl '$ProjectUrl'. Expected https://<project-ref>.supabase.co"
}

Write-Host "==> Project Ref: $ProjectRef" -ForegroundColor Cyan

# 1. Update Flutter/lib/services/constants.dart
$constantsPath = Join-Path $PSScriptRoot '..\Flutter\lib\services\constants.dart'
$constantsContent = Get-Content $constantsPath -Raw
$constantsContent = [regex]::Replace(
  $constantsContent,
  "const String SUPABASE_URL = '[^']*';",
  "const String SUPABASE_URL = '$($ProjectUrl.TrimEnd('/'))';"
)
$constantsContent = [regex]::Replace(
  $constantsContent,
  "const String SUPABASE_ANON_KEY =\s*'[^']*';",
  "const String SUPABASE_ANON_KEY =`n    '$AnonKey';"
)
Set-Content -Path $constantsPath -Value $constantsContent -Encoding UTF8
Write-Host "==> Updated Flutter/lib/services/constants.dart" -ForegroundColor Green

# 2. Apply SQL migrations via Supabase Management API
$headers = @{
  Authorization  = "Bearer $AccessToken"
  'Content-Type' = 'application/json'
}

$migrationsDir = Join-Path $PSScriptRoot 'migrations'
$migrationFiles = Get-ChildItem $migrationsDir -Filter '*.sql' | Sort-Object Name

foreach ($file in $migrationFiles) {
  Write-Host "==> Applying migration $($file.Name)..." -ForegroundColor Cyan
  [string]$sql = [System.IO.File]::ReadAllText($file.FullName)
  $body = @{ query = $sql } | ConvertTo-Json -Compress
  $resp = Invoke-RestMethod `
    -Method Post `
    -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/query" `
    -Headers $headers `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
  Write-Host "    OK: $($file.Name)" -ForegroundColor Green
}

# 3. Deploy Edge Functions via npx supabase
$env:SUPABASE_ACCESS_TOKEN = $AccessToken
$functions = @(
  'process-swipe',
  'get-explore-feed',
  'confirm-trade',
  'suggest-location',
  'accept-location',
  'create-review'
)

Push-Location (Join-Path $PSScriptRoot '..')
try {
  npx --yes supabase functions deploy $functions --project-ref $ProjectRef --no-verify-jwt
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to deploy edge functions"
  }
} finally {
  Pop-Location
}

Write-Host "==> All migrations and edge functions deployed successfully!" -ForegroundColor Green
