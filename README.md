# scripting dev drive configuration

Add/Remove a VHDX-backed Dev Drive formatted with ReFS for Windows 11. For more info on Dev Drive - https://learn.microsoft.com/en-us/windows/dev-drive/

## Prerequisites

- Windows 11 with Dev Drive support
- Elevated Admin session

## Quick Start (Command Prompt)

```cmd
create-devdrive.cmd --path "C:\DevDrives\devdrive.vhdx" --size 50GB --letter B --label DevDrive
```

Use defaults:

```cmd
create-devdrive.cmd --defaults
```

## Quick Start (PowerShell Interactive)

Use the PowerShell wrapper to validate inputs, then run `create-devdrive.cmd` elevated:

```powershell
powershell -ExecutionPolicy Bypass -File .\create-devdrive.ps1
```

The script:
- exits if a Dev Drive is already mounted
- prompts for size in GB (integer, minimum 50, maximum is `D:` free space minus 50 GB)
- prompts for a drive letter and ensures it is not already in use
- launches `create-devdrive.cmd --size <n>GB --letter <X>` as Administrator

## Examples

```cmd
create-devdrive.cmd --path "C:\DevDrives\devdrive.vhdx" --size 100GB ^
  --filters PrjFlt,MsSecFlt,DfmFlt --force
```

## Help

```cmd
create-devdrive.cmd --help
remove-devdrive.cmd --help
status-devdrive.cmd --help
```

## Notes

- If Dev Drive creation was previously disabled, enabling it may require a reboot.
- The drive letter pop-up during partition creation is normal; wait for formatting to finish.
- Run from an elevated Command Prompt.
- The CMD script only allows one Dev Drive at a time.
- Each script is self-contained and can run independently.
- Use `--no-av` to disable antivirus filters (default is `--allow-av`).
- Use `--fixed` to create a fixed-size VHDX (default is expandable).
- Use `--defaults` to create with all default settings.
- When using `--defaults`, an existing `%USERPROFILE%\dev-drive\devdrive.vhdx` is mounted instead of overwritten.
- Default path is `%USERPROFILE%\dev-drive\devdrive.vhdx`.
- Default drive letter is `B`.

## Remove an existing Dev Drive

```cmd
remove-devdrive.cmd --path "C:\DevDrives\devdrive.vhdx"
```

If you omit `--path`, the script will try to auto-detect the Dev Drive by drive letter.

Running `remove-devdrive.cmd` with no parameters shows help.

Use defaults (auto-detect and detach):

```cmd
remove-devdrive.cmd --defaults
```

Delete the VHDX after detaching (prompts by default):

```cmd
remove-devdrive.cmd --path "C:\DevDrives\devdrive.vhdx" --delete
```

Skip the delete prompt:

```cmd
remove-devdrive.cmd --path "C:\DevDrives\devdrive.vhdx" --delete --force
```

Combine defaults with delete options:

```cmd
remove-devdrive.cmd --defaults --delete
remove-devdrive.cmd --defaults --delete --force
```

When using `--delete`, the script will only delete the appropriate `.vhd`/`.vhdx` file.

## Status

```cmd
status-devdrive.cmd
```

The status output includes the Dev Drive path when available.
