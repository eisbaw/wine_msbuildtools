# Justfile for Wine MS Build Tools setup

# Variables
script_dir := justfile_directory()
wineprefix := script_dir + "/.wine"
layout_path := "C:\\vslayout"
vs_buildtools_exe := script_dir + "/visualstudio_buildtools/2019/vs_buildtools.exe"

# Default recipe - show available commands
default:
    @just --list

# Install prerequisites (.NET Framework 4.8) - REQUIRED before download/install
prerequisites:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Checking for .NET Framework 4.8..."
    if [ -f "{{wineprefix}}/dosdevices/c:/windows/dotnet48.installed.workaround" ]; then
        echo "✓ .NET Framework 4.8 already installed"
        exit 0
    fi

    echo "Installing .NET Framework 4.8 (this takes 5-15 minutes)..."
    winetricks -q dotnet48

    echo "✓ .NET Framework 4.8 installed successfully"

# Download VS Build Tools offline layout (~5GB, 10-30 minutes)
download:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check prerequisites
    if [ ! -f "{{vs_buildtools_exe}}" ]; then
        echo "ERROR: vs_buildtools.exe not found. Please ensure visualstudio_buildtools/2019/ directory exists." >&2
        exit 1
    fi

    # Initialize Wine if needed
    if [ ! -d "{{wineprefix}}" ]; then
        echo "Initializing Wine prefix..."
        wineboot --init
        wineserver --wait
    fi

    # Ensure .NET Framework 4.8 is installed
    if [ ! -f "{{wineprefix}}/dosdevices/c:/windows/dotnet48.installed.workaround" ]; then
        echo "ERROR: .NET Framework 4.8 not installed. Run 'just prerequisites' first." >&2
        exit 1
    fi

    # Check if layout already exists
    if [ -d "{{wineprefix}}/drive_c/vslayout" ]; then
        echo "Offline layout already exists"
        read -p "Re-download? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping download"
            exit 0
        fi
        rm -rf "{{wineprefix}}/drive_c/vslayout"
    fi

    # Download the offline layout
    echo "Downloading offline layout (this will take 10-30 minutes and download ~5GB)..."
    unset SHELL
    # Override WINEDEBUG to show errors and warnings
    WINEDEBUG="warn+all,err+all,fixme-all" wine "{{vs_buildtools_exe}}" \
        --layout "{{layout_path}}" \
        --lang en-US \
        --add Microsoft.VisualStudio.Workload.VCTools \
        --includeRecommended \
        --includeOptional \
        --quiet

    # Wait for all Wine processes to complete
    echo "Waiting for download to complete..."
    wineserver --wait

    if [ ! -d "{{wineprefix}}/drive_c/vslayout" ]; then
        echo "ERROR: Layout directory was not created" >&2
        exit 1
    fi

    layout_size=$(du -sh "{{wineprefix}}/drive_c/vslayout" | cut -f1)
    echo "Offline layout downloaded successfully (size: $layout_size)"

# Download VS Build Tools offline layout - MINIMAL (core tools only, less disk space)
download-minimal:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check prerequisites
    if [ ! -f "{{vs_buildtools_exe}}" ]; then
        echo "ERROR: vs_buildtools.exe not found. Please ensure visualstudio_buildtools/2019/ directory exists." >&2
        exit 1
    fi

    # Initialize Wine if needed
    if [ ! -d "{{wineprefix}}" ]; then
        echo "Initializing Wine prefix..."
        wineboot --init
        wineserver --wait
    fi

    # Ensure .NET Framework 4.8 is installed
    if [ ! -f "{{wineprefix}}/dosdevices/c:/windows/dotnet48.installed.workaround" ]; then
        echo "ERROR: .NET Framework 4.8 not installed. Run 'just prerequisites' first." >&2
        exit 1
    fi

    # Check if layout already exists
    if [ -d "{{wineprefix}}/drive_c/vslayout" ]; then
        echo "Offline layout already exists"
        read -p "Re-download? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping download"
            exit 0
        fi
        rm -rf "{{wineprefix}}/drive_c/vslayout"
    fi

    # Download the offline layout - MINIMAL (no --includeRecommended/Optional)
    echo "Downloading MINIMAL offline layout (core C++ tools only, smaller size)..."
    unset SHELL
    # Override WINEDEBUG to show errors and warnings
    WINEDEBUG="warn+all,err+all,fixme-all" wine "{{vs_buildtools_exe}}" \
        --layout "{{layout_path}}" \
        --lang en-US \
        --add Microsoft.VisualStudio.Workload.VCTools \
        --quiet

    # Wait for all Wine processes to complete
    echo "Waiting for download to complete..."
    wineserver --wait

    if [ ! -d "{{wineprefix}}/drive_c/vslayout" ]; then
        echo "ERROR: Layout directory was not created" >&2
        exit 1
    fi

    layout_size=$(du -sh "{{wineprefix}}/drive_c/vslayout" | cut -f1)
    echo "Minimal offline layout downloaded successfully (size: $layout_size)"

