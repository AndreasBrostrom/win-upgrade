# win-upgrade
**Windows upgrade** or **Upgrade** for short are a update script written in powershell. The script look for your package managers including WSL ones and update them.

![](https://github.com/AndreasBrostrom/win-upgrade/blob/main/resources/demo.png)

To run the script make sure your PS1 file is placed in a location in your path and that you are allowed to run scripts. 

To run the script make sure the script location is placed in your windows `$PATH` variable. (For a real terminal super user feeling.) But you can also just run the script.

The script can detect:
 - [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install) (WSL)
 - [PSWindowsUpdate](https://www.powershellgallery.com/packages/PSWindowsUpdate) (Powershell Module)
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

1. Create a `.bin` directory in your home directory and make sure it added to your `$PATH` environment variable.
   ```pwsh
   PS> New-Item -itemtype "directory" -path "$env:userprofile\.bin" -Force
   PS> [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:userprofile\.bin", "User")
   ```
2. Download latest release ([Can be found here](https://github.com/AndreasBrostrom/win-upgrade/releases/latest))
   ```
   PS> $version=(irm 'https://api.github.com/repos/AndreasBrostrom/win-upgrade/releases/latest' | Select tag_name).tag_name
   PS> iwr -URI "https://github.com/AndreasBrostrom/win-upgrade/releases/download/$version/upgrade-$version.zip" -OutFile "$env:userprofile/Downloads/upgrade-latest.zip"
   ```
3. Unzip latest release
   ```pwsh
   PS> Expand-Archive "$env:userprofile\Downloads\upgrade-latest.zip" -DestinationPath "$env:userprofile\.bin"
   PS> Remove-Item "$env:userprofile\.bin\README.md"
   ```
4. Run
   ```pwsh
   PS> upgrade
   ```
