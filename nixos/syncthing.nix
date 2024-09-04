{ inputs, outputs, lib, config, pkgs, ... }:
{
#  users.users.dokuwiki = {
#   #extraGroups = [ "nginx" ];
#    home = "/var/lib/DokuSync";
#    createHome = true;
#  };

  services = {
    syncthing = {
      enable = true;
      user = "root";
      dataDir = "/root/syncthing";
      configDir = "/root/syncthing/.config";
	  overrideDevices = true;
      overrideFolders = true;
      settings = {
		devices = {
	      "Embiggen" = { id = "IG544IL-LQMPEO4-VA7RBIO-TEPN4WF-CRUZ52F-BZHRTYE-BPJ3FVO-WQWS6Q2"; };
		  # "Cromulent" = { id = "DEVICE-ID-GOES-HERE"; };
	      "HePhaestus" = { id = "6BHPAS4-3WDSCZY-O7NOFJJ-YCMUXJT-PTTDX4Y-7HKKAXO-SKQUDXM-IMUUSQV"; };
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
