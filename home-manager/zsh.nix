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
		  # Save current window name and automatic-rename setting
		  local old_name=$(tmux display-message -p '#W')
          local old_automatic_rename=$(tmux show-options -w automatic-rename | awk '{print $2}')

		  # Temporarily disable automatic-rename to prevent it from overriding the custom name
		  tmux set-option -w automatic-rename off

		  # Extract the hostname from the SSH arguments
		  local hostname=$(echo "$*" | sed -E 's/.*@([^ ]+).*/\1/' | cut -d' ' -f1)
		  if [ -z "$hostname" ]; then
			hostname="$1" # If no @ is found, assume the first argument is the hostname
		  fi

		  # Set the tmux window name to the hostname
		  tmux rename-window "$hostname"

		  # Execute the SSH command
		  command ssh "$@"

		  # Restore previous window name or re-enable automatic-rename
		  if [ "$old_automatic_rename" = "on" ]; then
			tmux set-window-option -w automatic-rename on
			# If the original name was not automatically generated, restore it
			if [[ "$old_name" != "bash" && "$old_name" != "zsh" ]]; then # Adjust based on default shell names
			  tmux rename-window "$old_name"
			fi
		  fi
		else
		  # If not in tmux, just execute ssh normally
		  command ssh "$@"
		fi
	  }
    '';
  };
}
