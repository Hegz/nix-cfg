{ inputs, outputs, config, pkgs, lib, specialArgs, ... }:
let

  hostName   = "${config.networking.hostName}";
  keySource  = ../secrets/wireguard/${hostName}.key;
  addressIP  = "${specialArgs.secret.${hostName}.wireguard.addressIP}";
  addressDNS = "${specialArgs.secret.${hostName}.wireguard.addressDNS}";
  publicKey  = "${specialArgs.secret.${hostName}.wireguard.publicKey}";
  serverIP   = "${specialArgs.secret.${hostName}.wireguard.serverIP}";
  port       = "${specialArgs.secret.${hostName}.wireguard.port}";

in
{
  environment.etc = {
    wgKey.source = "${keySource}";
  };

  networking.wg-quick.interfaces = {
    wg0 = {
      # IP address of this machine in the *tunnel network*
      address = [ "${addressIP}" ];
      dns = [ "${addressDNS}" ];

      autostart = true;

      listenPort = lib.strings.toInt "${port}"; 

      privateKeyFile = "/etc/wgKey";

      peers = [{
        publicKey = "${publicKey}";
        allowedIPs = [ "0.0.0.0/0" ];
        endpoint = "${serverIP}:${port}";
        persistentKeepalive = 25;
      }];
    };
  };
}
