{ inputs, outputs, lib, config, pkgs, secrets, ... }:
# Vim configuration options
{
   xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
	"$schema" = "https://opencode.ai/config.json";

	provider = {
	  # llama-swap endpoint — covers all your local GGUF models
	  "llama-swap" = {
		npm = "@ai-sdk/openai-compatible";
		name = "Local (llama-swap)";
		options = {
		  baseURL = "http://${secrets.llama.host}:${secrets.llama.port}/v1";
		};
		models = {
		  "gemma4-e4b" = {
			name = "Gemma 4";
		  };
		  "qwen3-8b" = {
			name = "Qwen3 8B (fast)";
		  };
		  "qwen35-uncensored" = {
			name = "Qwen3.5 9B Uncensored";
		  };
		};
	  };

	# Default model for coding tasks

  };
};
}
