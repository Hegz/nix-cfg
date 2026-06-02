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
  };

in
{
  # Building more then 1 big thing at a time causes problems.
  nix.settings = { 
    max-jobs = 1;
    cores = 8;
  };

  systemd.services.llama-swap.serviceConfig = {
    ProcSubset =  lib.mkForce "all";
    ProtectProc = lib.mkForce "default";
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
      };
    };
  };

  # Point Open WebUI at llama-swap instead of (or alongside) Ollama
  services.open-webui = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";
    package = pkgs.unstable.open-webui;
    openFirewall = true;
    environment = {
      OPENAI_API_BASE_URLS = "http://localhost:8012/v1";
      OPENAI_API_KEYS = "none";
    };
  };

}
