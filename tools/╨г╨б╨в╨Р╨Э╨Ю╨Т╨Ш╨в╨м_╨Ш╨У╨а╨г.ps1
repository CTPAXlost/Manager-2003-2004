$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$installDir = Join-Path $env:LOCALAPPDATA 'Футбольный менеджер 2003'
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$exeName = 'Football_Manager_2003.exe'
$sourceExe = Join-Path $source $exeName

if (-not (Test-Path $sourceExe)) {
    Write-Host 'Не найден Football_Manager_2003.exe. Запустите установщик из распакованной Windows-сборки.' -ForegroundColor Red
    Read-Host 'Нажмите Enter'
    exit 1
}

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Get-ChildItem -LiteralPath $source -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $installDir $_.Name) -Force
}

$installedExe = Join-Path $installDir $exeName
$wsh = New-Object -ComObject WScript.Shell
foreach ($shortcutPath in @(
    (Join-Path $desktop 'Футбольный менеджер 2003.lnk'),
    (Join-Path $startMenu 'Футбольный менеджер 2003.lnk')
)) {
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $installedExe
    $shortcut.WorkingDirectory = $installDir
    $shortcut.Description = 'Футбольный менеджер сезона 2003/04'
    $shortcut.Save()
}

Write-Host ''
Write-Host 'Игра установлена:' -ForegroundColor Green
Write-Host $installDir
Write-Host 'Ярлыки созданы на рабочем столе и в меню Пуск.'
Write-Host ''
Write-Host 'Важно: ускорение вкладок обеспечено внутренними индексами и кэшем v1.1.0. Установка нужна для удобного запуска, а не для увеличения потребления ресурсов.' -ForegroundColor Cyan
Read-Host 'Нажмите Enter'
