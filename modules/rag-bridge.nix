# modules/rag-bridge.nix
#
# Provides:
#   1. Standalone ChromaDB HTTP server on localhost:8014
#      (replaces Open WebUI's embedded Chroma instance)
#   2. owui-rag-mcp deployed to /var/lib/mcpo/owui-rag-mcp.py
#      (add to mcpo's MCP server config in modules/llms.nix — see below)
#
# Required changes to modules/llms.nix (not made here — you must merge them):
#
#   A) Open WebUI environment — add these two vars to the service's env/environment block:
#        CHROMA_HTTP_HOST = "127.0.0.1";
#        CHROMA_HTTP_PORT = "8014";
#
#   B) mcpo MCP server config — add this entry alongside time/fetch/memory/sqlite:
#        "owui-rag" = {
#          command = "${ragBridgePython}/bin/python3";
#          args    = [ "/var/lib/mcpo/owui-rag-mcp.py" ];
#          env = {
#            EMBEDDING_BASE_URL = "http://localhost:8013";
#            CHROMA_HOST        = "localhost";
#            CHROMA_PORT        = "8014";
#          };
#        };
#      where ragBridgePython = the attribute defined in this file (expose it via an overlay
#      or just duplicate the withPackages expression inline).
#
# Migration — run ONCE before activating this module (see migrate-chroma.sh).
# Open WebUI's embedded Chroma data must be copied to /var/lib/chromadb before
# switching to the HTTP server or all existing indexed knowledge is lost.
{
  config,
  pkgs,
  lib,
  ...
}: let
  # Python environment for both the ChromaDB server process and the MCP bridge.
  # chromadb ships the `chroma` CLI we use to run the HTTP server.
  ragBridgePython = pkgs.python3.withPackages (ps:
    with ps; [
      chromadb # includes the `chroma` CLI entrypoint
      httpx # used by owui-rag-mcp.py for embedding calls
    ]);

  # Install owui-rag-mcp.py into the Nix store so the path is stable.
  owuiRagMcpScript = pkgs.writeTextFile {
    name = "owui-rag-mcp.py";
    text = builtins.readFile ./owui-rag-mcp.py;
    executable = true;
    destination = "/bin/owui-rag-mcp.py";
  };
in {
  # ---------------------------------------------------------------------------
  # 1. System user for ChromaDB
  # ---------------------------------------------------------------------------

  users.users.chromadb = {
    isSystemUser = true;
    group = "chromadb";
    home = "/var/lib/chromadb";
    createHome = false; # StateDirectory handles this
    description = "ChromaDB vector store service user";
  };
  users.groups.chromadb = {};

  # ---------------------------------------------------------------------------
  # 2. ChromaDB HTTP server
  # ---------------------------------------------------------------------------

  systemd.services.chromadb = {
    description = "ChromaDB vector store (shared between Open WebUI and OpenCode)";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];

    # Must be up before Open WebUI tries to connect.
    before = ["open-webui.service"];
    requiredBy = ["open-webui.service"];

    serviceConfig = {
      ExecStart = lib.escapeShellArgs [
        "${ragBridgePython}/bin/chroma"
        "run"
        "--host"
        "127.0.0.1"
        "--port"
        "8014"
        "--path"
        "/var/lib/chromadb"
      ];
      User = "chromadb";
      Group = "chromadb";
      StateDirectory = "chromadb"; # creates /var/lib/chromadb, owned by chromadb
      Restart = "on-failure";
      RestartSec = "5s";

      # Hardening — ChromaDB doesn't need anything exotic.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = ["/var/lib/chromadb"];
      PrivateTmp = true;
    };
  };

  # ---------------------------------------------------------------------------
  # 3. Deploy owui-rag-mcp.py to /var/lib/mcpo
  #    so the mcpo user can exec it without Nix store path gymnastics.
  # ---------------------------------------------------------------------------

  systemd.services.deploy-owui-rag-mcp = {
    description = "Deploy owui-rag-mcp.py to /var/lib/mcpo";
    wantedBy = ["multi-user.target"];
    before = ["mcpo.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "deploy-owui-rag-mcp" ''
        install -m 0755 -o mcpo -g mcpo \
          ${owuiRagMcpScript}/bin/owui-rag-mcp.py \
          /var/lib/mcpo/owui-rag-mcp.py
      '';
    };
  };
}
