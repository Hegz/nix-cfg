{ inputs, outputs, lib, config, pkgs, ... }:
let 

  # Define the llama-cpp package once, reused across all model commands
  llama-cpp = pkgs.unstable.llama-cpp.override { cudaSupport = true; };
  llama-server = "${llama-cpp}/bin/llama-server";

  # Fetch models into the Nix store at build time
  models = {
    qwen35-uncensored = pkgs.fetchurl {
      url = "https://huggingface.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive/resolve/main/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q6_K.gguf";
      hash = "sha256-wLp762j9P+R4kb1UlIbTjc9i0AgXKW6jFK03AX9aSYY="; # replace with real hash
    };
    gemma4 = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-Q6_K.gguf";
      hash = "sha256-A75pV0BO8kTB++PQggMGOwjXWf7htYMSm0XgtOMau/k=";
    };
    qwen3-8b = pkgs.fetchurl {
      url = "https://huggingface.co/Qwen/Qwen3-8B-GGUF/resolve/main/Qwen3-8B-Q4_K_M.gguf";
      hash = "sha256-2YzcvQPhfOR2gUNbUVDjTBQX9QtcABndVg5IgsV0V4U="; # replace with real hash
    };
	fim-coder = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-1.5B-Instruct-Q8_0.gguf";
      hash = "sha256-Mi9EkhJgT2NV3PhOrX9CYtEYC7a2REhmlN+BkVMU7sE=";
    };
  };

in
{
  # Building more then 1 big thing at a time causes problems.
  nix.settings = { 
    max-jobs = 1;
    cores = 8;
  };
     
  services.llama-swap = {
    enable = true;
    package = pkgs.unstable.llama-swap;
    port = 8012;
    openFirewall = true;
    settings = {
      # How long in seconds to wait for a model to load before giving up
      healthCheckTimeout = 120;

      # How long an idle model stays loaded before being swapped out (seconds)
      # This is the key feature of llama-swap — only one model in VRAM at a time
      models = {
        "qwen35-uncensored" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.qwen35-uncensored} --n-gpu-layers 99 --ctx-size 16384 --threads 8 --no-webui";
          ttl = 300; # unload after 5 minutes of inactivity
          aliases = [ "qwen35" "uncensored" ];
        };
        "gemma4-e4b" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.gemma4} --n-gpu-layers 99 --ctx-size 32768 --threads 8 --no-webui --jinja";
          ttl = 300;
          aliases = [ "coder" ];
        };
        "qwen3-8b" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.qwen3-8b} --n-gpu-layers 99 --ctx-size 32768 --threads 8 --no-webui";
          ttl = 300;
          aliases = [ "qwen3" "fast" ];
        };
		"fim-coder" = {
      	  cmd = "${llama-server} --port $\{PORT} -m ${models.fim-coder} --n-gpu-layers 99 --ctx-size 4096 --threads 8 --no-webui --cache-reuse 256";
      	  ttl = 600;  # keep loaded longer since vim completion is frequent
      	  aliases = [ "fim" ];
    	};
      };
    };
  };

  # Point Open WebUI at llama-swap instead of (or alongside) Ollama
  services.open-webui = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";
    openFirewall = true;
    environment = {
      OPENAI_API_BASE_URLS = "http://localhost:8012/v1";
      OPENAI_API_KEYS = "none";
    };
  };

}
