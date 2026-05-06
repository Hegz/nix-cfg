# modules/local-redirects.nix
#
# Listens on port 80 on the host's LAN interface and issues 301 redirects
# from  http://<service>.local  →  https://<service>.<tailnet-domain>
#
# Import this module on any host that serves SSO-protected services locally.
# Pass in the list of { local, target } redirect pairs for that host.
#
# Example (in MCP/configuration.nix):
#
#   (import ../modules/local-redirects.nix {
#     inherit secrets;
#     redirects = [
#       { local = "mealie";          }
#       { local = "audiobookshelf";  }
#       { local = "freshrss";        }
#       { local = "kanidm";          }
#     ];
#   })
#
# The `local` name becomes both the .local hostname AND the subdomain of the
# Tailscale domain, so  http://mealie.local  →  https://mealie.<tailnet>.
# If a service has a different local name, use the optional `target` key:
#   { local = "nvr"; target = "secunit"; }  (for Frigate on SecUnit)

{ secrets, redirects }:
{ lib, pkgs, ... }:

let
  domain = secrets.tailnet.domain;

  # Build one nginx virtualHost per redirect entry.
  makeVhost = entry:
    let
      localName  = entry.local;
      targetHost = if entry ? target then entry.target else entry.local;
    in {
      name  = "${localName}.local";
      value = {
        # No TLS here — this vhost exists only to redirect to the HTTPS URL.
        forceSSL   = false;
        addSSL     = false;
        listen     = [{ addr = "0.0.0.0"; port = 80; }];

        locations."/" = {
          return = "301 https://${targetHost}.${domain}$request_uri";
        };
      };
    };

in
{
  services.nginx = {
    enable                   = true;
    recommendedProxySettings = true;

    virtualHosts = builtins.listToAttrs (map makeVhost redirects);
  };

  # Open port 80 on the host firewall so LAN clients can reach this.
  # (Containers handle their own firewall rules separately.)
  networking.firewall.allowedTCPPorts = [ 80 ];
}
