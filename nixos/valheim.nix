# valheim.nix
{config, pkgs, lib, ...}: let
	# Set to {id}-{branch}-{password} for betas.
	steam-app = "896660";
in {
	imports = [
		./steam.nix
	];

	users.users.valheim = {
		isSystemUser = true;
		# Valheim puts save data in the home directory.
		home = "/var/lib/valheim";
		createHome = true;
		homeMode = "750";
		group = "valheim";
	};

	users.groups.valheim = {};

	systemd.services.valheim = {
		wantedBy = [ "multi-user.target" ];

		# Install the game before launching.
		wants = [ "steam@${steam-app}.service" ];
		after = [ "steam@${steam-app}.service" ];

		serviceConfig = {
			ExecStart = lib.escapeShellArgs [
				"/var/lib/steam-app-${steam-app}/valheim_server.x86_64"
				"-nographics"
				"-batchmode"
				# "-crossplay" # This is broken because it looks for "party" shared library in the wrong path.
				"-savedir" "/var/lib/valheim/save"
				"-name" "Fairbrother_Land"
				"-port" "2456"
				"-world" "Dedicated"
				"-password" "secret"
				"-public" "0" # Valheim now supports favourite servers in-game which I am using instead of listing in the public registry.
				"-backups" "5" # I take my own backups, if you don't you can remove this to use the built-in basic rotation system.
			];
			Nice = "-5";
			PrivateTmp = true;
			Restart = "always";
			User = "valheim";
			WorkingDirectory = "~";
		};
		environment = {
			# linux64 directory is required by Valheim.
			LD_LIBRARY_PATH = "/var/lib/steam-app-${steam-app}/linux64:${pkgs.glibc}/lib";
			SteamAppId = "892970";
		};
	};

	};

