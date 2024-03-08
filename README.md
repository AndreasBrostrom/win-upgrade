# win-upgrade
**Windows upgrade** or **Upgrade** for short are a update script written in powershell. The script look for your package managers including WSL ones and update them.

![](https://github.com/AndreasBrostrom/win-upgrade/blob/main/resources/demo.png)

To run the script make sure your PS1 file is placed in a location in your path and that you are allowed to run scripts. 

To run the script make sure the script location is placed in your windows `$PATH` variable. (For a real terminal super user fealing.) But you can also just run the script.

The script can detect:
 - [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install) (WSL)
 - [PSWindowsUpdate](https://www.powershellgallery.com/packages/PSWindowsUpdate) (Powershell Moduel)
 - [Scoop](https://scoop.sh/)
 - [Chocolatey](https://chocolatey.org/)
 - [WinGet](https://docs.microsoft.com/en-us/windows/package-manager/winget/) (Windows Package Manager)

```pwsh
Usage: upgrade [-w] [-s] [-v] [-help]

    -h, -help          Show this help
    -w, -noWindows     Disable update check for windows
    -s, -suMode        Disable suMode and require sudo password on a user level for wsl update. This may lead to required confirms.
    -v, -version       Show current version
```

***Note!** When using a sudo windows script i recommend you using [lukesampson sudo](https://github.com/lukesampson/psutils/blob/master/sudo.ps1) simply run `scoop install sudo`.*

## Install

1. Create a .bin directory in your home directory and make sure it added to your path.
   ```pwsh
   PS> New-Item -itemtype "directory" -path "$Env:userprofile\.bin" -Force
   PS> [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$Env:userprofile\.bin", "User")
   ```
2. Unzip latest release
   ```pwsh
   PS> Expand-Archive "$Env:userprofile\Downloads\upgrade-1.0.3.zip" -DestinationPath "$Env:userprofile\.bin"
   PS> Remove-Item "$Env:userprofile\.bin\README.md"
   ```
3. Run
   ```pwsh
   PS> upgrade
   ```
