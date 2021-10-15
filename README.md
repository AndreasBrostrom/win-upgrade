# win-upgrade
**Windows upgrade** or **Upgrade** for short are a update script written in powershell. The script look for your package managers including WSL and update your computer.

To run the script make sure your PS1 file is placed in a location in your path and that you are allowed to run scripts. For a real terminal super user fealing.

The script can detect:
 - [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install) (WSL)
 - [PSWindowsUpdate](https://www.powershellgallery.com/packages/PSWindowsUpdate/2.2.0.2) (Powershell Moduel)
 - [Scoop](https://scoop.sh/)
 - [Chocolatey](https://chocolatey.org/)
 - [WinGet](https://docs.microsoft.com/en-us/windows/package-manager/winget/) (Windows Package Manager)

***Note!** When using a sudo windows script i recommend you using [lukesampson sudo](https://github.com/lukesampson/psutils/blob/master/sudo.ps1) simply run `scoop install sudo`.*
