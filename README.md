# nix-cfg

Configuration files for multiple NixOS systems and Home Manager users.

## Overview

This project uses Nix Flakes to manage system configurations across multiple machines and users. It leverages NixOS, Home Manager, NUR (Nix User Repository), and custom overlays.

## Requirements

- [Nix](https://nixos.org/download.html) (Nix 2.18+ with flakes enabled)

## Quick Start

### Building a NixOS System

```bash
# Replace HOSTNAME with your target machine's hostname
nixos-rebuild switch --flake .#HOSTNAME

# For aarch64 systems (e.g., Raspberry Pi)
nixos-rebuild switch --flake .#HOSTNAME --system aarch64-linux
```

### Building a Home Manager Configuration

```bash
# Replace USER and HOSTNAME with your user and target machine
home-manager switch --flake ".#USER@HOSTNAME"

# For aarch64 systems
home-manager switch --flake ".#USER@HOSTNAME" --system aarch64-linux
```

### Using `nix shell`

```bash
# Enter a temporary shell with all dependencies
nix shell .

# Or specific packages if defined in pkgs/
nix shell .#package-name
```

## Directory Structure

```
nix-cfg/
├── flake.nix              # Main flake configuration
├── flake.lock             # Locked dependencies
├── README.md              # This file
├── nixos/                 # NixOS system configurations
│   ├── HOSTNAME/
│   │   ├── configuration.nix
│   │   └── ...
├── home-manager/          # Home Manager configurations
│   ├── username.nix
│   └── ...
├── modules/               # Reusable NixOS/Home Manager modules
│   ├── nixos/
│   └── home-manager/
├── overlays/              # Package overlays
├── pkgs/                  # Custom packages
├── patches/               # Nix patches
├── secrets/               # Sensitive configuration (encrypted)
│   └── secrets.json
├── Scripts/               # Helper scripts
├── distrobox/             # Distrobox container configs
└── unstable.nix           # Unstable package overrides
```

## Inputs

| Input | Source |
|-------|--------|
| `nixpkgs` | `nixos-25.11` (stable) |
| `nixpkgs-unstable` | `nixos-unstable` |
| `home-manager` | `release-25.11` |
| `nur` | Nix User Repository |
| `valheim-server` | Valheim server flake |

## Available Systems

### NixOS Configurations

- **Embiggen**, **cromulent**, **HePhaestus**, **SecUnit**, **MCP**, **GeoDude**, **GeoGames**, **Lenny**, **BackuPi**

### Home Manager Configurations

- `adam@Embiggen`, `adam@GeoGames`, `adam@MCP`, `adam@SecUnit`, `adam@BackuPi`
- `afairbrother@cromulent`, `afairbrother@HePhaestus`, `afairbrother@Lenny`

## Common Tasks

### Format Nix files

```bash
nix fmt
```

### View available outputs

```bash
nix flake show
```

### Debug/Shell

```bash
nix shell .#your-package
```

### Debug NixOS configuration

```bash
nixos-rebuild debug --flake .#HOSTNAME
```

## Secrets

Sensitive data is stored in `secrets/secrets.json`. Ensure proper permissions and backup this file.

## Custom Packages

See `pkgs/` for custom packages. Accessible via:

```bash
nix build .#packages.<system>.<package-name>
```

## Overlays

Custom package modifications are defined in `overlays/default.nix`.

## Modules

Reusable modules are exported from:
- `modules/nixos/` - NixOS modules
- `modules/home-manager/` - Home Manager modules

## License

See [LICENSE](LICENSE) file.

---

**Note**: This project uses Nix Flakes, which require Nix 2.18 or later with flakes enabled (`nix config set experimental-features nix-command flakes`).
