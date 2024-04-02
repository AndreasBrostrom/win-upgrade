# Check parameters

$programName = "$([io.path]::GetFileNameWithoutExtension("$($MyInvocation.MyCommand.Name)"))"

$help           = $false
$noWindows      = $false
$suMode         = $false
$updateWSL      = $false
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
    } elseif ($arg -in @("--updateWSL")) {
        $updateWSL = $TRUE
        continue
    } elseif ($arg -in @("--version", "-v")) {
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
    Write-Host
    Write-Host  "    --updateWSL               Upgrade WSL client"
    Write-Host
    Write-Host  "    -v, --version             Show current version"
    exit 0
}

$BUILD = "GIT"
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
function RemoveShortcut-Item($ShortcutName) {
    Remove-Item -Path "$env:USERPROFILE\Desktop\$ShortcutName" >$null 2>&1
    Remove-Item -Path "C:\Users\Default\Desktop\$ShortcutName" >$null 2>&1
    Remove-Item -Path "C:\Users\Public\Desktop\$ShortcutName" >$null 2>&1
}
function Test-PendingReboot {
    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction Ignore) { return $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction Ignore) { return $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction Ignore) { return $true }
    try {
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if (($status -ne $null) -and $status.RebootPending) {
            return $true
        }
    } catch { return $false };
    return $false
}

