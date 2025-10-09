# Visual Studio Build Tools 2019 in Wine

This directory contains an automated installer for Microsoft Visual Studio Build Tools 2019 running in Wine on NixOS/Linux.

## Quick Start

```bash
# Make the script executable
chmod +x install_buildtools.sh

# Run the installation
./install_buildtools.sh
```

The installation process takes approximately 30-60 minutes and requires:
- Internet connection for downloading ~5GB offline layout
- Approximately 10GB of free disk space

## Directory Structure

```
packages/
├── shell.nix                      # Nix environment with Wine
├── install_buildtools.sh          # Automated installation script
├── visualstudio_buildtools/2019/
│   ├── vs_buildtools.exe         # VS Build Tools bootstrapper
│   └── confirm.bat               # Verification script
└── .wine/                        # Wine prefix (created during install)
    └── drive_c/
        ├── vslayout/             # Offline installation layout (~5GB)
        └── Program Files (x86)/
            └── Microsoft Visual Studio/
                └── 2019/BuildTools/  # Installed Build Tools
```

## Installation Process

### Stage 1: Download Offline Layout

The installer downloads a complete offline installation layout containing all required packages:

```bash
wine visualstudio_buildtools/2019/vs_buildtools.exe \
    --layout "C:\vslayout" \
    --lang en-US \
    --add Microsoft.VisualStudio.Workload.VCTools \
    --includeRecommended \
    --includeOptional \
    --quiet
```

**Key parameters:**
- `--layout`: Creates offline installation source (must be <80 chars)
- `--quiet`: Avoids WPF UI errors in Wine
- `--lang en-US`: English language only
- `--add Microsoft.VisualStudio.Workload.VCTools`: C++ build tools
- `--includeRecommended --includeOptional`: All components

### Stage 2: Install from Layout

The installer uses the offline layout to install Build Tools:

```bash
wine .wine/drive_c/vslayout/vs_buildtools.exe \
    --quiet \
    --norestart \
    --noweb \
    --add Microsoft.VisualStudio.Workload.VCTools \
    --includeRecommended \
    --includeOptional
```

**Key parameters:**
- `--quiet`: No UI initialization
- `--noweb`: Use only offline layout
- `--norestart`: Don't reboot after install

## Usage

After installation, activate the build environment:

```bash
# Enter nix-shell
nix-shell

# Load Visual Studio environment
wine cmd /c "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

# Now you can use cl.exe, link.exe, etc.
wine cl.exe --version
```

## Troubleshooting

### Common Issues and Solutions

#### 1. WPF Graphics Error (0x88980406)

**Problem:** Visual Studio installer uses Windows Presentation Foundation (WPF) which requires DirectX capabilities Wine doesn't support.

**Solution:** Use `--quiet` flag instead of `--passive` to skip all UI initialization.

#### 2. Environment Variable Case Conflict

**Problem:** Wine exposes both `SHELL` (Linux) and `shell` (Windows), causing .NET dictionary conflicts.

**Error message:**
```
Error: Item has already been added. Key in dictionary: 'shell'  Key being added: 'SHELL'
```

**Solution:** Unset `SHELL` before running installer:
```bash
unset SHELL && wine vs_buildtools.exe ...
```

#### 3. Layout Path Too Long (Error 0x138f / 5007)

**Problem:** VS installer requires layout paths to be less than 80 characters.

**Error message:**
```
Error: The source layout directory is too long.
The layout directory name must be less than 80 characters.
```

**Solution:** Use short path like `C:\vslayout` instead of long Wine Z:\ paths.

#### 4. Relative Path Error (0x80070057)

**Problem:** `--layout` flag doesn't support relative paths or Linux-style paths.

**Error message:**
```
Error 0x80070057: --layout does not support relative paths.
```

**Solution:** Use Windows absolute path format:
```bash
# ✗ Wrong
--layout "$(pwd)/offline_layout"
--layout "/home/user/layout"

# ✓ Correct
--layout "C:\vslayout"
```

#### 5. Invalid Command Line Argument

**Problem:** VS 2019 installer doesn't support `--wait` flag (it was removed in later versions).

**Error message:**
```
Option 'wait' is unknown.
Error 0x80070057 (exit code 87)
```

**Solution:** Remove `--wait` flag from command line.

### Diagnostic Logs

