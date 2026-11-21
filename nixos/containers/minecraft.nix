{serverName}: {
  inputs,
  outputs,
  config,
  pkgs,
  lib,
  secrets,
  ...
}: let
  hostname = "minecraft";

  # Fetch a mod jar. Run once with lib.fakeHash, copy the real hash from the error.
  mkMod = {
    name,
    url,
    hash ? lib.fakeHash,
  }:
    pkgs.fetchurl {
      inherit url hash;
      name = "${name}.jar";
    };
in {
  containers."${hostname}" = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {
      "/var/lib/minecraft" = {
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;
      };
    };

    config = {
      config,
      pkgs,
      lib,
      ...
    }: let
      # Add mods here.
      mods = [
        # (mkMod {
        #   name = "lithium";
        #   url = "https://cdn.modrinth.com/data/<project-id>/versions/<version-id>/<file>.jar";
        #   hash = "sha256-...";
        # })
      ];
    in {
      imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];
      nixpkgs.overlays = [inputs.nix-minecraft.overlay];

      system.stateVersion = "24.05";

      # allow unfree minecraft
      nixpkgs.config.allowUnfree = true;

      networking = {
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {
          enable = true;
        };
        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;
      };
      services.resolved.enable = true;

      environment.systemPackages = with pkgs; [
        rcon
      ];

      # Add service definitions here.
      services.minecraft-servers = {
        enable = true;
        eula = true;
        openFirewall = true;
        dataDir = "/var/lib/minecraft";

        servers.main = {
          enable = true;
          # Fabric is required for mods; match the version to your mods.
          package = pkgs.fabricServers.fabric-1_21_1;

          serverProperties = {
            server-port = 43000;
            difficulty = "normal";
            gamemode = "survival";
            max-players = 5;
            motd = "Home Minecraft server!\n Play nice";
            white-list = false;
            allow-cheats = true;
            level-name = "fairly_good";
            level-seed = "good seed";
            pvp = false;
            enable-rcon = true;
            "rcon.password" = "hunter2";
            "rcon.port" = 25575;
          };
          jvmOpts = "-Xms4092M -Xmx4092M -Djava.net.preferIPv4Stack=true";

          # Mods are symlinked from the store into <dataDir>/main/mods.
          symlinks = lib.mkIf (mods != []) {
            mods = pkgs.linkFarmFromDrvs "mods" mods;
          };
        };
      };
    };
  };
}
