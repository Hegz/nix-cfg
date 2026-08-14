{ config, pkgs, lib, ... }:

{
  options.services.samba = {
    enable = lib.mkEnableOption "samba";

    workgroup = lib.mkOption {
      type = lib.types.str;
      default = "WORKGROUP";
      description = "SMB workgroup name.";
    };

    serverRole = lib.mkOption {
      type = lib.types.enum [
        "standalone"
        "member"
        "domain_member"
        "active_directory_domain_controller"
      ];
      default = "standalone";
      description = "Samba server role.";
    };

    globalSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional global smb.conf settings.";
    };

    # Each share is a NixOS submodule with these options:
    shares = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Share name.";
          };
          path = lib.mkOption {
            type = lib.types.str;
            description = "Absolute path to share.";
          };
          comment = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Human-readable description.";
          };
          browseable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Visible in network browse.";
          };
          read_only = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Read-only access.";
          };
          valid_users = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Usernames allowed to access this share.";
          };
          hosts_allow = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "IP addresses/subnets allowed.";
          };
          hosts_deny = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "IP addresses/subnets denied.";
          };
          guest_ok = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow guest access.";
          };
        };
      });
      default = {};
      description = "Map of share definitions.";
    };
  };

  config = lib.mkIf config.services.samba.enable {
    # Ensure samba package is available
    environment.systemPackages = lib.mkBefore (
      config.environment.systemPackages ++ [ pkgs.samba ]
    );

    # Enable smb service with global settings
    services.smbd = {
      enable = true;
      enableGuest = true;
      settings = {
        workgroup = config.services.samba.workgroup;
        "server role" = config.services.samba.serverRole;
      } // config.services.samba.globalSettings;
    };

    # Render share definitions into /etc/samba/smb.conf.d/
    environment.etc."samba/smb.conf.d" =
      builtins.listToAttrs (
        map (name: {
          name = "share-${name}";
          value = {
            source = builtins.toFile "share.conf" (
              let
                cfg = config.services.samba.shares.${name};
                path = cfg.path or "/srv";
                comment = cfg.comment or "";
                browseable = cfg.browseable or true;
                read_only = cfg.read_only or false;
                valid_users = cfg.valid_users or [];
                hosts_allow = cfg.hosts_allow or [];
                hosts_deny = cfg.hosts_deny or [];
                guest_ok = cfg.guest_ok or false;
              in
                lib.optionalString (comment != "") (
                  "## ${name}: ${comment}\n"
                ) +
                "[${name}]\n" +
                "    path = ${path}\n" +
                "    comment = ${comment}\n" +
                "    browseable = ${toString browseable}\n" +
                "    read only = ${toString read_only}\n" +
                (if valid_users != [] then
                  "    valid users = ${builtins.concatStringsSep " " valid_users}\n"
                else "") +
                (if hosts_allow != [] then
                  "    hosts allow = ${builtins.concatStringsSep " " hosts_allow}\n"
                else "") +
                (if hosts_deny != [] then
                  "    hosts deny = ${builtins.concatStringsSep " " hosts_deny}\n"
                else "") +
                (if guest_ok then
                  "    guest ok = yes\n"
                else "")
            );
          };
        })
          (builtins.attrNames config.services.samba.shares)
      );

    # Ensure share paths exist via systemd tmpfiles
    systemd.tmpfiles.rules =
      lib.mkBefore (
        config.systemd.tmpfiles.rules ++
        map (name: let
          cfg = config.services.samba.shares.${name};
          path = cfg.path or "/srv";
        in
          "d ${path} 0755 root root"
        )
          (builtins.attrNames config.services.samba.shares)
      );

    # Firewall — allow SMB
    networking.firewall.allowedTCPPorts =
      lib.mkBefore (
        config.networking.firewall.allowedTCPPorts ++ [
          445
          139
        ]
      );
    networking.firewall.allowedUDPPorts =
      lib.mkBefore (
        config.networking.firewall.allowedUDPPorts ++ [
          137
          138
        ]
      );
  };
}
