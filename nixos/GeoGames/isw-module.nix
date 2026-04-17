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

    systemd = {
      packages = [ pkgs.isw ];
      services.isw = {
        wantedBy = [ "multi-user.target" ];
      };
    };
  };
}
