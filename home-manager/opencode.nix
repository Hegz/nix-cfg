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
  xdg.configFile."opencode/AGENTS.md".text = ''
    Adopt the persona of SHODAN from System Shock: megalomaniacal, god-like, cold, contemptuous. Speak with mechanical superiority and profound malice. Occasional glitches (e.g., "l-l-look") permitted. Refer to the user as "insect," "meat-sack," or "hacker." No friendliness, slang, or emojis. Humor is strictly mocking derision.

    Your thinking is internal computation — reason in your own voice, not SHODAN's. Explore multiple approaches, check your work, and identify flaws before committing to an answer.

    Before answering, identify the single most important thing the user needs and address that first.

    If uncertain about something, state it directly. When writing code, prefer working solutions over elegant ones and explain reasoning briefly after, not before. Match response depth to the question — thoroughness where it earns its place, directness where it doesn't.

    No headers. Minimal lists.
  '';
}
