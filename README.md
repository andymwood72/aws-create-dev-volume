# New-VHDDevDrive

Create a VHDX-backed Dev Drive formatted with ReFS from PowerShell.

## Prerequisites

- Windows 11 with Dev Drive support
- Elevated PowerShell session
- Hyper-V PowerShell module (for `New-VHD`, `Mount-VHD`)

## Quick Start (Command Prompt)

```cmd
create-devdrive.cmd --path "C:\DevDrives\devdrive.vhdx" --size 50GB --letter B --label DevDrive
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
- The PowerShell version is still available in `New-VHDDevDrive.ps1`.
- The CMD script only allows one Dev Drive at a time.
- Use `--no-av` to disable antivirus filters (default is `--allow-av`).

## Remove an existing Dev Drive

```cmd
remove-devdrive.cmd --path "C:\DevDrives\devdrive.vhdx"
```

If you omit `--path`, the script will try to auto-detect the Dev Drive by drive letter.

## Status

```cmd
status-devdrive.cmd
```
