# Builds the website and publishes it to Firebase Hosting.
#
# One-time setup (needs YOUR Google account, so run it yourself):
#   firebase login
#   (put your project id in .firebaserc, or run: firebase use --add)
#
# Then, from the project folder:
#   powershell -ExecutionPolicy Bypass -File tool\publish_web.ps1
#
# The QR code on the landing page uses the published address automatically.

$ErrorActionPreference = 'Stop'
$env:Path = "C:\src\flutter\bin;" + $env:Path

if (-not (Test-Path .firebaserc)) {
  Write-Error 'Missing .firebaserc. Run: firebase use --add   (choose your project)'
}

Write-Host 'Checking the code first...'
flutter analyze
flutter test

Write-Host 'Building the website...'
cmd /c "rmdir /s /q build" 2>$null
flutter build web --release

Write-Host 'Publishing...'
firebase deploy --only hosting
