# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a NixOS flake-based configuration repository for managing multiple hosts. The configuration uses a modular architecture with the following key components:

### Repository Structure
- **flake.nix**: Main flake entry point defining nixosConfigurations for multiple hosts
- **hosts/**: Host-specific configurations and hardware definitions
  - **common.nix**: Shared configuration imported by all hosts
  - **{hostname}/configuration.nix**: Host-specific system configurations
  - **{hostname}/hardware-configuration.nix**: Hardware-specific settings (auto-generated)
- **modules/**: Reusable configuration modules
  - **system/**: System-level modules (agenix, greetd, keyd, virtualisation, etc.)
  - **home-manager/**: User environment configurations and dotfiles
- **secrets/**: Age-encrypted secrets managed by agenix

### Host Architecture
The flake defines four main hosts:
- **intelNuc**: Desktop system (x86_64-linux, isNotebook=false)
- **t480s**: ThinkPad laptop (x86_64-linux, isNotebook=true)  
- **spectre**: HP Spectre laptop (x86_64-linux, isNotebook=true)
- **devPi**: Raspberry Pi development device (aarch64-linux)

Each host configuration receives special arguments:
- `host`: hostname string for conditional logic
- `isNotebook`: boolean for laptop-specific settings
- `inputs`: flake inputs for accessing external packages

### Home Manager Integration
User environments are managed through home-manager with modular configurations:
- Desktop environment: Sway + Waybar + Rofi
- Terminal: Kitty with Nushell shell
- Editor: Helix as primary editor
- File manager: Yazi (terminal) + Nemo (GUI)
- Applications: Firefox, Brave, Thunderbird, Obsidian, etc.

## Common Commands

### System Rebuild Operations
```bash
# Build and switch to new configuration (most common)
sudo nixos-rebuild switch --flake .

# Build and switch for specific host
sudo nixos-rebuild switch --flake .#hostname

# Test configuration without making it default
sudo nixos-rebuild test --flake .

# Build configuration without activating
sudo nixos-rebuild build --flake .

# Show what would be built/changed
sudo nixos-rebuild dry-build --flake .
sudo nixos-rebuild dry-activate --flake .
```

### Development and Validation
```bash
# Check flake syntax and evaluate outputs
nix flake check

# Update flake lock file
nix flake update

# Update specific input
nix flake update nixpkgs

# Enter development shell with flake packages
nix develop

# Build specific output
nix build .#nixosConfigurations.hostname.config.system.build.toplevel
```

### System Management
```bash
# List system generations
sudo nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild --rollback switch

# Garbage collection
sudo nix-collect-garbage -d

# Optimize nix store
sudo nix-store --optimise
```

### Secrets Management (agenix)
```bash
# Edit encrypted secret
agenix -e secrets/secret-name.age

# Re-key secrets after adding new host
agenix -r
```

## Development Patterns

### Adding New Hosts
1. Create `hosts/new-hostname/` directory
2. Add `configuration.nix` and `hardware-configuration.nix`
3. Update `flake.nix` nixosConfigurations with new host entry
4. Add host SSH key to `secrets/secrets.nix` for agenix access

### Module Organization
- System modules in `modules/system/` for OS-level functionality
- Home-manager modules in `modules/home-manager/` for user environment
- Use `host` and `isNotebook` arguments for host-specific conditional logic
- Import common.nix for shared system configuration

### Home Manager Patterns
- Each user gets a dedicated configuration file in `modules/home-manager/users/`
- Modular approach with separate files for applications (sway.nix, kitty.nix, etc.)
- Custom fonts placed in `modules/home-manager/fonts/`
- Configuration files for applications stored alongside .nix modules

### Hardware-Specific Configuration
- Power management for laptops (suspend-then-hibernate)
- Display output configuration per host
- Kernel parameters and module loading per device

This configuration emphasizes modularity, reproducibility, and host-specific customization while maintaining shared common functionality across all systems.