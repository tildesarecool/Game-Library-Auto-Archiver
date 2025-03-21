# Module manifest for GameLibAutoArchiver
@{
    # Script module (.psm1) or binary module (.dll) to be loaded when importing the module
    RootModule        = 'gamelibautoarchiver.psm1'

    # Version number of this module
    ModuleVersion     = '0.0.1'

    # Supported PowerShell editions
    PowerShellVersion = '7.0'

    # Author of this module
    Author           = 'Your Name'

    # Company or vendor of this module
    CompanyName      = 'YourName or GitHub Username'

    # Copyright statement for this module
    Copyright        = '(c) 2024 Your Name. All rights reserved.'

    # Description of the functionality provided by this module
    Description      = 'A PowerShell module for automatically archiving PC game libraries using last write date and platform detection.'

    # Functions to export from this module
    FunctionsToExport = @('*')

    # Cmdlets to export from this module
    CmdletsToExport  = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport  = @()

    # Private data (Used for publishing to PowerShell Gallery)
    PrivateData = @{
        PSData = @{
            # Tags for searching the module in PowerShell Gallery
            Tags         = @('Game', 'Library', 'Archiver', 'Backup', 'Automation', 'Zip', 'Compression')

            # Project URL (GitHub repo)
            ProjectUri   = 'https://github.com/yourusername/GameLibAutoArchiver'

            # License URL
            LicenseUri   = 'https://github.com/yourusername/GameLibAutoArchiver/blob/main/LICENSE'

            # Release notes
            ReleaseNotes = 'Initial version 0.0.1'
        }
    }
}
