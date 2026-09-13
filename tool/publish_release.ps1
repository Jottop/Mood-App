# Publica una versión de "Tu día" en el hub:
#   1) compila el APK universal de release (todas las ABIs)
#   2) calcula su SHA-256
#   3) sube el versionCode + manifest.json (fuente del hub y del chequeo in-app)
#   4) commit + push de pubspec.yaml y docs/manifest.json
#   5) crea el GitHub Release con el APK como asset
#
# Uso (PowerShell, desde la raíz del repo):
#   ./tool/publish_release.ps1 -Version 0.2.0 -Build 2 `
#     -Notes "Burbuja del widget: aura mas gruesa", "Detalle por dia: swipe sin freezes"
#
# Requiere: flutter, gh autenticado, y env.json con SUPABASE_URL/KEY (o pasarlos por parámetro).
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][int]$Build,
  [string[]]$Notes = @(),
  [string]$SupabaseUrl,
  [string]$SupabaseKey
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)

# -- 0) Pre-checks -----------------------------------------------------------
git diff --quiet; if (-not $?) {
  throw "Hay cambios sin commitear. Publiquese desde un arbol limpio."
}
$branch = git branch --show-current
if ($branch -ne "main") { throw "Se publica desde main (estas en $branch)." }

$envJson = $null
if (Test-Path -LiteralPath "env.json") {
  $envJson = Get-Content -LiteralPath "env.json" -Raw | ConvertFrom-Json
}
if (-not $SupabaseUrl) { $SupabaseUrl = $envJson.SUPABASE_URL }
if (-not $SupabaseKey) { $SupabaseKey = $envJson.SUPABASE_PUBLISHABLE_KEY }
if (-not $SupabaseUrl -or -not $SupabaseKey) {
  throw "Faltan SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY (env.json o parametros)."
}

# -- 1) versiones + build ----------------------------------------------------
$pubspec = Get-Content -LiteralPath "pubspec.yaml" -Raw
$pubspec = $pubspec -replace "(?m)^version:\s*\S+\s*$", "version: ${Version}+${Build}"
Set-Content -LiteralPath "pubspec.yaml" -Value $pubspec -NoNewline -Encoding UTF8

flutter build apk --release `
  --dart-define=SUPABASE_URL=$SupabaseUrl `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$SupabaseKey

$apk = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path -LiteralPath $apk)) { throw "No se genero el APK universal." }

$sha = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
$size = (Get-Item -LiteralPath $apk).Length
$date = Get-Date -Format "yyyy-MM-dd"

# -- 2) manifest -------------------------------------------------------------
$manifest = [ordered]@{
  versionName = $Version
  versionCode = $Build
  releaseDate = $date
  notes       = @($Notes)
  sizeBytes   = $size
  sha256      = $sha
  apkUrl      = "https://github.com/Jottop/Mood-App/releases/download/v$Version/app-release.apk"
}
$manifestJson = $manifest | ConvertTo-Json -Depth 4
Set-Content -LiteralPath "docs\manifest.json" -Value $manifestJson -NoNewline -Encoding UTF8

# -- 3) commit + push --------------------------------------------------------
$notesText = ($Notes -join "`n`n").Trim()
git add pubspec.yaml docs/manifest.json
git commit -m "Release v${Version}: hub de descargas actualizado para el APK universal"
git push

# -- 4) GitHub Release -------------------------------------------------------
gh release create "v$Version" $apk --title "Tu día v$Version" --notes $notesText

Write-Host ""
Write-Host "OK publicada v$Version (versionCode $Build)." -ForegroundColor Green
Write-Host "  Hub:     https://jottop.github.io/Mood-App/"
Write-Host "  Manifiesto: https://jottop.github.io/Mood-App/manifest.json"
Write-Host "  Descarga:  $($manifest.apkUrl)"
Write-Host "  SHA-256:   $sha"