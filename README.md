# Game Library Auto Archiver  

**A PowerShell module for automatically compressing and managing game library backups.**  

This module scans a game library directory and archives each game's folder into a compressed file. It supports multiple PC gaming platforms, including **Steam, GOG, Amazon, Epic, Origin, Uplay, and more**. Archive filenames include the game's **last modified date** and platform identifier for easy tracking.  

**Note: I've recently learned that zip files created with compress-archive have a file size limit of 2GB, which I was not aware of. The only work arounds as far as I can tell is to either auto-create ~2 gig zip files of folders larger than this or to use a third party utility like 7zip. I don't have any interest in splitting a 110 gigabyte folder into many 2 gigabyte zip files. Actually the default zip file size limit is 4 gigaybtes anyway. Apparently compress-archive doesn't do zip64 which has no such file size limits. I actually thought of my own alternative as well which I'm still assessing.**

**A long winded a way of saying this script is on hold while I 're-assess my options.'**


## Features  
- 📂 **Automated Archiving** – Compress game library folders into archives with platform and date metadata.  
- 🔄 **Outdated Zip Cleanup** – Automatically removes older archives if the game folder has been updated.  
- ⚙️ **Custom Compression Formats** – Future support for different archive formats beyond `.zip`.  
- 🛠 **PowerShell 7 Compatible** – Designed for Windows 10/11 with PowerShell 7.x.  
- 🏗 **Modular & Extensible** – Packaged as a PowerShell module (`.psm1` + `.psd1`) for ease of use.  
- 🧪 **Tested with Pester** – Uses automated testing to ensure reliability.  
- ☁ **GitHub Versioning & CI/CD Ready** – Maintains version control with Git, GitHub Actions, and Git tags.  
- 🎯 **Manual PowerShell Gallery Publishing** – Ensures only stable versions are released.  

## Installation  

To install from source:  

```powershell
git clone https://github.com/YOUR_USERNAME/GameLibAutoArchiver.git
cd GameLibAutoArchiver
```

## Usage

It's not actually ready to use yet. Don't use it. This is jsut an example.

Import-Module ./GameLibAutoArchiver/GameLibAutoArchiver.psd1
Start-GameLibraryArchive -LibraryPath "C:\Games"

Where that c:\games is a path to your game library.

## Contributing

Feel free to submit issues or pull requests!

