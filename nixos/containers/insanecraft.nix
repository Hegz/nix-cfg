{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "minecraft";
  # InsaneCraft modpack details:
  #   CurseForge project ID : 527180
  #   Latest version        : v1.3.1.1
  #   Minecraft version     : 1.12.2
  #   Mod loader            : Forge
  #
  # One-time setup (run on the HOST before first boot):
  #   1. Download the InsaneCraft server pack from CurseForge:
  #        https://www.curseforge.com/minecraft/modpacks/insanecraft-modpack/files
  #      and extract it into /home/container/minecraft
  #   2. Inside that directory, run the Forge installer:
  #        java -jar forge-*-installer.jar --installServer
  #   3. Make sure start.sh is executable:
  #        chmod +x /home/container/minecraft/start.sh
  #
  # The systemd service below will call start.sh on every boot.
  dataDir = "/var/lib/minecraft";
  jvmOpts = "-Xms4092M -Xmx8192M -Djava.net.preferIPv4Stack=true";
in
{
  containers."${hostname}" = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {
      "${dataDir}" = {
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;
      };
    };

    config = {config, pkgs, lib, ... }: {
      system.stateVersion = "24.05";

      nixpkgs.config.allowUnfree = true;

      networking = {
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {
          enable = true;
          # Minecraft game port + RCON
          allowedTCPPorts = [ 43000 25575 ];
        };
        useHostResolvConf = lib.mkForce false;
      };
      services.resolved.enable = true;

      environment.systemPackages = with pkgs; [
        rcon
        # Java 8 is required for Minecraft 1.12.2 / Forge
        jre8_headless
      ];

      # InsaneCraft runs via a Forge start.sh, so we manage it as a plain
      # systemd service instead of using services.minecraft-server.
      systemd.services.insanecraft = {
        description = "InsaneCraft Modpack Server (CurseForge #527180, v1.3.1.1)";
        wantedBy    = [ "multi-user.target" ];
        after       = [ "network.target" ];

        serviceConfig = {
          Type             = "simple";
          WorkingDirectory = dataDir;
          ExecStart        = "${dataDir}/start.sh";
          # Pass JVM flags the same way services.minecraft-server does
          Environment      = "JVMOPTS=${jvmOpts}";

          # Run as a dedicated user for safety
          User             = "minecraft";
          Group            = "minecraft";

          Restart          = "on-failure";
          RestartSec       = "30s";

          # Give the JVM enough time to flush world data on shutdown
          TimeoutStopSec   = "60";
          KillSignal       = "SIGTERM";
        };
      };

      # Create the minecraft user/group inside the container
      users.users.minecraft = {
        isSystemUser = true;
        group        = "minecraft";
        home         = dataDir;
      };
      users.groups.minecraft = {};

      # Write server.properties declaratively.
      # The Forge/InsaneCraft start.sh will pick this up on launch.
      environment.etc."minecraft-server.properties" = {
        target = "${lib.removePrefix "/" dataDir}/server.properties";
        text = ''
          server-port=43000
          difficulty=normal
          gamemode=survival
          max-players=5
          motd=Home Minecraft server!\n Play nice
          white-list=false
          allow-cheats=true
          level-name=fairly_good
          level-seed=good seed
          pvp=false
          enable-rcon=true
          rcon.password=hunter2
          rcon.port=25575
        '';
      };
    };
  };
}