# Install Build Tools (downloads layout if needed, then installs)
install:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check prerequisites
    if [ ! -f "{{vs_buildtools_exe}}" ]; then
        echo "ERROR: vs_buildtools.exe not found" >&2
        exit 1
    fi

    # Initialize Wine if needed
    if [ ! -d "{{wineprefix}}" ]; then
        echo "Initializing Wine prefix..."
        wineboot --init
        wineserver --wait
    fi

    # Download layout if it doesn't exist
    if [ ! -d "{{wineprefix}}/drive_c/vslayout" ]; then
        echo "Offline layout not found. Running download first..."
        just download
    fi

    # Check if already installed
    if [ -f "{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat" ]; then
        echo "Build Tools already installed"
        read -p "Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping installation"
            exit 0
        fi
    fi

    # Install from offline layout
    echo "Installing Build Tools from offline layout..."
    echo "Enabling Wine error output to diagnose issues..."

    unset SHELL
    set +e  # Don't exit on error, we want to check exit code
    # Override WINEDEBUG to show errors and warnings (shell.nix sets it to -all)
    WINEDEBUG="warn+all,err+all,fixme-all" wine "{{wineprefix}}/drive_c/vslayout/vs_buildtools.exe" \
        --quiet \
        --norestart \
        --noweb \
        --add Microsoft.VisualStudio.Workload.VCTools \
        --includeRecommended \
        --includeOptional
    installer_exit_code=$?
    set -e

    # Wait for all Wine processes to complete (installer spawns background processes)
    echo "Waiting for installer to complete..."
    wineserver --wait

    # Give filesystem time to sync (especially important in CI)
    sleep 5

    # Check installer exit code
    echo "Installer exit code: $installer_exit_code"
    if [ $installer_exit_code -ne 0 ]; then
        echo "WARNING: Installer returned non-zero exit code: $installer_exit_code"
        echo "Checking logs for errors..."
        tail -100 "{{wineprefix}}/drive_c/users/"*/Temp/dd_setup_*.log 2>/dev/null | grep -i "error" || true
        tail -100 "{{wineprefix}}/drive_c/users/"*/Temp/dd_installer_*.log 2>/dev/null | grep -i "error" || true
    fi

    # Verify installation
    vcvarsall="{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat"
    if [ ! -f "$vcvarsall" ]; then
        echo "ERROR: Installation verification failed: vcvarsall.bat not found" >&2
        echo "Checking what was installed..."
        ls -la "{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/" 2>/dev/null || echo "No BuildTools directory found"
        echo ""
        echo "Checking recent logs..."
        ls -ltr "{{wineprefix}}/drive_c/users/"*/Temp/dd_*.log 2>/dev/null | tail -5 || echo "No logs found"
        exit 1
    fi

    # Cleanup
    wineserver -k 2>/dev/null || true

    echo ""
    echo "================================================================"
    echo "Installation completed successfully!"
    echo "================================================================"
    echo ""
    echo "Build Tools location:"
    echo "  {{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/"
    echo ""
    echo "To verify, run: just demo"

