{ inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostName  = ${config.networking.hostName};
  keySource = "../secrets/wireguard/${hostName}.key";
  addressIP = ${secrets.${hostName}.wireguard.addressIP};
  addresDNS = ${secrets.${hostName}.wireguard.addressDNS};
  publicKey = ${secrets.${hostName}.wireguard.publicKey};
  serverIP  = ${secrets.${hostName}.wireguard.serverIP};
  port      = ${secrets.${hostName}.wireguard.port};

in
{
  environment.etc = {
    wgKey.source = keySource;
  };

  networking.wg-quick.interfaces = {
    wg0 = {
      # IP address of this machine in the *tunnel network*
      address = [ "${addressIP}" ];
      dns = [ "${addressDNS}" ];

      autostart = true;

      listenPort = ${port}; 

      privateKeyFile = "/etc/wgKey";

      peers = [{
        publicKey = "${publicKey}";
        allowedIPs = [ "0.0.0.0/0" ];
        endpoint = "${server_ip}:${port}";
        persistentKeepalive = 25;
      }];
    };
  };
}
