{ inputs, outputs, config, pkgs, lib, specialArgs, ... }:
let

  hostName   = "${config.networking.hostName}";
  private    = "/var/lib/private/${hostName}";
  #addressIP  = "${specialArgs.secret.${hostName}.wireguard.addressIP}";
  #addressDNS = "${specialArgs.secret.${hostName}.wireguard.addressDNS}";
  #publicKey  = "${specialArgs.secret.${hostName}.wireguard.publicKey}";
  #serverIP   = "${specialArgs.secret.${hostName}.wireguard.serverIP}";
  #port       = "${specialArgs.secret.${hostName}.wireguard.port}";

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
	  ${pkgs.tailscale}/bin/tailscale cert ${hostName}.taild7a71.ts.net
	  ${pkgs.coreutils}/bin/chown caddy ${hostName}.taild7a71.ts.net.*
	  ${pkgs.systemd}/bin/systemctl restart caddy.service
	'';
	serviceConfig = {
	  Type = "oneshot";
	  User = "root";
	};
  };

  services.caddy = {
	enable = true;
	virtualHosts."${hostName}.taild7a71.ts.net".extraConfig = ''
	 reverse_proxy http://localhost:9000
	 tls /var/lib/caddy/${hostName}.taild7a71.ts.net.crt /var/lib/caddy/${hostName}.taild7a71.ts.net.key {
	   protocols tls1.3
	   }
	 '';
  };
}
