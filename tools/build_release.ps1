# Сборка релиза Piano Notation: APK (для RuStore) и AAB (для Google Play).
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_release.ps1 [-OutDir <папка>]
# Подпись берётся из android\key.properties (см. docs\PUBLISHING.md).
param(
    [string]$OutDir = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Piano\build')
)
$ErrorActionPreference = 'Stop'
$proj = Split-Path -Parent $PSScriptRoot
Set-Location $proj

if (-not (Test-Path 'android\key.properties')) {
    throw 'Нет android\key.properties — без него релиз подпишется debug-ключом, магазины его не примут.'
}
$version = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
Write-Host "Версия: $version"

flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze нашёл замечания — сначала исправьте.' }

flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Сборка APK не удалась.' }
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) { throw 'Сборка AAB не удалась.' }

New-Item -ItemType Directory -Force $OutDir | Out-Null
$name = "PianoNotation-$($version.Replace('+','-b'))"
$apk = Join-Path $OutDir "$name.apk"
$aab = Join-Path $OutDir "$name.aab"
Copy-Item 'build\app\outputs\flutter-apk\app-release.apk' $apk -Force
Copy-Item 'build\app\outputs\bundle\release\app-release.aab' $aab -Force

# Проверка, что файл подписан нашим ключом, а не debug-ключом.
$jarsigner = 'C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe'
if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\jarsigner.exe'))) {
    $jarsigner = Join-Path $env:JAVA_HOME 'bin\jarsigner.exe'
}
if (Test-Path $jarsigner) {
    $info = & $jarsigner -verify -verbose -certs $apk 2>&1 | Out-String
    if ($info -match 'Android Debug') { throw 'APK подписан DEBUG-ключом — проверьте android\key.properties!' }
    Write-Host 'Подпись APK: не debug-ключ — ок.'
}

Write-Host ''
Write-Host "Готово: $apk"
Write-Host "Готово: $aab"
