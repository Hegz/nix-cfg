# Flake configuration

{
  description = "Systems configuration flake";
  
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Nix User Repository
    nur.url = "github:nix-community/NUR";

    valheim-server = {
      url = "github:aidalgol/valheim-server-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    valheim-server,
    nur,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      #"aarch64-linux"
      #"i686-linux"
      "x86_64-linux"
      #"aarch64-darwin"
      #"x86_64-darwin"
    ];

    # Read in secrets
    secrets = builtins.fromJSON (builtins.readFile "${self}/secrets/secrets.json");

    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    # packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;

    # NixOS configuration entrypoints
    # Available through 'nixos-rebuild --flake .#hostname'
    nixosConfigurations = {
      Embiggen = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main nixos configuration file <
          ./nixos/Embiggen/configuration.nix
          valheim-server.nixosModules.default
        ];
      };
      cromulent = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main nixos configuration file <
          ./nixos/Cromulent/configuration.nix
    	];
      };
      HePhaestus = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main nixos configuration file <
          ./nixos/HePhaestus/configuration.nix
        ];
      };
      SecUnit = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main nixos configuration file <
          ./nixos/SecUnit/configuration.nix
	      home-manager.nixosModules.home-manager

        ];
      };
      MCP = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main nixos configuration file <
          ./nixos/MCP/configuration.nix
          home-manager.nixosModules.home-manager
        ];
      };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      # FIXME replace with your username@hostname
      "adam@Embiggen" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/adam.nix
        ];
      };
      "adam@MCP" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/adam.nix
        ];
      };
      "adam@SecUnit" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/adam.nix
        ];
      };
      "afairbrother@Cromulent" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/afairbrother.nix
        ];
      };
      "afairbrother@HePhaestus" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs secrets;};
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/afairbrother.nix
        ];
      };
    };
  };
}
