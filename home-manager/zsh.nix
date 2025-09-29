{ inputs, outputs, lib, config, pkgs, ... }:
# Zsh configuration  options
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    oh-my-zsh = {
      enable = true;
      theme = "risto";
      plugins = [ "sudo" "common-aliases" "mosh" "ssh-agent" ];
      extraConfig = ''
        zstyle :omz:plugins:ssh-agent agent-forwarding yes
        zstyle :omz:plugins:ssh-agent lazy yes
      '';
    };
    initContent = lib.mkOrder 1200 ''
	  ssh() {
		if [ -n "$TMUX" ]; then # Check if inside a tmux session

		  # Temporarily disable automatic-rename to prevent it from overriding the custom name
		  tmux set-window-option automatic-rename off

		  # Extract the hostname from the SSH arguments
		  local hostname=$(echo "$*" | sed -E 's/.*@([^ ]+).*/\1/' | cut -d' ' -f1)
		  if [ -z "$hostname" ]; then
			hostname="$1" # If no @ is found, assume the first argument is the hostname
		  fi

		  # Set the tmux window name to the hostname
		  tmux rename-window "$hostname"

		  # Execute the SSH command
		  command ssh "$@"

		  # re-enable automatic-rename
          tmux set-window-option automatic-rename on

		else
		  # If not in tmux, just execute ssh normally
		  command ssh "$@"
		fi
	  }
    '';
  };
}
