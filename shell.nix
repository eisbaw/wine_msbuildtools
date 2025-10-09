{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "wine-buildtools";

  buildInputs = with pkgs; [
    # WINE and dependencies
    wineWow64Packages.full  # Full 64-bit Wine with 32-bit support
    winetricks

    # Additional utilities that might be needed
    cabextract
    p7zip
    unzip

    # Useful for debugging
    file
    which
  ];

  # Set up environment variables for local wineprefix
  WINEARCH = "win64";

  # Disable Wine debugging output by default (can be overridden)
  WINEDEBUG = "-all";

  shellHook = ''
    # Set WINEPREFIX to absolute path
    export WINEPREFIX="$(pwd)/.wine"

    # Fix for winetricks: Create wine64 symlink if it doesn't exist
    WINE_BIN_DIR="$(dirname $(which wine))"
    if [ ! -e "$WINE_BIN_DIR/wine64" ]; then
      mkdir -p "$WINEPREFIX/bin-fix"
      ln -sf "$WINE_BIN_DIR/wine" "$WINEPREFIX/bin-fix/wine64"
      export PATH="$WINEPREFIX/bin-fix:$PATH"
    fi

    # Initialize wineprefix if it doesn't exist
    if [ ! -d "$WINEPREFIX" ]; then
      echo "Initializing 64-bit WINE prefix at $WINEPREFIX..."
      wineboot --init

      # Wait for wineserver to finish initialization
      wineserver --wait

      echo "WINE prefix initialized successfully."
    fi

    # Helper functions
    install_buildtools() {
      echo "Starting Microsoft Build Tools 2019 installation..."
      wine visualstudio_buildtools/2019/vs_buildtools.exe
    }

    run_confirm() {
      echo "Running confirmation script..."
      wine cmd /c "cd visualstudio_buildtools\\2019 && confirm.bat"
    }

    # Show available commands
    echo ""
    echo "Environment ready. Available commands:"
    echo "  install_buildtools - Install Microsoft Build Tools 2019"
    echo "  run_confirm       - Run the confirmation script"
    echo "  winecfg          - Open Wine configuration"
    echo "  winetricks       - Run winetricks for additional Windows components"
    echo ""
    echo "Wine prefix location: $WINEPREFIX"
    echo "Wine architecture: $WINEARCH"
    echo "wine64 symlink: $(which wine64)"
  '';
}