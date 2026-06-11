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
          "qwen35-uncensored" = {
            name = "Qwen3.5 9B Uncensored";
          };
          "gemma4-e4b" = {
            name = "gemma4 e4b";
          };
          "gemma4-12b" = {
            name = "gemma4 12b";
          };
          "qwen35-deepseek" = {
            name = "qwen 3.5 Deepseek";
          };
        };
      };

      # Default model for coding tasks
    };
  };
}
