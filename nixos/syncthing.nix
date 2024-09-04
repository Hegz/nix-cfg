{ inputs, outputs, lib, config, pkgs, ... }:
{
  users.users.dokuwiki = {
    #extraGroups = [ "nginx" ];
    home = "/var/lib/DokuSync";
    createHome = true;
  };

  services = {
    syncthing = {
      enable = true;
      user = "dokuwiki";
      dataDir = "/var/lib/DokuSync";
      configDir = "/var/lib/DokuSync/.config";
	  overrideDevices = true;
      overrideFolders = true;
      settings = {
		devices = {
	      "Embiggen" = { id = "ZBJLL4Y-KOLP7G6-GQL6JOK-TSVUY36-PGMBZAT-HA3MJ3N-7DJEWJ7-3FCNUQ5"; };
		  # "Cromulent" = { id = "DEVICE-ID-GOES-HERE"; };
	      "HePhaestus" = { id = "D5KKSD7-P2CCRQ4-VCUL4GH-AXQN7VV-7TXGLRY-QKCCQHY-OEY5SOL-RQNEZA2"; };
		};
		folders = {
	      "dokuwiki" = {
		    label = "DokuWiki";
			path = "/var/lib/dokuwiki/";
			devices = [ "Embiggen" "HePhaestus" ];
		    ignorePerms = false;  # By default, Syncthing doesn't sync file permissions. This line enables it for this folder.
		  };
		};
	  };
    };
  };
}
