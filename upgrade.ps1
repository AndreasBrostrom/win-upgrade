# Check parameters

$programName = "$([io.path]::GetFileNameWithoutExtension("$($MyInvocation.MyCommand.Name)"))"

$help           = $false
$noWindows      = $false
$suMode         = $false
$version        = $false
foreach ($arg in $args) {
    if ($arg -in @("--help", "-h")) {
        $help = $TRUE
        continue
    } elseif ($arg -in @("-noWindowsUpdate", "-w")) {
        $noWindows = $TRUE
        continue
    } elseif ($arg -in @("--suMode", "-su")) {
        $suMode = $TRUE
        continue
    } elseif ($arg -in @("--version", "--v")) {
        $version = $TRUE
        continue
    } else{
        Write-Host "${programName}: '$arg' unknown argument" -ForegroundColor Red
        exit 1
    }

}



if ($help) {
    Write-Host  "Usage: ${programName} [-w] [-su] [-v] [-help]"
    Write-Host  ""
    Write-Host  "    -h, --help                Show this help"
    Write-Host  "    -w, --noWindowsUpdate     Disable update check for windows"
    Write-Host  "    -su, --suMode             Disable suMode and require sudo password on a user level for wsl update. This may lead to required confirms."
    Write-Host  "    -v, --version             Show current version"
    exit 0
}

$BUILD = "DEV"
if ( $Version ) {
    Write-Host "Version: $BUILD"
    exit 0
}

$IS_ADMIN = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")

# Check for package managers
Write-Host "Looking for Package Managers and WSL..."
if ([bool](Test-Path "$env:WINDIR\system32\wsl.exe" -PathType Leaf)) {
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
if (!$IS_ADMIN) {
    Write-Host "${programName} is not running as Administrator. Start PowerShell by using the Run as Administrator option" -ForegroundColor Red -NoNewline
    
    # check if have sudo programs installed
        $sudoScripts =  "$env:USERPROFILE\scoop\shims\sudo",
                        "$env:USERPROFILE\scoop\shims\sudo.ps1",
                        "$env:PROGRAMDATA\scoop\shims\sudo",
                        "$env:PROGRAMDATA\scoop\shims\sudo.ps1",
                        "$env:PROGRAMDATA\chocolatey\bin\Sudo.exe",
                        "$env:USERPROFILE\.bin\sudo.ps1",
                        "$env:SCOOP_GLOBAL\shims\sudo",
                        "$env:SCOOP_GLOBAL\shims\sudo.ps1"

    foreach ($sudoScript in $sudoScripts) { if ( [System.IO.File]::Exists("$sudoScript") ) { [bool] $hasSudo = 1; break } }
    if ($hasSudo) { Write-Host " or run with sudo" -ForegroundColor Red -NoNewline }
    
    Write-Host ", and then running the script again." -ForegroundColor Red

    if ([bool](Test-Path "$env:USERPROFILE\scoop\shims\scoop" -PathType Leaf)) {
        Write-Host "Due to scoop being installed we will update its local packages...`n" -ForegroundColor Yellow
    } else {
        exit 1
    }
}

# Functions
function runWSLUpdate {

    Write-Host "Updating WSL distros..." -ForegroundColor Blue
    if (-not $suMode) {
        Write-Host "This will update using the root user.`nTo update using your distrobution user run $programName with the argument --suMode" -ForegroundColor DarkGray
    }
    
    $distrosList = @()
    wsl.exe --list | ForEach-Object -Process {
        if ($_ -eq "") {return}
        if ($_ -eq "Windows Subsystem for Linux Distributions:") {return}
        $dist = -split "$_"
        $distName = $dist[0]
        $DistrosList += $distName
    }
    if ($distrosList.count -eq 0) {
        Write-Host "No WSL distrobutions detected skipping...`n" -ForegroundColor Red
        return
    }

    Write-Host "`nUpdating folloing distros:"
    foreach ($dist in $DistrosList) { Write-Host " - $dist" }
    
    foreach ($dist in $DistrosList) {
        # Variable $dist apparently does not work for Start-Process argumentList collected earlier or in the loop it self eather
        Write-Host "`nUpdating $dist..."
        if ($dist.ToLower() -eq "arch") {
            if (-not $suMode) {
                $distPackageManagers = "eval 'yes `"`" | pacman -Syyuu'"
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution arch", "--user root", "-- $distPackageManagers"
            } else {
                $distPackageManagers = "eval 'yay -Syyu --sudoloop --noconfirm --color=always'"
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution arch", "-- $distPackageManagers"
            }
            continue
        }
        if ($dist.ToLower() -eq "debian") { 
            if (-not $suMode) {
                $distPackageManagers = "eval 'yes "" | apt update && apt full-upgrade -y && apt autoremove -y'"
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution debian", "--user root", "-- $distPackageManagers" 
            } else {
                $distPackageManagers = "eval 'sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y'"
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution debian", "-- $distPackageManagers" 
            }
            continue
        }
        if ($dist.ToLower() -eq "ubuntu") {
            if (-not $suMode) {
                $distPackageManagers = "eval 'apt update && apt full-upgrade -y && apt autoremove -y'"
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution ubuntu", "--user root", "-- $distPackageManagers" 
            } else {
                $distPackageManagers = "eval 'sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y'"
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution ubuntu", "-- $distPackageManagers" 
            }
            continue
        }
    }
    Write-Host "`nWindows Subsystem for Linux update compleat...`n" -ForegroundColor Green
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

    if ($IS_ADMIN) {
        Write-Host "Updating globla packages..."
        scoop update * --global
    }

    Write-Host "Scoop update compleat...`n" -ForegroundColor Green
}
function runChocolateyUpdate {
    Write-Host "Updating Choco packages..." -ForegroundColor Blue

    choco upgrade all -y

    Write-Host "Chocolatey update compleat...`n" -ForegroundColor Green
}
function runWinGetUpdate {
    Write-Host "Updating WinGet packages..." -ForegroundColor Blue

    winget upgrade --include-unknown --silent --all

    Write-Host "WinGet update compleat...`n" -ForegroundColor Green
}
function RemoveShortcut-Item($ShortcutName) {
    Remove-Item -Path "$env:USERPROFILE\Desktop\$ShortcutName" >$null 2>&1
    Remove-Item -Path "C:\Users\Default\Desktop\$ShortcutName" >$null 2>&1
    Remove-Item -Path "C:\Users\Public\Desktop\$ShortcutName" >$null 2>&1
}

# Run programs if they exist
if ( $IS_ADMIN -And $HAS_WLS ) { runWSLUpdate }
if ( $IS_ADMIN -And -Not $noWindows -And $HAS_PSWindowsUpdate ) {
    if ( -Not [BOOL](Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "DoNotConnectToWindowsUpdateInternetLocations" ) ) {
        Write-Host "Checking for windows updates..." -ForegroundColor Blue
        runWindowsUpdate
    } else {
        Write-Host "Windows update is currently disabled in regestry skipping...`n" -ForegroundColor Yellow
    }
}
if ( $HAS_Scoop ) { runScoopUpdate }
if ( $IS_ADMIN -And $HAS_Chocolatey ) {
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
if ( $IS_ADMIN -And  $HAS_winget ) {
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