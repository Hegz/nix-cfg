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

  # Fetch a mod jar. Either give a CurseForge fileId + filename (CDN URL is built
  # for you) or a full url. Run once with lib.fakeHash, copy the real hash from the error.
  mkMod = {
    name,
    fileId ? null,
    filename ? null,
    url ? null,
    hash ? lib.fakeHash,
  }: let
    id = toString fileId;
    cfUrl = "https://mediafilez.forgecdn.net/files/${builtins.substring 0 4 id}/${builtins.substring 4 (-1) id}/${lib.escapeURL filename}";
  in
    pkgs.fetchurl {
      name = "${name}.jar";
      url =
        if url != null
        then url
        else cfUrl;
      inherit hash;
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
      # All files below are the Fabric builds for Minecraft 26.3.
      # Mine+ only exists for Fabric 26.3, which is what pins everything else.
      mods = [
        # Required by Mob Lootbags and Mine+ (Mine+ wants 0.162.0+26.3).
        # TODO: grab the real URL from the Fabric API page on Modrinth.
        (mkMod {
          name = "fabric-api";
          url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/<version-id>/fabric-api-0.162.0+26.3.jar";
        })

        (mkMod {
          name = "mob-loot-bags";
          fileId = 9680883;
          filename = "mob_loot_bags-fabric-26.3-2.0.3.jar";
        })

        (mkMod {
          name = "carry-on";
          fileId = 9524333;
          filename = "carryon-fabric-26.3-2.12.2.jar"; # filename unconfirmed
        })

        (mkMod {
          name = "simple-voice-chat";
          fileId = 9350669;
          filename = "voicechat-fabric-26.3-2.6.27.jar"; # filename unconfirmed
        })

        (mkMod {
          name = "structures-plus";
          fileId = 9394717;
          filename = "Structures+ v3.1.jar";
        })

        (mkMod {
          name = "mine-plus";
          fileId = 9156814;
          filename = "mineplus-1.1.0.jar";
        })
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
          # Simple Voice Chat
          allowedUDPPorts = [24454];
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
          # Fabric is required for mods; must match the mods' Minecraft version.
          package = pkgs.fabricServers.fabric-26_3;
          # 26.x needs Java 25.
          jvmPackage = pkgs.jdk25_headless;

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
