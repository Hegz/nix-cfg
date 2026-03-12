{port}: { inputs, outputs, config, pkgs, lib, specialArgs, ... }:
let

  hostName   = "${config.networking.hostName}";
  private    = "/var/lib/private/${hostName}";
  domain     = ${specialArgs.secret.tailnet.domain};

in
{
  systemd.timers."ssl-refresh" = {
	wantedBy = ["timers.target"];
	timerConfig = {
	  OnCalendar = "quarterly";
	  Persistent = true;
	  Unit = "ssl-refresh.service";
	};
  };
  
  systemd.services."ssl-refresh" = {
	script = ''
	  set -eu
	  cd /var/lib/caddy
	  ${pkgs.tailscale}/bin/tailscale cert ${lib.toLower hostName}.${domain}
	  ${pkgs.coreutils}/bin/chown caddy ${lib.toLower hostName}.${domain}.*
	  ${pkgs.systemd}/bin/systemctl restart caddy.service
	'';
	serviceConfig = {
	  Type = "oneshot";
	  User = "root";
	};
  };

  services.caddy = {
	enable = true;
	virtualHosts."${hostName}.${domain}".extraConfig = ''
	 reverse_proxy http://localhost:${port}
	 tls /var/lib/caddy/${lib.toLower hostName}.${domain}.crt /var/lib/caddy/${lib.toLower hostName}.${domain}.key {
	   protocols tls1.3
	   }
	 '';
  };
}
