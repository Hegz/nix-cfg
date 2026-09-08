# modules/rag-bridge.nix
#
# Provides:
#   1. Standalone ChromaDB HTTP server on localhost:8014
#   2. owui-rag-mcp.py + shell wrapper deployed to /var/lib/mcpo/
#
# Required additions to modules/llms.nix:
#
#   A) Open WebUI environment block:
#        CHROMA_HTTP_HOST = "127.0.0.1";
#        CHROMA_HTTP_PORT = "8014";
#
#   B) mcpo MCP server config (no Nix variables needed — wrapper is at a fixed path):
#        "owui-rag" = {
#          command = "/var/lib/mcpo/owui-rag-wrapper";
#          args    = [];
#        };

{ config, pkgs, lib, ... }:

let
  ragBridgePython = pkgs.python3.withPackages (ps: with ps; [
    chromadb
    httpx
  ]);

  owuiRagMcpScript = pkgs.writeTextFile {
    name        = "owui-rag-mcp.py";
    text        = builtins.readFile ./owui-rag-mcp.py;
    executable  = true;
    destination = "/bin/owui-rag-mcp.py";
  };

  # Wrapper bakes in env vars. mcpo silently drops any server entry
  # containing an `env` key, so env vars cannot pass through config.json.
  owuiRagWrapper = pkgs.writeShellScript "owui-rag-wrapper" ''
    export EMBEDDING_BASE_URL="http://localhost:8013"
    export CHROMA_HOST="localhost"
    export CHROMA_PORT="8014"
    exec ${ragBridgePython}/bin/python3 /var/lib/mcpo/owui-rag-mcp.py
  '';

  deployScript = pkgs.writeShellScript "deploy-owui-rag-mcp" ''
    install -m 0755 -o mcpo -g mcpo \
      ${owuiRagMcpScript}/bin/owui-rag-mcp.py \
      /var/lib/mcpo/owui-rag-mcp.py

    install -m 0755 -o mcpo -g mcpo \
      ${owuiRagWrapper} \
      /var/lib/mcpo/owui-rag-wrapper
  '';

in {

  users.users.chromadb = {
    isSystemUser = true;
    group        = "chromadb";
    home         = "/var/lib/chromadb";
    createHome   = false;
    description  = "ChromaDB vector store service user";
  };
  users.groups.chromadb = {};

  systemd.services.chromadb = {
    description = "ChromaDB vector store (shared between Open WebUI and OpenCode)";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];
    before      = [ "open-webui.service" ];
    requiredBy  = [ "open-webui.service" ];

    serviceConfig = {
      ExecStart = "${ragBridgePython}/bin/chroma run --host 127.0.0.1 --port 8014 --path /var/lib/chromadb";
      User           = "chromadb";
      Group          = "chromadb";
      StateDirectory = "chromadb";
      Restart        = "on-failure";
      RestartSec     = "5s";

      NoNewPrivileges = true;
      ProtectSystem   = "strict";
      ProtectHome     = true;
      ReadWritePaths  = [ "/var/lib/chromadb" ];
      PrivateTmp      = true;
    };
  };

  systemd.services.deploy-owui-rag-mcp = {
    description   = "Deploy owui-rag-mcp.py and wrapper to /var/lib/mcpo";
    wantedBy      = [ "multi-user.target" ];
    before        = [ "mcpo.service" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart       = "${deployScript}";
    };
  };
}
