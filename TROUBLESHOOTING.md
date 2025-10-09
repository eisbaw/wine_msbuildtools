# Troubleshooting Guide: VS Build Tools 2019 in Wine

This document details the specific issues encountered and solutions applied during the installation of Visual Studio Build Tools 2019 in Wine.

## Issue Resolution Timeline

### Issue #1: WPF Graphics Initialization Failure

**Error Code:** `0x88980406` (`WGXERR_UCE_MALFORMEDPACKET`)

**Symptoms:**
- Installer exits with code `0x138a` (5002 decimal)
- Log shows: `Error 0x88980406: General Failure`
- Occurs during `System.Windows.Window.ShowDialog()`

**Root Cause:**
Visual Studio installer uses Windows Presentation Foundation (WPF) for its UI, which requires DirectX/graphics rendering capabilities. Wine's implementation of DirectX/WPF is incomplete, causing the graphics subsystem to fail when the installer tries to show dialogs.

**Location in logs:**
```
.wine/drive_c/users/mpedersen/Temp/dd_bootstrapper_*.log
[0114:0001] Error 0x88980406: General Failure.
Message:Exception from HRESULT: 0x88980406
Callstack: at System.Windows.Media.Composition.DUCE.Channel.SyncFlush()
```

**Solution:**
Use `--quiet` flag instead of `--passive`:
```bash
# ✗ Wrong - tries to show UI
wine vs_buildtools.exe --passive ...

# ✓ Correct - skips all UI
wine vs_buildtools.exe --quiet ...
```

**Why this works:**
- `--passive`: Shows minimal UI, still initializes WPF window
- `--quiet`: No UI at all, skips WPF initialization entirely

---

### Issue #2: Environment Variable Case Conflict

**Error Code:** `0x80070057` (ERROR_INVALID_PARAMETER)

**Symptoms:**
- Installer exits with code `0x138a` (5002 decimal)
- Error about duplicate dictionary keys
- Log shows: `Item has already been added. Key in dictionary: 'shell' Key being added: 'SHELL'`

**Root Cause:**
Wine exposes both Linux environment variables (case-sensitive) and Windows environment variables (case-insensitive). The `SHELL` variable exists in Linux, but Wine also tries to create a lowercase `shell` variable for Windows compatibility. When the .NET installer tries to build its environment dictionary (which is case-insensitive), it encounters both `SHELL` and `shell`, causing a duplicate key exception.

**Location in logs:**
```
.wine/drive_c/users/mpedersen/Temp/dd_bootstrapper_*.log
[0114:0007] Error 0x80070057: Couldn't launch setup process.
Error: Item has already been added. Key in dictionary: 'shell'  Key being added: 'SHELL'
at System.Collections.Hashtable.Insert(Object key, Object nvalue, Boolean add)
at System.Collections.Hashtable.Add(Object key, Object value)
at System.Collections.Specialized.StringDictionaryWithComparer.Add(String key, String value)
at System.Diagnostics.ProcessStartInfo.get_EnvironmentVariables()
```

**Solution:**
Unset `SHELL` before running the installer:
```bash
# ✗ Wrong - SHELL conflicts
wine vs_buildtools.exe ...

# ✓ Correct - SHELL unset
unset SHELL && wine vs_buildtools.exe ...
```

**Why this works:**
Removing the `SHELL` environment variable before launching Wine prevents it from being duplicated in the Windows environment, avoiding the case-sensitivity conflict.

---

### Issue #3: Layout Path Length Restriction

**Error Code:** `0x138f` (5007 decimal)

**Symptoms:**
- Error message: "The source layout directory is too long"
- Message: "The layout directory name must be less than 80 characters"

**Root Cause:**
The Visual Studio installer has a hardcoded 80-character limit on layout paths. Wine's Z:\ drive mapping creates long paths like:
```
Z:\home\mpedersen\nvidia\retimer_sdk-windows-vm\packages\.wine\drive_c\vs_buildtools_2019_layout
```
This path is 89 characters, exceeding the limit.

**Location in logs:**
```
.wine/drive_c/users/mpedersen/Temp/dd_bootstrapper_*.log
[0114:0001] Error: The source layout directory is too long.
The layout directory name must be less than 80 characters.
```