Installation logs are located in:
```
.wine/drive_c/users/mpedersen/Temp/
├── dd_bootstrapper_*.log          # Bootstrapper execution logs
├── dd_installer_*.log             # Main installer logs
├── dd_installer_elevated_*.log    # Elevated installer logs
├── dd_setup_*.log                 # Setup engine logs
└── dd_vs_buildtools_decompression_log.txt  # Extraction logs
```

Check the most recent logs for detailed error information:
```bash
ls -ltr .wine/drive_c/users/mpedersen/Temp/dd_*.log | tail -5
```

## Technical Details

### Wine Environment

The `shell.nix` provides:
- Wine 9.0 (wineWow64Packages.full) with 64-bit support
- winetricks for managing Windows components
- wine64 symlink fix for winetricks compatibility
- Isolated Wine prefix at `.wine/` (not system-wide)

### Critical Fixes Applied

1. **WPF UI Bypass:** Using `--quiet` instead of `--passive` to avoid graphics initialization
2. **Environment Sanitization:** Unsetting `SHELL` to avoid case-sensitivity conflicts
3. **Path Format:** Using Windows C:\ paths instead of Wine Z:\ paths
4. **Path Length:** Keeping paths under 80 characters
5. **Offline Mode:** Using `--noweb` to prevent network hangs

### Prerequisites Installed

The installation includes:
- .NET Framework 4.0 through 4.8
- Visual C++ runtimes
- Windows SDK 10.0.19041
- MSBuild tools
- C/C++ compiler toolchain (cl.exe, link.exe)
- CMake tools
- LLVM/Clang toolsets

### What Gets Installed

**Components included:**
- Microsoft.VisualStudio.Workload.VCTools (main workload)
- Microsoft.VisualStudio.Component.VC.Tools.x86.x64
- Microsoft.VisualStudio.Component.VC.Redist.14.Latest
- Microsoft.VisualStudio.Component.Windows10SDK.19041
- Microsoft.VisualStudio.Component.VC.CMake.Project
- Microsoft.VisualStudio.Component.VC.ATL
- Microsoft.VisualStudio.Component.VC.ATLMFC
- Microsoft.VisualStudio.Component.VC.CLI.Support
- Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Llvm.Clang
- And many more...

**Installation size:**
- Offline layout: ~5GB
- Installed Build Tools: ~3-4GB
- Total disk usage: ~8-10GB

## Known Limitations

### What Works
✅ Offline layout creation
✅ Build Tools installation
✅ vcvarsall.bat environment setup
✅ Command-line compilation (cl.exe, link.exe)
✅ MSBuild execution

### What May Not Work
⚠️ GUI applications (due to WPF limitations)
⚠️ Interactive installers
⚠️ Some Windows-specific services

### Why Wine?

This approach uses Wine instead of a full Windows VM because:
- Lighter weight (no VM overhead)
- Faster I/O (direct filesystem access)
- Easier integration with Linux tools
- Can be automated via scripts

However, for production use or if you encounter issues, consider:
- Using a Windows VM for better compatibility
- Using native Linux toolchains (GCC/Clang)
- Using MinGW-w64 for Windows cross-compilation

## Version Information

- **Visual Studio Build Tools:** 2019 (16.11.51)
- **Wine:** 9.0 (wineWow64Packages.full)
- **Architecture:** win64 (64-bit)
- **Installer Version:** 3.14.2086

## References

### Official Documentation
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2019)
- [Create an offline installation](https://docs.microsoft.com/en-us/visualstudio/install/create-an-offline-installation-of-visual-studio)
- [Use command-line parameters](https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio)

### Wine Resources
- [Wine HQ](https://www.winehq.org/)
- [Wine User's Guide](https://wiki.winehq.org/Wine_User%27s_Guide)
- [winetricks](https://github.com/Winetricks/winetricks)

## Verification

To verify the installation is working:

```bash
# Enter the environment
nix-shell

# Run the confirmation script
wine cmd /c "cd visualstudio_buildtools\\2019 && confirm.bat"

# Expected output:
# ** Visual Studio 2019 Developer Command Prompt v16.11.51
# ** Copyright (c) 2021 Microsoft Corporation
# [vcvarsall.bat] Environment initialized for: 'x64'

# Check for vcvarsall.bat
ls -la ".wine/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat"
```

## License

This project uses Microsoft Visual Studio Build Tools 2019, which is subject to Microsoft's license terms. Please review the license agreement before use.

The installation scripts (shell.nix, install_buildtools.sh) are provided as-is for educational and development purposes.
