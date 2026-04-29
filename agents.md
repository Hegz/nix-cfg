# 🤖 Agents Repository Architecture Documentation

## 📘 Overview and Project Purpose

This repository is a configuration "flake" that defines multiple, isolated, and specialized operating system environments (machines or "systems"). Each system—such as `SecUnit` (a security/media server), `GeoDude` (a personal desktop), or `BackuPi` (a backup machine)—is defined declaratively using Nix.

The primary purpose of this codebase is to provide **reproducibility and hermeticity**. Instead of installing software manually, a developer uses the Nix toolchain to build a complete, consistent system based on these configurations. It supports both large-scale server deployments (NixOS) and granular user desktop environments (Home Manager).

### Supported Tasks
This codebase supports the management of complex, customized Linux environments, including:
*   **Server Deployment:** Setting up media servers (e.g., Jellyfin, audiobookshelf), network appliances (DNSmasq, captive portal), and security/monitoring tools (Frigate, Netdata).
*   **Personal Desktop Customization:** Defining a user's complete toolchain, including shell (Zsh), editor (Vim), workflow tools (Tmux), and version control (Git).
*   **System Provisioning:** Deploying entire OS profiles (NixOS) and user profiles (Home Manager) across different hardware and roles.

---

## 💻 Primary Technologies and Dependencies

| Component | Technology | Role |
| :--- | :--- | :--- |
| **Core Language** | Nix | The language used to define and manage the entire system state. |
| **System Manager** | NixOS | Used to configure the entire operating system, kernel settings, networking, services, and hardware features. |
| **User Manager** | Home Manager | Used to manage user-specific settings, dotfiles, applications, and environment variables *on top* of NixOS. |
| **Configuration Tool** | Flakes | The modern Nix mechanism (`flake.nix`) used to aggregate, manage dependencies, and provide standardized entry points for all defined systems. |
| **Dependencies** | Nixpkgs, Home-Manager | These act as the vast package repositories and module libraries from which all system components and applications are pulled. |

---

## 📁 Directory and File Structure Breakdown

The structure is organized around the principle of **Composition**. Components are rarely written from scratch; instead, they are defined as modules and imported into a final configuration.

*   **`flake.nix` (Entry Point):** The root definition file. It serves as the central hub, importing core packages, defining all available systems (`nixosConfigurations`), and linking them to the specific configuration files (e.g., `nixos/GeoDude/configuration.nix`).
*   **`nixos/` (System Configurations):** Contains the definitions for complete operating systems.
    *   **`nixos/{SystemName}/configuration.nix`:** The main entry point for a specific machine profile. This file defines the kernel, hardware settings, global services (e.g., `services.netdata`), and network configuration for that entire system.
    *   **`nixos/users/{UserName}.nix`:** Defines user-specific accounts and initial setup for that system.
    *   **`nixos/containers/`:** Defines containerized services (e.g., Minecraft, JellyFin), ensuring these services run within a controlled, reproducible environment.
*   **`home-manager/` (User Profiles):** Contains configurations that apply only to a specific user.
    *   **`home-manager/{UserName}.nix`:** The main user profile wrapper, which delegates all specific tool configurations (Vim, Zsh, Git) to dedicated imported modules (e.g., `./vim.nix`).
*   **`modules/` (Reusable Features):** Stores abstract, reusable code blocks (e.g., `wireguard.nix`). These modules allow complex features—like VPN connectivity or specific service setups—to be dropped into any system configuration with minimal effort.
*   **`secrets/` (Security):** Stores sensitive configuration data (e.g., API keys, disk UUIDs) in JSON or specialized Nix files, which are read at build time and injected securely into the respective NixOS configurations.
*   **`pkgs/` (Custom Packages):** Used to define custom, specialized packages that may not exist in the main Nixpkgs repository (e.g., Appimage wrappers).

---

## ⚙️ Common Implementation Patterns

### 1. Declarative Composition (The Core Pattern)
The entire system is built via **composition** using the `imports` directive.
*   *Example:* A system's `configuration.nix` does not contain the code for DNSmasq; it simply imports `( import ./dnsmasq.nix { ip = accessPointIP; interface = apInterface; })`.
*   This allows for extreme flexibility: you can reuse a Wi-Fi module on a desktop system or an access-point system simply by importing it, while allowing local variables (like `apInterface`) to customize its behavior.

### 2. Secret and Environment Injection
Secrets are managed by defining a source file (`secrets/secrets.json`) and reading it into the flake at build time. This data is then injected into the configuration as a special `secrets` variable (e.g., `secrets.secunit.disk-uuid`). This ensures that sensitive data is never committed into the main configuration files but is available during the build process.

### 3. Network and Service Handling
Network services (like DHCP, VPN, and firewall rules) are managed declaratively.
*   **Firewall:** Rules are defined explicitly per interface (e.g., `interfaces."wlan-ap0".allowedUDPPorts = [67, 123];`).
*   **Services:** Services like Frigate are defined as encapsulated modules, which accept configuration parameters (like `hostName`) and manage the installation, configuration, and running state of the service.

### 4. State Management (User vs. System)
*   **System State (NixOS):** Managed globally via `nixos-rebuild --flake .#SystemName`. The state is the definition of the entire OS.
*   **User State (Home Manager):** Managed specifically for a user via `home-manager --flake .#user@system`. The state is the collection of user tools and environment variables.

---

## 🧭 How to Approach Tasks in This Codebase

When starting work, always ask: **"Is this a system-wide requirement, or a user-specific requirement?"**

| Task Type | Recommended Approach | Key Files/Modules |
| :--- | :--- | :--- |
| **New Server Feature (e.g., adding a new monitoring service)** | Define the service as a new, self-contained Nix module in `modules/`. Then, import this module into the target `nixos/{SystemName}/configuration.nix`. | `modules/`, `nixos/{SystemName}/configuration.nix` |
| **New User Tool (e.g., adding a specific VS Code extension)** | Define the tool configuration within the `home-manager/adam.nix` wrapper, or ideally, create a new module in `modules/home-manager/` and import it into `home-manager/adam.nix`. | `home-manager/adam.nix`, `modules/home-manager/` |
| **Configuration Change (e.g., changing a port)** | Locate the specific service configuration file (e.g., `nixos/SecUnit/configuration.nix`) and modify the relevant parameter. Use `secrets/` if the change involves credentials. | `nixos/{SystemName}/configuration.nix`, `secrets/` |
| **New Machine Profile (e.g., a dedicated VPN server)** | Create a new directory under `nixos/` (e.g., `nixos/VPNServer/`) and define a `configuration.nix` that imports the necessary networking modules (like `modules/wireguard.nix`). Then, add a new entry to `flake.nix`. | `nixos/`, `flake.nix`, `modules/` |