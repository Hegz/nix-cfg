# File sourced from User Artturin https://github.com/NixOS/nixpkgs/issues/129954
# Updated with Claude

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.isw;
  defaultConf = "${pkgs.isw}/etc/isw.conf";
in
{
  options = {
    services.isw = {
      enable = mkEnableOption "msi laptop fan profile daemon";

      section = mkOption {
        type = types.str;
        description = ''
          The section name from isw.conf matching your laptop model,
          e.g. "16R2EMS1". Find yours by running: sudo isw -c
          and looking at the ASCII string near address 0xa0,
          or by checking the section headers in /etc/isw.conf.
        '';
      };

      configFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          The path to the <filename>isw.conf</filename> file. Leave
          to null to use the default config file included in the package
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.isw ];

    environment.etc."isw.conf".source =
      if cfg.configFile == null then defaultConf else cfg.configFile;

    boot.kernelModules = [ "ec_sys" ];
    boot.extraModprobeConfig = "options ec_sys write_support=1";

	systemd.services."isw@${cfg.section}" = {
      description = "ISW fan control service";
      wantedBy = [ "multi-user.target" "sleep.target" ];
      after = [ "multi-user.target" "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
        ExecStart = "${pkgs.isw}/bin/isw -w ${cfg.section}";
      };
    };
  };
}
