# modules/local-redirects.nix
#
# Listens on port 80 and issues 301 redirects to the HTTPS Tailscale URL.
# Handles both <service>.local and any custom local TLD domains.
#
# Example (in MCP/configuration.nix):
#
#   (import ../modules/local-redirects.nix {
#     inherit secrets;
#     redirects = [
#       { local = "mealie";         customDomains = [ "mealie.fair" ]; }
#       { local = "audiobookshelf"; }
#       { local = "freshrss";       customDomains = [ "freshrss.fair" "rss.fair" ]; }
#       { local = "kanidm";         }
#     ];
#   })

{ secrets, redirects }:
{ lib, pkgs, ... }:

let
  tailnetDomain = secrets.tailnet.domain;

  makeVhost = localName: targetName: {
    forceSSL = false;
    addSSL   = false;
    listen   = [{ addr = "0.0.0.0"; port = 80; }];
    locations."/".return = "301 https://${targetName}.${tailnetDomain}$request_uri";
  };

  # Build the full attrset of hostname → vhost config for one redirect entry
  entryToVhosts = entry:
    let
      target = if entry ? target then entry.target else entry.local;
      localVhost  = { "${entry.local}.local" = makeVhost entry.local target; };
      customVhosts = if entry ? customDomains
        then builtins.listToAttrs (map (d: { name = d; value = makeVhost d target; }) entry.customDomains)
        else {};
    in
      localVhost // customVhosts;

in
{
  services.nginx = {
    enable                   = true;
    recommendedProxySettings = true;
    virtualHosts = lib.foldl' (acc: entry: acc // entryToVhosts entry) {} redirects;
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
