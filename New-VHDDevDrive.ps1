<#
.SYNOPSIS
Creates a VHDX-backed Dev Drive formatted with ReFS.

.DESCRIPTION
Dot-source this script to load the New-VHDDevDrive function, then call it to
create a dynamic VHDX, mount it, initialize it with GPT, and format it as a
ReFS Dev Drive. The function also enables Dev Drive support if needed.

.EXAMPLE
PS> . .\New-VHDDevDrive.ps1
PS> New-VHDDevDrive -Path "C:\DevDrives\devdrive.vhdx" -Size 50GB -Label "DevDrive"

.EXAMPLE
PS> Get-Help .\New-VHDDevDrive.ps1 -Full

.NOTES
Requires an elevated PowerShell session and the Hyper-V PowerShell module.
#>
[CmdletBinding()]
param(
    [string]$Path,

    [string]$Size = '5GB',

    [string]$Label = 'DevDrive',

    [ValidatePattern('^[A-Za-z]$')]
    [string]$DriveLetter = 'B',

    [ValidateSet('Default', 'AllowAv', 'DisallowAv')]
    [string]$AvFilterPolicy = 'Default',

    [switch]$Force,

    [string[]]$FiltersAllowed
)

Set-StrictMode -Version Latest

function Test-IsAdministrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Enable-HyperVPowerShellModule {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    $moduleAvailable = Get-Module -ListAvailable -Name Hyper-V
    if ($moduleAvailable) {
        try {
            Import-Module Hyper-V -ErrorAction Stop
            return
        } catch {
            throw "Hyper-V PowerShell module is installed but failed to import. $($_.Exception.Message)"
        }
    }

    if (-not (Test-IsAdministrator)) {
        throw 'Hyper-V PowerShell module is not installed. Run as Administrator to install it.'
    }

    if (-not $Force) {
        $answer = Read-Host 'Hyper-V PowerShell module is not installed. Install it now? (Y/N)'
        if ($answer -notin @('Y', 'y', 'Yes', 'yes')) {
            throw 'Hyper-V PowerShell module is required to create a VHD.'
        }
    }

    $installOutput = & Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell -All -NoRestart 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Hyper-V PowerShell module. Output: $installOutput"
    }

    try {
        Import-Module Hyper-V -ErrorAction Stop
    } catch {
        throw "Hyper-V PowerShell module was installed but failed to import. $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
Enables Dev Drive support and validates policy settings.

.DESCRIPTION
Checks for policy that disables Dev Drive creation, enables the registry flag
for Dev Drive creation, and runs fsutil to enable Dev Drive support. Optionally
configures how antivirus filters attach to Dev Drives.

.PARAMETER AvFilterPolicy
Controls antivirus filter attachment when enabling Dev Drive support.
Valid values are Default, AllowAv, or DisallowAv.

.EXAMPLE
PS> Enable-DevDriveConfiguration -AvFilterPolicy DisallowAv
#>
function Enable-DevDriveConfiguration {
    [CmdletBinding()]
    param(
        [ValidateSet('Default', 'AllowAv', 'DisallowAv')]
        [string]$AvFilterPolicy = 'Default'
    )

    if (-not (Test-IsAdministrator)) {
        throw 'Run this function in an elevated PowerShell session.'
    }

    $policyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Filesystem'
    $policy = Get-ItemProperty -Path $policyKey -Name EnableDevDrive -ErrorAction SilentlyContinue
    if ($policy -and $policy.EnableDevDrive -eq 0) {
        throw 'Dev Drive creation is disabled by policy. Set EnableDevDrive to 1 or update Group Policy.'
    }

    $fsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    $current = Get-ItemProperty -Path $fsKey -Name EnableDevDrive -ErrorAction SilentlyContinue
    if ($null -eq $current -or $current.EnableDevDrive -ne 1) {
        New-ItemProperty -Path $fsKey -Name EnableDevDrive -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Verbose 'Enabled Dev Drive creation (a reboot may be required).'
    }

    $enableArgs = @('devdrv', 'enable')
    switch ($AvFilterPolicy) {
        'AllowAv' { $enableArgs += '/allowAv' }
        'DisallowAv' { $enableArgs += '/disallowAv' }
        default { }
    }

    $output = & fsutil @enableArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to enable Dev Drive support. fsutil output: $output"
    }
}