**Solution:**
Use a short C: drive path:
```bash
# ✗ Wrong - path too long (89 chars)
wine vs_buildtools.exe --layout "Z:\home\mpedersen\...\vs_buildtools_2019_layout"

# ✓ Correct - short path (11 chars)
wine vs_buildtools.exe --layout "C:\vslayout"
```

Then move the layout to `.wine/drive_c/vslayout` which appears as `C:\vslayout` in Wine.

**Why this works:**
The C: drive path is measured from the Windows perspective, not the Linux filesystem path. `C:\vslayout` is only 11 characters.

---

### Issue #4: Relative Path Not Supported

**Error Code:** `0x80070057` (ERROR_INVALID_PARAMETER)

**Symptoms:**
- Error message: "--layout does not support relative paths"
- Installer rejects Linux-style paths

**Root Cause:**
The `--layout` parameter requires an absolute Windows path. It does not accept:
- Relative paths (`./layout`, `../layout`)
- Linux absolute paths (`/home/user/layout`)
- Wine Z: drive paths with Linux structure

**Location in logs:**
```
.wine/drive_c/users/mpedersen/Temp/dd_bootstrapper_*.log
[0114:0001] Error 0x80070057: Please provide a fully qualified path.
LayoutLocation:'/home/mpedersen/nvidia/retimer_sdk-windows-vm/packages/...'
[0114:0001] Error 0x80070057: General Failure.
Message:--layout does not support relative paths.
```

**Solution:**
Always use Windows absolute paths with drive letters:
```bash
# ✗ Wrong - relative path
wine vs_buildtools.exe --layout "$(pwd)/offline_layout"

# ✗ Wrong - Linux absolute path
wine vs_buildtools.exe --layout "/home/user/layout"

# ✗ Wrong - Wine Z: with Linux path
wine vs_buildtools.exe --layout "Z:\home\user\layout"

# ✓ Correct - Windows C: path
wine vs_buildtools.exe --layout "C:\vslayout"
```

**Why this works:**
The installer validates paths using Windows path rules, which require a drive letter (C:, D:, etc.) and backslashes.

---

### Issue #5: Invalid `--wait` Parameter

**Error Code:** `87` (ERROR_INVALID_PARAMETER)

**Symptoms:**
- Error message: "Option 'wait' is unknown"
- Installer shows all valid command-line options
- Exit code 87 (not 0x138a)

**Root Cause:**
The `--wait` flag was valid in older VS installer versions but was removed in VS 2019. Some documentation and examples still reference it, causing confusion.

**Location in logs:**
```
.wine/drive_c/users/mpedersen/Temp/dd_installer_*.log
[0120:0001] Warning: Closing the installer with exit code 87
[0120:0009] Warning: Command line errors:
Option 'wait' is unknown.
[0120:0001] Warning: Failed to parse the command line arguments:
Option 'wait' is unknown.
```

**Solution:**
Remove `--wait` from command line:
```bash
# ✗ Wrong - --wait not supported
wine vs_buildtools.exe --quiet --norestart --wait ...

# ✓ Correct - no --wait
wine vs_buildtools.exe --quiet --norestart ...
```

**Why this works:**
The installer behavior is already synchronous with `--quiet` or `--passive`, making `--wait` unnecessary and causing it to be removed from supported parameters.

---

### Issue #6: Certificate Validation (Red Herring)

**Error Code:** `0x138a` (5002 decimal)

**Initial Hypothesis:**
Error code 5002 typically indicates certificate validation failure. Research suggested the DigiCert Trusted Root G4 certificate might be missing.

**Investigation Results:**
Checked Wine's certificate store and found the required certificate **WAS present**:
```bash
wine regedit /E /tmp/certs.txt "HKEY_LOCAL_MACHINE\Software\Microsoft\SystemCertificates\ROOT\Certificates"
grep -i "DDFB16CD4931C973A2037D3FC83A4D7D775D05E4" /tmp/certs.txt
# Certificate found - not the issue!
```

