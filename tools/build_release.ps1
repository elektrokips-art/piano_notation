# Сборка релиза Piano Notation: APK (для RuStore) и AAB (для Google Play).
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_release.ps1 [-OutDir <папка>]
# Подпись берётся из android\key.properties (см. docs\PUBLISHING.md).
param(
    [string]$OutDir = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Piano\build')
)
$ErrorActionPreference = 'Stop'
$proj = Split-Path -Parent $PSScriptRoot
Set-Location $proj

# Если TEMP записан в «коротком» виде (C:\Users\HPPC~1\...), Java не может создать
# внутренний сокет и Gradle падает с "Unable to establish loopback connection".
if ($env:TEMP -match '~') {
    $short = Join-Path ($proj.Substring(0, 3)) 't'
    New-Item -ItemType Directory -Force $short | Out-Null
    $env:TEMP = $short; $env:TMP = $short
    Write-Host "TEMP заменён на $short (обход проблемы с короткими путями)"
}

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

# Проверка подписи APK через apksigner (современные APK подписаны схемой v2/v3,
# jarsigner их не видит). Нужно убедиться, что это наш ключ, а не debug-ключ.
$sdk = $env:ANDROID_HOME
if (-not $sdk -and (Test-Path 'android\local.properties')) {
    $m = Select-String -Path 'android\local.properties' -Pattern '^sdk.dir=(.+)$'
    if ($m) { $sdk = $m.Matches[0].Groups[1].Value -replace '\\\\', '\' -replace '\\:', ':' }
}
$apksigner = $null
if ($sdk -and (Test-Path (Join-Path $sdk 'build-tools'))) {
    $apksigner = Get-ChildItem (Join-Path $sdk 'build-tools') -Recurse -Filter 'apksigner.bat' |
        Sort-Object FullName -Descending | Select-Object -First 1
}
if (-not $apksigner) {
    Write-Warning 'apksigner не найден — подпись APK не проверена. Проверьте вручную.'
} else {
    $info = & $apksigner.FullName verify --print-certs $apk 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Подпись APK не прошла проверку:`n$info" }
    if ($info -match 'Android Debug') { throw 'APK подписан DEBUG-ключом — проверьте android\key.properties!' }
    $dn = ($info -split "`n" | Select-String 'certificate DN:' | Select-Object -First 1).Line.Trim()
    Write-Host "Подпись APK проверена (apksigner): $dn"
}

Write-Host ''
Write-Host "Готово: $apk"
Write-Host "Готово: $aab"
