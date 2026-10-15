{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  secrets,
  ...
}: let
  # Prevents uvx from downloading its own Python binary (which is a generic
  # Linux ELF that NixOS cannot execute). Forces it to use the Nix-managed
  # Python interpreter instead.
  uvxEnv = {
    UV_PYTHON = "${pkgs.python3}/bin/python3";
    UV_PYTHON_DOWNLOADS = "never";
  };
in {
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";

    model = "llama-swap/ternary-bonsai-2";

    provider = {
      "llama-swap" = {
        npm = "@ai-sdk/openai-compatible";
        name = "Local (llama-swap)";
        options = {
          baseURL = "http://${secrets.llama.host}:${secrets.llama.port}/v1";
        };
        models = {
          "ternary-bonsai-2" = {
            name = "bonsai-2";
          };
        };
      };
    };

    mcp = {
      "fetch" = {
        type = "remote";
        url = "http://${secrets.llama.host}:8009/fetch";
        enabled = true;
      };

      "time" = {
        type = "remote";
        url = "http://${secrets.llama.host}:8009/time";
        enabled = true;
      };

      "nixos" = {
        type = "remote";
        url = "http://${secrets.llama.host}:8009/nixos";
        enabled = true;
      };
    };
  };
}
