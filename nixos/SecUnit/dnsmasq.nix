# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).


{ip, interface, ... }: { inputs, outputs, lib, config, pkgs, secrets, ... }:
{
  #Provide DNS and DHCP
  services.dnsmasq = {
    enable = true;
    settings = {
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      cache-size = 1000;
      server = [ "1.1.1.1" "8.8.8.8" ];
      bind-dynamic = true;

      # DHCP Settings
      interface = "${interface}";
      no-hosts = true;

      listen-address ="${ip}";
      dhcp-option-force = [ 
        "option:router,${ip}"
        "option:dns-server,${ip}"
        "option:ntp-server,${ip}"
      ];
      dhcp-range = [ "192.168.10.50,192.168.10.54,24h" ];
      dhcp-host = builtins.map (x: "${x.mac},${x.name},${x.ip}" ) (
         secrets.secunit.hosts );
    };
  };
}
