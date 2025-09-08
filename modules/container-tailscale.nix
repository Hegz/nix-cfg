{ inputs, outputs, config, pkgs, lib, specialArgs, ... }:
{
  # Enable tailscale
  services.tailscale = {
    enable = true;
    interfaceName = "userspace-networking";
  };
}
