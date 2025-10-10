# Justfile Usage Guide

The `justfile` provides convenient commands for installing and testing VS Build Tools 2019 in Wine.

## Prerequisites

Install `just` command runner (if not already available):
```bash
nix-shell -p just
```

## Quick Start

For a complete installation from scratch:
```bash
just full-install
```

This will run all steps in order:
1. Install .NET Framework 4.8 (prerequisites)
2. Download offline layout (~5GB)
3. Install Build Tools from layout
4. Run demo compilation

## Step-by-Step Installation

### 1. Install Prerequisites
```bash
just prerequisites
```
Installs .NET Framework 4.8 via winetricks (required, takes 5-15 minutes).

### 2. Download Offline Layout
```bash
just download
```
Downloads ~5GB offline installation layout (takes 10-30 minutes).

### 3. Install Build Tools
```bash
just install
```
Installs Build Tools from the downloaded layout.

### 4. Verify Installation
```bash
just demo
```
Compiles and runs a test C program to verify the toolchain works.

## Utility Commands

### Check Installation Status
```bash
just status
```
Shows which components are installed and disk usage.

### View Compiler Information
```bash
just compiler-info
```
Shows MSVC compiler version and help.

### List Installed Tools
```bash
just list-tools
```
Lists all MSVC executables (cl.exe, link.exe, etc.).

### Check Installer Logs
```bash
just check-logs
```
Shows recent installer log files for troubleshooting.

### Clean Up Wine Processes
```bash
just clean-wine
```
Kills background Wine processes (useful if something hangs).

### Delete Everything (Nuclear Option)
```bash
just clean-all
```
**WARNING:** Deletes the entire Wine prefix. You'll need to reinstall everything.

## Available Commands

Run `just` or `just --list` to see all available commands:

```
Available recipes:
    check-logs     # Check recent installer logs
    clean-all      # Delete entire Wine prefix (WARNING: destructive!)
    clean-wine     # Clean up Wine background processes
    compiler-info  # Show compiler version and help
    default        # Show available commands
    demo           # Demonstrate Build Tools work by compiling test program
    download       # Download VS Build Tools offline layout (~5GB, 10-30 minutes)
    full-install   # Full installation: prerequisites -> download -> install -> demo
    info           # Show Wine prefix information
    install        # Install Build Tools (downloads layout if needed)
    list-tools     # List installed MSVC tools
    prerequisites  # Install .NET Framework 4.8 (REQUIRED before download/install)
    status         # Show installation status and disk usage
    winecfg        # Open Wine configuration
```

## Example Workflow

### Fresh Installation
```bash
# Check what's installed
just status

# Install everything
just full-install

# Check status again
just status
```

### Manual Step-by-Step
```bash
# Step 1: Prerequisites
just prerequisites

# Step 2: Download
just download

# Check status
just status

# Step 3: Install
just install

# Step 4: Test
just demo
```

### After Installation
```bash
# Verify everything works
just demo

# Show compiler info
just compiler-info

# List all tools
just list-tools

# Check disk usage
just status
```

### Troubleshooting
```bash
# Check installer logs
just check-logs

# View Wine information
just info

# Kill hung processes
just clean-wine

# Start over (nuclear option)
just clean-all
```

## Tips

1. **First time?** Run `just full-install` and go get coffee (takes 30-60 minutes)

2. **Already have .wine directory?** Run `just status` to see what's already installed

3. **Something went wrong?** Run `just check-logs` to see installer errors

4. **Want to start fresh?** Run `just clean-all` then `just full-install`

5. **Need just the demo?** Already installed? Run `just demo` to test

## Notes

- All commands should be run from the `wine_msbuildtools` directory
- The Wine prefix is created at `./.wine/` (not system-wide)
- Total disk usage after full install: ~8-10GB
- Download requires internet connection
- .NET Framework 4.8 is a critical prerequisite - don't skip it!