**Actual Cause:**
Error code 0x138a was a generic failure code that masked the real issues (WPF initialization, environment variables, path problems). Once those were fixed, the "certificate error" disappeared.

**Lesson Learned:**
Error code 0x138a is a catch-all failure code for the VS installer. Always check the detailed logs (`dd_bootstrapper_*.log`) for the specific error message, not just the exit code.

---

## Complete Working Solution

Combining all fixes, here's the complete working command sequence:

### Stage 1: Create Offline Layout

```bash
nix-shell --run "unset SHELL && wine visualstudio_buildtools/2019/vs_buildtools.exe \
    --layout 'C:\vslayout' \
    --lang en-US \
    --add Microsoft.VisualStudio.Workload.VCTools \
    --includeRecommended \
    --includeOptional \
    --quiet"
```

**Key fixes applied:**
- ✅ `unset SHELL` - Fixes case conflict
- ✅ `--layout "C:\vslayout"` - Short Windows path (<80 chars)
- ✅ `--quiet` - Skips WPF UI
- ❌ No `--wait` - Removed unsupported flag
- ✅ Windows path format - Not Linux paths

### Stage 2: Install from Layout

```bash
nix-shell --run "unset SHELL && wine .wine/drive_c/vslayout/vs_buildtools.exe \
    --quiet \
    --norestart \
    --noweb \
    --add Microsoft.VisualStudio.Workload.VCTools \
    --includeRecommended \
    --includeOptional"
```

**Key fixes applied:**
- ✅ `unset SHELL` - Fixes case conflict
- ✅ `--quiet` - Skips WPF UI
- ✅ `--noweb` - Uses only offline layout
- ❌ No `--wait` - Removed unsupported flag

---

## Success Indicators

### Successful Layout Download

**Expected output:**
```
[10/9/2025, 18:19:32] Launched extracted application exiting with result code: 0x0
```

**Verification:**
```bash
ls -lh .wine/drive_c/vslayout/
# Should show ~5GB of content with Catalog.json, ChannelManifest.json, etc.

du -sh .wine/drive_c/vslayout/
# Should show approximately 4.9G
```

### Successful Installation

**Expected in logs:**
```
[017c:003b] Shutting down the application with exit code 0
[017c:0001] Closing the installer with exit code 0
[017c:0001] Exit Code: 0
```

**Verification:**
```bash
# Check for vcvarsall.bat
find .wine/drive_c -name "vcvarsall.bat"
# Should find: .wine/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat

# Run confirmation
nix-shell --run 'wine cmd /c "cd visualstudio_buildtools\\2019 && confirm.bat"'
# Should show: "Environment initialized for: 'x64'"
```

---

## Diagnostic Commands

### Check Wine Processes
```bash
nix-shell --run "wineserver -w"  # Wait for all processes to finish
nix-shell --run "wineserver -k"  # Kill all Wine processes
```

### View Recent Logs
```bash
ls -ltr .wine/drive_c/users/mpedersen/Temp/dd_*.log | tail -10
```

### Check Installation Size
```bash
du -sh .wine/drive_c/vslayout/                                              # Layout
du -sh ".wine/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/"   # Install
```

### Verify Components
```bash
# Check for key files
ls ".wine/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Tools/MSVC/"
ls ".wine/drive_c/Program Files (x86)/Windows Kits/10/Include/"
```

---

## Lessons Learned

1. **Error codes can be misleading**: Exit code 0x138a masked multiple different issues. Always check detailed logs.

2. **WPF is incompatible with Wine**: Any UI mode (`--passive`, without flags) will fail due to WPF graphics issues. Always use `--quiet`.

3. **Environment variables matter**: Wine's bridging between Linux and Windows environments can cause unexpected conflicts.

4. **Path handling is strict**: VS installer has specific requirements for path format and length that Wine's path translation can violate.

5. **Documentation can be outdated**: Official VS documentation still references `--wait`, which is no longer supported.

6. **Two-stage installation is required**: Direct installation hangs on network downloads in Wine. Creating an offline layout first, then installing from it, is the only reliable approach.

7. **Wine limitations**: While Wine worked for this installation, it has fundamental limitations with Windows services and GUI applications. For production use, consider a full Windows VM.
