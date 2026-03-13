# scripting dev drive configuration

Add/Remove a VHDX-backed Dev Drive formatted with ReFS for Windows 11. For more info on Dev Drive - https://learn.microsoft.com/en-us/windows/dev-drive/. These scripts were developed with the intention of deployment in Amazon WorkSpaces; but would work on w365 or physical devices that have the capability of using Dev Drives 

## Prerequisites

- Windows 11 with Dev Drive support (https://learn.microsoft.com/en-us/windows/dev-drive/)
- Windows 11, Build #10.0.22621.2338 or later (Check for Windows updates)
- Recommend 16 GB memory (minimum of 8 GB)
- Minimum 50 GB free disk space
- Dev Drives are available on all Windows SKU versions.
- Local administrator permissions.

## Quick Start (Command Prompt)

```cmd
create-devdrive.cmd --path "C:\DevDrives\devdrive.vhdx" --size 50GB --letter B --label DevDrive
```

Use defaults:

```cmd
create-devdrive.cmd --defaults
```

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
