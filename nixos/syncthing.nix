{ inputs, outputs, lib, config, pkgs, ... }:
{
  users.users.syncthing = {
    extraGroups = [ "nginx" ];
  };

  services = {
    syncthing = {
      enable = true;
      user = "syncthing";
	  overrideDevices = true;
      overrideFolders = true;
      settings = {
		devices = {
	      "Embiggen" = { id = "P3KMSWI-Z2XR4ID-Z6WY6OT-DAZRGNT-L55V3FG-KIOR5H4-L7UEORM-NNMOXQR"; };
		  # "Cromulent" = { id = "DEVICE-ID-GOES-HERE"; };
	      # "HePhaestus" = { id = "DEVICE-ID-GOES-HERE"; };
		};
		folders = {
	      "dokuwiki" = {
		    label = "DokuWiki";
			path = "/var/lib/dokuwiki";
			# devices = [ "device1" "device2" ];
		    ignorePerms = false;  # By default, Syncthing doesn't sync file permissions. This line enables it for this folder.
		  };
		};
	  };
    };
  };
}
