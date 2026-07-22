{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  secrets,
  ...
}:
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
          "gemma4-12b-qat" = {
            name = "gemma4 12b";
          };
          "ornith-1_0-9b" = {
            name = "Ornith 1.0 9B";
          };
        };
      };
    };
  };
}
