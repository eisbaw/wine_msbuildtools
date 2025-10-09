#!/usr/bin/env bash
#
# install_buildtools.sh - Install Microsoft Visual Studio Build Tools 2019 in Wine
#
# This script automates the installation of Visual Studio Build Tools 2019
# within a Wine environment on NixOS/Linux systems.
#
# Prerequisites:
#   - NixOS with shell.nix available
#   - Internet connection for downloading the offline layout (~5GB)
#   - Approximately 10GB of free disk space
#
# Usage:
#   ./install_buildtools.sh
#
# The script performs a two-stage installation:
#   Stage 1: Download the offline layout containing all installation packages
#   Stage 2: Install Build Tools from the offline layout
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT_PATH="C:\\vslayout"
WINEPREFIX_PATH="$SCRIPT_DIR/.wine"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
    exit 1
}

check_prerequisites() {
    log "Checking prerequisites..."

    if [ ! -f "$SCRIPT_DIR/shell.nix" ]; then
        error "shell.nix not found in $SCRIPT_DIR"
    fi

    if [ ! -f "$SCRIPT_DIR/visualstudio_buildtools/2019/vs_buildtools.exe" ]; then
        error "vs_buildtools.exe not found. Please ensure visualstudio_buildtools/2019/ directory exists."
    fi

    log "Prerequisites check passed"
}

initialize_wine() {
    log "Initializing Wine environment..."

    # The shell.nix handles Wine initialization automatically
    nix-shell --run "echo 'Wine environment initialized'" || error "Failed to initialize Wine environment"

    log "Wine environment ready at $WINEPREFIX_PATH"
}

download_offline_layout() {
    log "Stage 1: Downloading offline layout (this will take 10-30 minutes and download ~5GB)..."

    # Check if layout already exists
    if [ -d "$WINEPREFIX_PATH/drive_c/vslayout" ]; then
        log "Offline layout already exists at $WINEPREFIX_PATH/drive_c/vslayout"
        read -p "Do you want to re-download the layout? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Skipping layout download"
            return 0
        fi
        log "Removing existing layout..."
        rm -rf "$WINEPREFIX_PATH/drive_c/vslayout"
    fi

    # Download the offline layout
    # Key points:
    #   - unset SHELL: Avoids case-sensitivity conflict between 'SHELL' and 'shell' environment variables
    #   - --layout C:\vslayout: Uses short Windows path (must be <80 chars)
    #   - --quiet: Avoids WPF UI initialization errors in Wine
    #   - --lang en-US: English language only
    #   - --add Microsoft.VisualStudio.Workload.VCTools: C++ build tools workload
    #   - --includeRecommended --includeOptional: Include all components

    nix-shell --run "unset SHELL && wine visualstudio_buildtools/2019/vs_buildtools.exe \
        --layout \"$LAYOUT_PATH\" \
        --lang en-US \
        --add Microsoft.VisualStudio.Workload.VCTools \
        --includeRecommended \
        --includeOptional \
        --quiet" || error "Failed to download offline layout"

    # Verify layout was created
    if [ ! -d "$WINEPREFIX_PATH/drive_c/vslayout" ]; then
        error "Layout directory was not created"
    fi

    local layout_size=$(du -sh "$WINEPREFIX_PATH/drive_c/vslayout" | cut -f1)
    log "Offline layout downloaded successfully (size: $layout_size)"
}

install_buildtools() {
    log "Stage 2: Installing Build Tools from offline layout..."

    # Check if already installed
    if [ -f "$WINEPREFIX_PATH/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat" ]; then
        log "Build Tools appear to be already installed"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Skipping installation"
            return 0
        fi
    fi

    # Install from the offline layout
    # Key points:
    #   - unset SHELL: Avoids case-sensitivity conflict
    #   - --quiet: No UI (avoids WPF errors)
    #   - --norestart: Don't reboot after installation
    #   - --noweb: Use only offline layout, no internet downloads
    #   - Uses vs_buildtools.exe from the layout directory

    nix-shell --run "unset SHELL && wine .wine/drive_c/vslayout/vs_buildtools.exe \
        --quiet \
        --norestart \
        --noweb \
        --add Microsoft.VisualStudio.Workload.VCTools \
        --includeRecommended \
        --includeOptional" || error "Failed to install Build Tools"

    log "Build Tools installation completed"
}

verify_installation() {
    log "Verifying installation..."

    local vcvarsall="$WINEPREFIX_PATH/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvarsall.bat"

    if [ ! -f "$vcvarsall" ]; then
        error "Installation verification failed: vcvarsall.bat not found"
    fi

    log "Found vcvarsall.bat at: $vcvarsall"

    # Run the confirmation script
    log "Running confirmation script..."
    if nix-shell --run "wine cmd /c \"cd visualstudio_buildtools\\\\2019 && confirm.bat\"" 2>&1 | grep -q "Environment initialized"; then
        log "Installation verified successfully!"
        return 0
    else
        error "Installation verification failed: confirm.bat did not complete successfully"
    fi
}

cleanup_background_processes() {
    log "Cleaning up Wine processes..."
    nix-shell --run "wineserver -k" 2>/dev/null || true
}

main() {
    log "Starting Visual Studio Build Tools 2019 installation in Wine"
    log "Working directory: $SCRIPT_DIR"

    check_prerequisites
    initialize_wine
    download_offline_layout
    install_buildtools
    verify_installation
    cleanup_background_processes

    log "================================================================"
    log "Installation completed successfully!"
    log "================================================================"
    log ""
    log "Build Tools location:"
    log "  $WINEPREFIX_PATH/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/"
    log ""
    log "To use the build tools, run:"
    log "  nix-shell --run 'wine cmd /c \"C:\\\\Program Files (x86)\\\\Microsoft Visual Studio\\\\2019\\\\BuildTools\\\\VC\\\\Auxiliary\\\\Build\\\\vcvarsall.bat\" x64'"
    log ""
}

main "$@"
