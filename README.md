# Visual Studio Build Tools 2019 in Wine

Automated installer for Microsoft Visual Studio Build Tools 2019 running in Wine on NixOS/Linux, with a convenient justfile interface.

## Quick Start

```bash
# Enter the nix shell
nix-shell

# Complete installation (30-60 minutes)
just full-install

# Or step-by-step:
just prerequisites  # Install .NET Framework 4.8 (5-15 min)
just download       # Download offline layout (~5GB, 10-30 min)
just install        # Install Build Tools
just demo           # Verify with test compilation
```

## Available Commands

Run `just` to see all available commands:

| Command | Description |
|---------|-------------|
| `just prerequisites` | Install .NET Framework 4.8 (required before download/install) |
| `just download` | Download VS Build Tools offline layout (~5GB) |
| `just install` | Install Build Tools from offline layout |
| `just demo` | Compile and run test C program to verify installation |
| `just status` | Show installation status and disk usage |
| `just full-install` | Run all steps: prerequisites → download → install → demo |
| `just compiler-info` | Show MSVC compiler version and help |
| `just list-tools` | List all installed MSVC tools (cl.exe, link.exe, etc.) |
| `just check-logs` | Show recent installer log files |
| `just clean-wine` | Kill background Wine processes |
| `just clean-all` | **WARNING:** Delete entire Wine prefix |
| `just info` | Show Wine prefix information |
| `just winecfg` | Open Wine configuration GUI |

## Requirements

- Internet connection for downloading ~5GB offline layout
- Approximately 10GB of free disk space
- 30-60 minutes for complete installation

## Installation Process

### Prerequisites: .NET Framework 4.8 (Critical)

**The VS Build Tools installer requires .NET Framework 4.8.** Without it, the installer will crash with a segmentation fault (exit code 139).

```bash
just prerequisites
```

This installs .NET Framework 4.8 via winetricks (takes 5-15 minutes).

### Stage 1: Download Offline Layout

Downloads a complete offline installation layout (~5GB):

```bash
just download
```

This runs:
```bash
wine vs_buildtools.exe \
    --layout "C:\vslayout" \
    --lang en-US \
    --add Microsoft.VisualStudio.Workload.VCTools \
    --includeRecommended \
    --includeOptional \
    --quiet
```

**Key parameters:**
- `--layout C:\vslayout` - Short Windows path (<80 chars required)
- `--quiet` - Skips UI (avoids WPF errors in Wine)
- `--lang en-US` - English language only
- `--add Microsoft.VisualStudio.Workload.VCTools` - C++ build tools workload

### Stage 2: Install from Layout

Installs Build Tools from the offline layout:

```bash
just install
```

This runs:
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
- `--quiet` - No UI initialization
- `--noweb` - Use only offline layout (no internet downloads)
- `--norestart` - Don't reboot after installation

### Verification

```bash
# Run demo compilation
just demo

# Or manually verify
wine cmd /c "cd visualstudio_buildtools\\2019 && confirm.bat"

# Expected output:
# ** Visual Studio 2019 Developer Command Prompt v16.11.51
# [vcvarsall.bat] Environment initialized for: 'x64'
```

## Usage

After installation, use the Build Tools:

```bash
# Enter nix-shell
nix-shell

# Load Visual Studio environment
wine cmd /c "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

# Compile C/C++ code
wine cl.exe myfile.c
wine cl.exe myfile.cpp

# Check compiler version
wine cl.exe
```

## Directory Structure

```
wine_msbuildtools/
├── shell.nix                     # Nix environment with Wine
├── justfile                      # Task runner with all commands
├── visualstudio_buildtools/2019/
│   ├── vs_buildtools.exe        # VS Build Tools bootstrapper
│   └── confirm.bat              # Verification script
└── .wine/                       # Wine prefix (created during install)
    └── drive_c/
        ├── vslayout/            # Offline installation layout (~5GB)
        └── Program Files (x86)/
            └── Microsoft Visual Studio/
                └── 2019/BuildTools/  # Installed Build Tools
```

## Troubleshooting

### Common Issues

#### Issue #1: Missing .NET Framework 4.8

**Problem:** VS Build Tools installer crashes with segmentation fault before any output.

**Error code:** Exit code 139 (SIGSEGV)

**Root cause:** The VS installer bootstrapper requires .NET Framework 4.8 to initialize.

**Solution:**
```bash
just prerequisites
# Or manually:
nix-shell --run "winetricks -q dotnet48"
```

#### Issue #2: WPF Graphics Error (0x88980406)

**Problem:** Installer exits with error code 0x138a, logs show WPF graphics errors.

**Root cause:** Visual Studio installer uses Windows Presentation Foundation (WPF) which requires DirectX capabilities Wine doesn't fully support.

**Solution:** Use `--quiet` flag instead of `--passive` to skip all UI initialization.
```bash
# ✗ Wrong - tries to show UI
wine vs_buildtools.exe --passive ...

# ✓ Correct - skips all UI
wine vs_buildtools.exe --quiet ...
```

**Why this works:**
- `--passive`: Shows minimal UI, still initializes WPF
- `--quiet`: No UI at all, skips WPF initialization

#### Issue #3: Environment Variable Case Conflict

**Problem:** Installer crashes with "Item has already been added. Key in dictionary: 'shell' Key being added: 'SHELL'"

**Error code:** 0x80070057

