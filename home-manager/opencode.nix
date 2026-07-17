{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  secrets,
  ...
}:
let
  # Prevents uvx from downloading its own Python binary (which is a generic
  # Linux ELF that NixOS cannot execute). Forces it to use the Nix-managed
  # Python interpreter instead.
  uvxEnv = {
    UV_PYTHON           = "${pkgs.python3}/bin/python3";
    UV_PYTHON_DOWNLOADS = "never";
  };
in
{
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";

    model = "llama-swap/qwen35-deepseek";

    provider = {
      "llama-swap" = {
        npm     = "@ai-sdk/openai-compatible";
        name    = "Local (llama-swap)";
        options = {
          baseURL = "http://${secrets.llama.host}:${secrets.llama.port}/v1";
        };
        models = {
          "qwen35-uncensored" = { name = "Qwen3.5 9B Uncensored"; };
          "gemma4-e4b"        = { name = "Gemma4 E4B"; };
          "gemma4-12b"        = { name = "Gemma4 12B"; };
          "qwen35-deepseek"   = { name = "Qwen3.5 Deepseek"; };
        };
      };
    };

    mcp = {

      "owui-rag" = {
        type    = "local";
        command = [ "/var/lib/mcpo/owui-rag-wrapper" ];
        enabled = true;
      };

      "fetch" = {
        type        = "local";
        command     = [ "${pkgs.uv}/bin/uvx" "mcp-server-fetch" ];
        enabled     = true;
        environment = uvxEnv;
      };

      "time" = {
        type        = "local";
        command     = [ "${pkgs.uv}/bin/uvx" "mcp-server-time" "--local-timezone=America/Vancouver" ];
        enabled     = true;
        environment = uvxEnv;
      };

      "memory" = {
        type    = "local";
        command = [ "${pkgs.nodejs}/bin/npx" "-y" "@modelcontextprotocol/server-memory" ];
        enabled = true;
      };

      "sqlite" = {
        type        = "local";
        command     = [ "${pkgs.uv}/bin/uvx" "mcp-server-sqlite" "--db-path" "/var/lib/mcpo/netrunner-cards.db" ];
        enabled     = true;
        environment = uvxEnv;
      };
    };
  };
}
