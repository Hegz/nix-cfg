# Flake configuration

{
  description = "System configuration flake";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-23.11";
    };
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      HePhaestus = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./HePhaestus.nix
        ];
      };
    };
  };
}