**Root cause:** Wine exposes both `SHELL` (Linux) and `shell` (Windows). The .NET installer's case-insensitive dictionary detects both as duplicates.

**Solution:** Unset `SHELL` before running installer (automatically done by justfile):
```bash
unset SHELL && wine vs_buildtools.exe ...
```

#### Issue #4: Layout Path Too Long (Error 0x138f / 5007)

**Problem:** "The source layout directory is too long. The layout directory name must be less than 80 characters."

**Root cause:** VS installer has a hardcoded 80-character limit on layout paths.

**Solution:** Use short Windows C:\ paths instead of long Wine Z:\ paths:
```bash
# ✗ Wrong - path too long
wine vs_buildtools.exe --layout "Z:\home\user\very\long\path\..."

# ✓ Correct - short path (<80 chars)
wine vs_buildtools.exe --layout "C:\vslayout"
```

#### Issue #5: Relative Path Error (0x80070057)

**Problem:** "--layout does not support relative paths"

**Root cause:** The `--layout` parameter requires absolute Windows paths with drive letters.

**Solution:** Always use Windows absolute paths:
```bash
# ✗ Wrong - relative path
--layout "$(pwd)/offline_layout"

# ✗ Wrong - Linux absolute path
--layout "/home/user/layout"

# ✓ Correct - Windows C: path
--layout "C:\vslayout"
```

#### Issue #6: Invalid `--wait` Parameter

**Problem:** "Option 'wait' is unknown", exit code 87

**Root cause:** The `--wait` flag was removed in VS 2019 installer.

**Solution:** Remove `--wait` from command line (justfile already does this):
```bash
# ✗ Wrong - --wait not supported
wine vs_buildtools.exe --quiet --wait ...

# ✓ Correct - no --wait
wine vs_buildtools.exe --quiet ...
```

### Diagnostic Commands

```bash
# Check installation status
just status

# View recent installer logs
just check-logs

# Manual log inspection
ls -ltr .wine/drive_c/users/*/Temp/dd_*.log | tail -10
cat .wine/drive_c/users/*/Temp/dd_bootstrapper_*.log | grep -i error

# Check Wine processes
just clean-wine

# Check disk usage
du -sh .wine/drive_c/vslayout/
du -sh ".wine/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/"

# Verify key files
ls -la ".wine/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat"
```

### Success Indicators

**Successful layout download:**
```bash
# Log shows:
Launched extracted application exiting with result code: 0x0

# Verification:
du -sh .wine/drive_c/vslayout/  # ~4.9G
ls .wine/drive_c/vslayout/Catalog.json  # Should exist
```

**Successful installation:**
```bash
# Log shows:
Exit Code: 0

# Verification:
just demo  # Should compile and run test program
```

## Technical Details

### Wine Environment

The `shell.nix` provides:
- Wine 9.0 (wineWow64Packages.full) with 64-bit support
- winetricks for managing Windows components
- wine64 symlink fix for winetricks compatibility
- Isolated Wine prefix at `./.wine/` (not system-wide)
- `just` task runner for convenient commands

### Critical Fixes Applied

1. **WPF UI Bypass:** Using `--quiet` instead of `--passive` to avoid graphics initialization
2. **Environment Sanitization:** Unsetting `SHELL` to avoid case-sensitivity conflicts
3. **Path Format:** Using Windows C:\ paths instead of Wine Z:\ paths
4. **Path Length:** Keeping paths under 80 characters
5. **Offline Mode:** Using `--noweb` to prevent network hangs
6. **.NET Framework:** Installing .NET 4.8 before running VS installer

### Components Installed

**Main workload:**
- Microsoft.VisualStudio.Workload.VCTools

**Key components:**
- Microsoft.VisualStudio.Component.VC.Tools.x86.x64
- Microsoft.VisualStudio.Component.Windows10SDK.19041
- Microsoft.VisualStudio.Component.VC.CMake.Project
- Microsoft.VisualStudio.Component.VC.ATL
- Microsoft.VisualStudio.Component.VC.ATLMFC
- Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Llvm.Clang
- And many more with `--includeRecommended --includeOptional`

**Installation size:**
- Offline layout: ~5GB
- Installed Build Tools: ~3-4GB
- Total disk usage: ~8-10GB

### What Works

✅ Offline layout creation
✅ Build Tools installation
✅ vcvarsall.bat environment setup
✅ Command-line compilation (cl.exe, link.exe)
✅ MSBuild execution
✅ CMake with MSVC

### Known Limitations

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
- **MSVC Compiler:** 19.29.30159
- **MSVC Linker:** 14.29.30159
- **Wine:** 9.0 (wineWow64Packages.full)
- **Architecture:** win64 (64-bit)

## References

### Official Documentation
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2019)
- [Create an offline installation](https://docs.microsoft.com/en-us/visualstudio/install/create-an-offline-installation-of-visual-studio)
- [Use command-line parameters](https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio)

### Wine Resources
- [Wine HQ](https://www.winehq.org/)
- [Wine User's Guide](https://wiki.winehq.org/Wine_User%27s_Guide)
- [winetricks](https://github.com/Winetricks/winetricks)

## License

This project uses Microsoft Visual Studio Build Tools 2019, which is subject to Microsoft's license terms. Please review the license agreement before use.

The installation scripts (shell.nix, justfile) are provided as-is for educational and development purposes.
