{serverName}: {
  inputs,
  outputs,
  config,
  pkgs,
  lib,
  secrets,
  ...
}: let
  hostname = "insanecraft";
  # InsaneCraft modpack details:
  #   CurseForge project ID : 527180
  #   Latest version        : v1.3.1.1
  #   Minecraft version     : 1.12.2
  #   Mod loader            : Forge
  #
  # The systemd service below will call start.sh on every boot.
  dataDir = "/var/lib/insanecraft";
  jvmOpts = "-Xms4092M -Xmx8192M -Djava.net.preferIPv4Stack=true";
in {
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

    config = {
      config,
      pkgs,
      lib,
      ...
    }: {
      system.stateVersion = "24.05";

      nixpkgs.config.allowUnfree = true;

      networking = {
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {
          enable = true;
          # Minecraft game port + RCON
          allowedTCPPorts = [25565 25575];
          allowPing = true;
        };
        useHostResolvConf = lib.mkForce false;
      };
      services.resolved.enable = true;

      environment.systemPackages = with pkgs; [
        rcon
        jre8_headless
      ];

      # InsaneCraft runs via a Forge start.sh, so we manage it as a plain
      # systemd service instead of using services.minecraft-server.
      systemd.services.insanecraft = {
        description = "InsaneCraft Modpack Server (CurseForge #527180, v1.3.1.1)";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        serviceConfig = {
          Type = "simple";
          WorkingDirectory = dataDir;
          ExecStart = "${dataDir}/start.sh";
          # Pass JVM flags the same way services.minecraft-server does
          Environment = "JVMOPTS=${jvmOpts}";

          # Run as a dedicated user for safety
          User = "minecraft";
          Group = "minecraft";

          Restart = "on-failure";
          RestartSec = "30s";

          # Give the JVM enough time to flush world data on shutdown
          TimeoutStopSec = "60";
          KillSignal = "SIGTERM";
        };
      };

      # Create the minecraft user/group inside the container
      users.users.minecraft = {
        isSystemUser = true;
        group = "minecraft";
        home = dataDir;
      };
      users.groups.minecraft = {};

      # Write server.properties declaratively.
      # The Forge/InsaneCraft start.sh will pick this up on launch.
      environment.etc."minecraft-server.properties" = {
        target = "${lib.removePrefix "/" dataDir}/server.properties";
        text = ''
          server-port=25565
          difficulty=normal
          gamemode=survival
          max-players=5
          motd=Home insanecraft server!\n Play nice
          white-list=false
          allow-cheats=true
          level-name=fairly_good
          level-seed=good seed
          pvp=false
          enable-rcon=true
          rcon.password=${secrets.${serverName}.containers.${hostname}.rcon-pass}
          rcon.port=25575
        '';
      };
    };
  };
}