# Install Build Tools - MINIMAL (core tools only, less disk space)
install-minimal:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check prerequisites
    if [ ! -f "{{vs_buildtools_exe}}" ]; then
        echo "ERROR: vs_buildtools.exe not found" >&2
        exit 1
    fi

    # Initialize Wine if needed
    if [ ! -d "{{wineprefix}}" ]; then
        echo "Initializing Wine prefix..."
        wineboot --init
        wineserver --wait
    fi

    # Download layout if it doesn't exist
    if [ ! -d "{{wineprefix}}/drive_c/vslayout" ]; then
        echo "Offline layout not found. Running minimal download first..."
        just download-minimal
    fi

    # Check if already installed
    if [ -f "{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat" ]; then
        echo "Build Tools already installed"
        read -p "Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping installation"
            exit 0
        fi
    fi

    # Install from offline layout - MINIMAL (no --includeRecommended/Optional)
    echo "Installing MINIMAL Build Tools from offline layout (core C++ tools only)..."
    echo "Enabling Wine error output to diagnose issues..."

    unset SHELL
    set +e  # Don't exit on error, we want to check exit code
    # Override WINEDEBUG to show errors and warnings (shell.nix sets it to -all)
    WINEDEBUG="warn+all,err+all,fixme-all" wine "{{wineprefix}}/drive_c/vslayout/vs_buildtools.exe" \
        --quiet \
        --norestart \
        --noweb \
        --add Microsoft.VisualStudio.Workload.VCTools
    installer_exit_code=$?
    set -e

    # Wait for all Wine processes to complete (installer spawns background processes)
    echo "Waiting for installer to complete..."
    wineserver --wait

    # Give filesystem time to sync (especially important in CI)
    sleep 5

    # Check installer exit code
    echo "Installer exit code: $installer_exit_code"
    if [ $installer_exit_code -ne 0 ]; then
        echo "WARNING: Installer returned non-zero exit code: $installer_exit_code"
        echo "Checking logs for errors..."
        tail -100 "{{wineprefix}}/drive_c/users/"*/Temp/dd_setup_*.log 2>/dev/null | grep -i "error" || true
        tail -100 "{{wineprefix}}/drive_c/users/"*/Temp/dd_installer_*.log 2>/dev/null | grep -i "error" || true
    fi

    # Verify installation
    vcvarsall="{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat"
    if [ ! -f "$vcvarsall" ]; then
        echo "ERROR: Installation verification failed: vcvarsall.bat not found" >&2
        echo "Checking what was installed..."
        ls -la "{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/" 2>/dev/null || echo "No BuildTools directory found"
        echo ""
        echo "Checking recent logs..."
        ls -ltr "{{wineprefix}}/drive_c/users/"*/Temp/dd_*.log 2>/dev/null | tail -5 || echo "No logs found"
        exit 1
    fi

    # Cleanup
    wineserver -k 2>/dev/null || true

    echo ""
    echo "================================================================"
    echo "MINIMAL installation completed successfully!"
    echo "================================================================"
    echo ""
    echo "Build Tools location:"
    echo "  {{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/"
    echo ""
    echo "To verify, run: just demo"

# Demonstrate Build Tools work by compiling and running a test program
demo:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== Verification Step 1: vcvarsall.bat ==="
    wine cmd /c "cd visualstudio_buildtools\\2019 && confirm.bat"

    echo ""
    echo "=== Verification Step 2: Compile Test Program ==="

    # Create test C program
    cat > /tmp/test.c << 'EOF'
    #include <stdio.h>

    int main() {
        printf("Hello from MSVC in Wine!\n");
        printf("Compiler: Microsoft Visual C++\n");
        printf("Test: PASSED\n");
        return 0;
    }
    EOF

    # Create compile script
    cat > /tmp/compile.bat << 'EOF'
    @echo off
    call "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
    cd /d Z:\tmp
    cl.exe test.c
    EOF

    echo "Compiling test.c with MSVC..."
    wine cmd /c 'Z:\tmp\compile.bat'

    echo ""
    echo "=== Verification Step 3: Run Compiled Program ==="
    wine /tmp/test.exe

    echo ""
    echo "✓ Demo completed successfully!"
    echo "✓ MSVC toolchain is fully functional in Wine"