# Upgrade functions
function runWSLUpdate {

    if ($updateWSL) {
        Write-Host "Updating WSL client..." -ForegroundColor Blue
        wsl --update
        Write-Host
    }

    Write-Host "Updating WSL distros..." -ForegroundColor Blue
    if (-not $suMode) {
        Write-Host "This will update using the root user.`nTo update using your distrobution user run $programName with the argument --suMode" -ForegroundColor DarkGray
    }
    
    $distrosList = @()
    Try {
        $i=0
        wsl.exe --list | ForEach-Object -Process {
            $i++
            if ($i -lt 2) {return}
            if ($_ -eq "") {return}
            $dist = -split "$_"
            $distName = $dist[0]
            $DistrosList += $distName
        }
    }
    Catch {
        Write-Host "WSL not supported via remote connections...`nSee https://github.com/microsoft/WSL/issues/7900`n" -ForegroundColor Red
        return
    }
    if ($distrosList.count -eq 0) {
        Write-Host "No WSL distrobutions detected skipping...`n" -ForegroundColor Red
        return
    }

    Write-Host "`nUpdating following distros:"
    foreach ($dist in $DistrosList) { Write-Host " - $dist" }
    
    foreach ($dist in $DistrosList) {
        # Variable $dist apparently does not work for Start-Process argumentList collected earlier or in the loop it self eather
        if ($dist.ToLower() -eq "arch") {
            Write-Host "`nUpdating $dist..." -ForegroundColor DarkCyan
            if (-not $suMode) {
                $distPackageManagers = (
                    "eval '" +
                    "if [[ which paru 1>/dev/null 2>&1 ]]; then" +
                    "  echo -e `'\033[1;32mparu\033[0m`';" +
                    "  yes `"`" | paru -Syyu --sudoloop --noconfirm --color=always;" +
                    "  exit $?;"
                    "fi;" +
                    "echo -e `"\033[1;32mpacman\033[0m`" && yes `"`" | pacman -Syyuu;" +
                    "'"
                )
                echo $distPackageManagers
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution arch", "--user root", "-- $distPackageManagers"
            } else {
                $distPackageManagers = (
                    "eval '" +
                    "echo -e `'\033[1;32mparu\033[0m`' && yes `"`" | paru -Syyu --sudoloop --noconfirm --color=always" +
                    "'"
                )
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution arch", "-- $distPackageManagers"
            }
            continue
        }
        if ($dist.ToLower() -eq "debian") { 
            Write-Host "`nUpdating $dist..." -ForegroundColor DarkCyan
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
            Write-Host "`nUpdating $dist..." -ForegroundColor DarkCyan
            if (-not $suMode) {
                $distPackageManagers = "eval 'apt update && apt full-upgrade -y && apt autoremove -y && snap refresh'"
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution ubuntu", "--user root", "-- $distPackageManagers" 
            } else {
                $distPackageManagers = "eval 'sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo snap refresh'"
                Start-Process -NoNewWindow -Wait -FilePath wsl.exe -ArgumentList "--distribution ubuntu", "-- $distPackageManagers" 
            }
            continue
        }

        Write-Host "`nSkipping update for $dist..." -ForegroundColor DarkCyan
        Write-Host "$dist not yet supported...`nSubmit a issue to add support: https://github.com/AndreasBrostrom/win-upgrade/issues" -ForegroundColor Yellow
    }
    Write-Host "`nWindows Subsystem for Linux update compleat...`n`n" -ForegroundColor Green
}
function runWindowsUpdate {

    Try {
        Write-Host "Checking for updates..."
        Write-Host "This may take some time stand by..." -ForegroundColor DarkGray
        Get-WindowsUpdate
        Write-Host "`nInstalling updates..."
        Write-Host "This may take some time stand by..." -ForegroundColor DarkGray
        Install-WindowsUpdate -AcceptAll -IgnoreReboot -Install >$null 2>&1

        Write-Host "`nWindows update compleat...`n`n" -ForegroundColor Green
    }
    Catch {
        Write-Host "Windows update don't work with remote connection...`n$_`n`n" -ForegroundColor Red
        return
    }
}
function runScoopUpdate {
    Write-Host "Updating Scoop..." -ForegroundColor Blue

    Write-Host "Updating Scoop repositories..."
    scoop update

    Write-Host "Updating local packages..."
    scoop update *

    if ($IS_ADMIN) {
        Write-Host "Updating globla packages..."
        scoop update * --global
    }

    Write-Host "`nScoop update compleat...`n`n" -ForegroundColor Green
}
function runChocolateyUpdate {
    Write-Host "Updating Choco packages..." -ForegroundColor Blue

    # Get links on desktop befor installation
    $preDesktop = [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktop') |
        Get-ChildItem -Filter '*.lnk'

    # Update choco
    choco upgrade all -y

    # Cleaning up new unwhanted desktop icons
    Write-Host "`nCleaning up Chocolatey created desktop icons..."
    $postDesktop = [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktop') |
        Get-ChildItem -Filter '*.lnk'
    $postDesktop | Where-Object FullName -notin $preDesktop.FullName | Foreach-Object {
        Remove-Item -LiteralPath $_.FullName
        Write-Host "Cleaned up $($_.Name)" -ForegroundColor DarkGray
    }

    Write-Host "`nChocolatey update compleat...`n`n" -ForegroundColor Green
}
function runWinGetUpdate {
    Write-Host "Updating WinGet packages..." -ForegroundColor Blue

    # Get links on desktop befor installation
    $preDesktop = [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktop') |
        Get-ChildItem -Filter '*.lnk'

    # Update WinGet
    winget upgrade --include-unknown --silent --all

    # Cleaning up new unwhanted desktop icons
    Write-Host "`nCleaning up WinGet created desktop icons..."
    $postDesktop = [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktop') |
        Get-ChildItem -Filter '*.lnk'
    $postDesktop | Where-Object FullName -notin $preDesktop.FullName | Foreach-Object {
        Remove-Item -LiteralPath $_.FullName
        Write-Host "Cleaned up $($_.Name)" -ForegroundColor DarkGray
    }

    Write-Host "`nWinGet update compleat...`n`n" -ForegroundColor Green
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
if ( $IS_ADMIN -And $HAS_Chocolatey ) { runChocolateyUpdate}
if ( $IS_ADMIN -And  $HAS_winget ) { runWinGetUpdate }

Write-Host "All updates is completed." -ForegroundColor Green

if (Test-PendingReboot) {
    Write-Host "Reboot is required, but do it manually." -ForegroundColor Yellow
}

exit 0