# Check parameters
param (
    [Parameter(Mandatory=$false)][Switch]$help,
    [Parameter(Mandatory=$false)][Switch]$Windows,
    [Parameter(Mandatory=$false)][Switch]$Version
)
if ($help) {
    Write-Host  "Usage: $((Get-Item $PSCommandPath).Basename) [-w] [-l] [-s] [-c] [-v] [-help]"
    Write-Host  ""
    Write-Host  "    -h, -help          Show this help"
    Write-Host  "    -w, -windows       Disable update check for windows"
    Write-Host  "    -v, -version       Show current version"
    exit 0
}

$BUILD = "DEV"
if ( $Version ) {
    Write-Host "Version: $BUILD"
    exit 0
}

# Check for package managers
Write-Host "Looking for Package Managers and WSL..."
if ([bool](Test-Path "$env:WINDIR\system32\bash.exe" -PathType Leaf)) {
    Write-Host " - Detected Windows Subsystem for Linux (WSL)"
    $HAS_WLS=$TRUE
}
if ([bool](Get-Command -module PSWindowsUpdate)) {
    Write-Host " - Detected PSWindowsUpdate Powershell Moduel"
    $HAS_PSWindowsUpdate=$TRUE
}
if ([bool](Test-Path "$env:USERPROFILE\scoop\shims\scoop" -PathType Leaf)) { 
    Write-Host " - Detected Scoop"
    $HAS_Scoop=$TRUE
}
if ([bool](Test-Path "$env:ChocolateyInstall\choco.exe" -PathType Leaf)) {
    Write-Host " - Detected Chocolatey"
    $HAS_Chocolatey=$TRUE
}
if ([bool](Test-Path "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\winget.exe" -PathType Leaf)) {
    Write-Host " - Detected WinGet (Windows Package Manager)"
    $HAS_winget=$TRUE
}
Write-Host ""