<#
.SYNOPSIS
Creates a VHDX-backed Dev Drive formatted with ReFS.

.DESCRIPTION
Ensures Dev Drive support is enabled, creates a dynamic VHDX, mounts it,
initializes the disk using GPT, creates a single partition, and formats it as
a ReFS Dev Drive. Optionally sets allowed filters on the new volume.

.PARAMETER Path
Full path to the new VHDX file, e.g. C:\DevDrives\devdrive.vhdx.

.PARAMETER Size
Size of the VHDX. Accepts PowerShell size strings (e.g. 50GB, 200GB).

.PARAMETER Label
Volume label for the formatted Dev Drive.

.PARAMETER DriveLetter
Drive letter to assign to the new volume.

.PARAMETER AvFilterPolicy
Controls antivirus filter attachment when enabling Dev Drive support.
Valid values are Default, AllowAv, or DisallowAv.

.PARAMETER Force
Skips confirmation prompts (for example, installing Hyper-V PowerShell module).

.PARAMETER FiltersAllowed
Optional list of minifilter names to allow on this Dev Drive volume.

.EXAMPLE
PS> . .\New-VHDDevDrive.ps1
PS> New-VHDDevDrive -Path "C:\DevDrives\devdrive.vhdx" -Size 50GB -Label "DevDrive"

.EXAMPLE
PS> . .\New-VHDDevDrive.ps1
PS> New-VHDDevDrive -Path "C:\DevDrives\devdrive.vhdx" -Size 100GB `
>>   -FiltersAllowed @('PrjFlt','MsSecFlt','DfmFlt')

.NOTES
Requires an elevated PowerShell session and the Hyper-V PowerShell module.
If Dev Drive creation was disabled, you may need to reboot after enabling it.
#>
function New-VHDDevDrive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path, # e.g. 'C:\test4.vhdx'

        [string]$Size = '5GB',

        [string]$Label = 'DevDrive',

        [ValidatePattern('^[A-Za-z]$')]
        [string]$DriveLetter = 'B',

        [ValidateSet('Default', 'AllowAv', 'DisallowAv')]
        [string]$AvFilterPolicy = 'Default',

        [switch]$Force,

        [string[]]$FiltersAllowed
    )

    Enable-DevDriveConfiguration -AvFilterPolicy $AvFilterPolicy

    Enable-HyperVPowerShellModule -Force:$Force

    $parentDir = Split-Path -Parent $Path
    if (-not (Test-Path -Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    if (Test-Path -Path $Path) {
        throw "VHD already exists at path: $Path"
    }

    $vhd = New-VHD -Path $Path -Dynamic -SizeBytes $Size
    $disk = $vhd | Mount-VHD -Passthru
    $init = $disk | Initialize-Disk -PartitionStyle GPT -PassThru

    # New-Partition pops open explorer to the new drive before Format-Volume
    # completes, so it often tells you to format the drive.
    #
    # > You need to format the disk in drive R: before you can use it.
    #
    # Just ignore the pop-up until the formatting is complete, then click Cancel.
    $normalizedLetter = $DriveLetter.ToUpper()
    if (Get-PSDrive -Name $normalizedLetter -ErrorAction SilentlyContinue) {
        throw "Drive letter $normalizedLetter`: is already in use."
    }

    $part = $init | New-Partition -DriveLetter $normalizedLetter -UseMaximumSize
    $vol = $part | Format-Volume -DevDrive -FileSystem ReFS -Confirm:$false -Force -NewFileSystemLabel $Label

    if ($FiltersAllowed -and $FiltersAllowed.Count -gt 0) {
        $filterList = $FiltersAllowed -join ','
        $filterOutput = & fsutil devdrv setFiltersAllowed /F /volume "$($vol.DriveLetter):" $filterList 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set allowed filters. fsutil output: $filterOutput"
        }
    }

    return $vol

    # You can enable filters on this volume, too, like GVFS & Security:
    # fsutil devdrv setFiltersAllowed /F /volume "$($vol.DriveLetter):" PrjFlt,MsSecFlt,DfmFlt
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($PSBoundParameters.Count -eq 0) {
        Get-Help $MyInvocation.MyCommand.Path -Full
        return
    }

    New-VHDDevDrive @PSBoundParameters
}