# Full installation: prerequisites -> download -> install -> demo
full-install: prerequisites download install demo
    @echo ""
    @echo "=========================================="
    @echo "Full installation completed successfully!"
    @echo "=========================================="
    @echo ""
    @echo "Build Tools location:"
    @echo "  {{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/"
    @echo ""
    @echo "Quick start:"
    @echo "  just demo     - Run demo compilation"
    @echo "  just status   - Show installation status"

# Show installation status and disk usage
status:
    @echo "Installation Status:"
    @echo "===================="
    @echo ""
    @if [ -d "{{wineprefix}}" ]; then \
        echo "Wine prefix: ✓ EXISTS"; \
        du -sh "{{wineprefix}}"; \
    else \
        echo "Wine prefix: ✗ NOT FOUND"; \
    fi
    @echo ""
    @if [ -f "{{wineprefix}}/dosdevices/c:/windows/dotnet48.installed.workaround" ]; then \
        echo ".NET Framework 4.8: ✓ INSTALLED"; \
    else \
        echo ".NET Framework 4.8: ✗ NOT INSTALLED (run: just prerequisites)"; \
    fi
    @echo ""
    @if [ -d "{{wineprefix}}/drive_c/vslayout" ]; then \
        echo "Offline layout: ✓ EXISTS"; \
        du -sh "{{wineprefix}}/drive_c/vslayout"; \
    else \
        echo "Offline layout: ✗ NOT FOUND (run: just download)"; \
    fi
    @echo ""
    @if [ -f "{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat" ]; then \
        echo "Build Tools: ✓ INSTALLED"; \
        du -sh "{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools"; \
    else \
        echo "Build Tools: ✗ NOT INSTALLED (run: just install)"; \
    fi

# Clean up Wine background processes
clean-wine:
    @echo "Cleaning up Wine processes..."
    @wineserver -k 2>/dev/null || true

# Delete entire Wine prefix (WARNING: destructive!)
clean-all:
    @echo "WARNING: This will delete the entire Wine prefix ({{wineprefix}})"
    @echo "Press Ctrl+C to cancel, or Enter to continue..."
    @read -r
    rm -rf "{{wineprefix}}"
    @echo "✓ Wine prefix deleted"

# Show compiler version and help
compiler-info:
    @echo "MSVC Compiler Information:"
    @wine "{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Tools/MSVC/14.29.30133/bin/Hostx64/x64/cl.exe" /? | head -20

# List installed MSVC tools
list-tools:
    @echo "Installed MSVC tools (x64):"
    @find "{{wineprefix}}/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Tools/MSVC/14.29.30133/bin/Hostx64/x64" -type f -name "*.exe" 2>/dev/null | xargs basename -a | sort

# Check recent installer logs
check-logs:
    @echo "Recent installer logs:"
    @ls -ltr "{{wineprefix}}/drive_c/users/"*/Temp/dd_*.log 2>/dev/null | tail -10 || echo "No logs found"

# Dump full installer logs (for debugging failures)
dump-logs:
    #!/usr/bin/env bash
    echo "=== Bootstrapper Logs ==="
    tail -100 "{{wineprefix}}/drive_c/users/"*/Temp/dd_bootstrapper_*.log 2>/dev/null || echo "No bootstrapper logs"
    echo ""
    echo "=== Installer Logs ==="
    tail -100 "{{wineprefix}}/drive_c/users/"*/Temp/dd_installer_*.log 2>/dev/null || echo "No installer logs"
    echo ""
    echo "=== Setup Logs ==="
    tail -200 "{{wineprefix}}/drive_c/users/"*/Temp/dd_setup_*.log 2>/dev/null || echo "No setup logs"
    echo ""
    echo "=== Setup Error Logs ==="
    cat "{{wineprefix}}/drive_c/users/"*/Temp/dd_setup_*_errors.log 2>/dev/null || echo "No error logs"

# Show Wine prefix information
info:
    @echo "Wine prefix: {{wineprefix}}"
    @echo "Wine architecture: $WINEARCH"
    @echo "wine64: $(which wine64 2>/dev/null || echo 'not found')"

# Open Wine configuration
winecfg:
    @winecfg
