# scripting dev drive configuration

Add/Remove a VHDX-backed Dev Drive formatted with ReFS for Windows 11. For more info on Dev Drive - https://learn.microsoft.com/en-us/windows/dev-drive/

## Prerequisites

- Windows 11 with Dev Drive support
- Elevated Admin session

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
- The CMD script only allows one Dev Drive at a time.
- Use `--no-av` to disable antivirus filters (default is `--allow-av`).
- Use `--fixed` to create a fixed-size VHDX (default is expandable).

## Remove an existing Dev Drive

```cmd
remove-devdrive.cmd --path "C:\DevDrives\devdrive.vhdx"
```

If you omit `--path`, the script will try to auto-detect the Dev Drive by drive letter.

## Status

```cmd
status-devdrive.cmd
```
