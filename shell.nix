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

    # Task runner
    just

    # Virtual X server for headless GUI apps
    xorg.xvfb
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
      wineboot --init
      wineserver --wait
    fi

    echo "Wine Build Tools environment ready. Run 'just' to see available commands."
  '';
}