# Check if Admin else exit
if ( ![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
    Write-Host "$([io.path]::GetFileNameWithoutExtension("$($MyInvocation.MyCommand.Name)")) is not running as Administrator. Start PowerShell by using the Run as Administrator option" -ForegroundColor Red -NoNewline
    
    # check if have sudo programs installed
    $sudoScripts =  "$env:USERPROFILE\scoop\shims\sudo",
                    "$env:USERPROFILE\scoop\shims\sudo.ps1",
                    "$env:PROGRAMDATA\scoop\shims\sudo",
                    "$env:PROGRAMDATA\scoop\shims\sudo.ps1",
                    "$env:PROGRAMDATA\chocolatey\bin\Sudo.exe",
                    "$env:USERPROFILE\.bin\sudo.ps1"

    foreach ($sudoScript in $sudoScripts) { if ( [System.IO.File]::Exists("$sudoScript") ) { [bool] $hasSudo = 1; break } }
    if ($hasSudo) { Write-Host " or run with sudo" -ForegroundColor Red -NoNewline }
    
    Write-Host ", and then try running the script again." -ForegroundColor Red

    exit 1
}

# Functions
function runWSLUpdate {

    Write-Host "Updating your WSL system..." -ForegroundColor Blue
    
    #bash.exe -c "sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y";
    Write-Host "Rewriting system WSL update will be back soon...`n" -ForegroundColor DarkGray
    
    Write-Host "Windows Subsystem for Linux update compleat...`n" -ForegroundColor Green
}
function runWindowsUpdate {
    Write-Host "This can take some time stand by..." -ForegroundColor DarkGray

    Write-Host "Checking for updates..."
    Get-WindowsUpdate
    Write-Host "Installing updates..."
    Install-WindowsUpdate -AcceptAll -IgnoreReboot -Install >$null 2>&1

    Write-Host "Windows update compleat...`n" -ForegroundColor Green
}
function runScoopUpdate {
    Write-Host "Updating Scoop repositories..."
    scoop update

    Write-Host "Updating local packages..."
    scoop update *

    Write-Host "Updating globla packages..."
    scoop update * --global

    Write-Host "Scoop update compleat...`n" -ForegroundColor Green
}
function runChocolateyUpdate {
    Write-Host "Updating Choco packages..." -ForegroundColor Blue

    choco upgrade all -y

    Write-Host "Chocolatey update compleat...`n" -ForegroundColor Green
}
function runWinGetUpdate {
    Write-Host "Updating WinGet packages..." -ForegroundColor Blue

    winget upgrade --accept-package-agreements --accept-source-agreements --all

    Write-Host "WinGet update compleat...`n" -ForegroundColor Green
}
function RemoveShortcut-Item($ShortcutName) {
    Remove-Item -Path "$env:USERPROFILE\Desktop\$ShortcutName" >$null 2>&1
    Remove-Item -Path "C:\Users\Default\Desktop\$ShortcutName" >$null 2>&1
    Remove-Item -Path "C:\Users\Public\Desktop\$ShortcutName" >$null 2>&1
}

# Run programs if they exist
if ( $HAS_WLS ) { runWSLUpdate }
if ( -Not $Windows -And $HAS_PSWindowsUpdate ) {
    if ( -Not [BOOL](Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "DoNotConnectToWindowsUpdateInternetLocations" ) ) {
        Write-Host "Checking for windows updates..." -ForegroundColor Blue
        runWindowsUpdate
    } else {
        Write-Host "Windows update is currently disabled in regestry skipping...`n" -ForegroundColor Yellow
    }
}
if ( $HAS_Scoop ) { runScoopUpdate }
if ( $HAS_Chocolatey ) {
    # Get links on desktop befor installation
    $Desktops =    "$env:USERPROFILE\Desktop\$ShortcutName",
                    "C:\Users\Default\Desktop\$ShortcutName",
                    "C:\Users\Public\Desktop\$ShortcutName" 
    $preDesktop = @()
    foreach ($Desktop in $Desktops) {
        $items = Get-ChildItem -Path $Desktop -Name -Include "*.lnk"
        foreach ($item in $items) {
            $preDesktop += $item
        }
    }

    # Update choco
    runChocolateyUpdate

    # Cleaning up new unwhanted desktop icons
    Write-Host "Cleaning up Chocolatey created desktop icons...`n"
    $newDesktopLinks = @()
    foreach ($Desktop in $Desktops) {
        $items = Get-ChildItem -Path $Desktop -Name -Include "*.lnk"
        foreach ($item in $items) {
            if ($preDesktop -contains $item ) {
            } else {
                $newDesktopLinks += $item
            }
        }
    }
    foreach ($item in $newDesktopLinks) {
        RemoveShortcut-Item $item
        Write-Host "Cleaned up $item" -ForegroundColor DarkGray
    }
}
if ( $HAS_winget ) {
    # Get links on desktop befor installation
    $Desktops =    "$env:USERPROFILE\Desktop\$ShortcutName",
                    "C:\Users\Default\Desktop\$ShortcutName",
                    "C:\Users\Public\Desktop\$ShortcutName" 
    $preDesktop = @()
    foreach ($Desktop in $Desktops) {
        $items = Get-ChildItem -Path $Desktop -Name -Include "*.lnk"
        foreach ($item in $items) {
            $preDesktop += $item
        }
    }

    # Update WinGet
    runWinGetUpdate 

    # Cleaning up new unwhanted desktop icons
    Write-Host "Cleaning up WinGet created desktop icons...`n"
    $newDesktopLinks = @()
    foreach ($Desktop in $Desktops) {
        $items = Get-ChildItem -Path $Desktop -Name -Include "*.lnk"
        foreach ($item in $items) {
            if ($preDesktop -contains $item ) {
            } else {
                $newDesktopLinks += $item
            }
        }
    }
    foreach ($item in $newDesktopLinks) {
        RemoveShortcut-Item $item
        Write-Host "Cleaned up $item" -ForegroundColor DarkGray
    }
}

Write-Host "All updates is completed." -ForegroundColor Green
exit 0