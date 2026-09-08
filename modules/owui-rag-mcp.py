#!/usr/bin/env python3
"""
owui-rag-mcp: MCP stdio server bridging Open WebUI's ChromaDB to OpenCode/mcpo.

Implements the MCP JSON-RPC stdio protocol directly.
No mcp/fastmcp library required — only httpx and chromadb.

Environment variables:
  EMBEDDING_BASE_URL  default: http://localhost:8013
  EMBEDDING_MODEL     default: nomic-embed-text-v1.5
  QUERY_PREFIX        default: "search_query: "   (required by nomic for full quality)
  CHROMA_HOST         default: localhost
  CHROMA_PORT         default: 8014
  N_RESULTS           default: 5
"""

import json
import os
import sys

import httpx
import chromadb

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

EMBEDDING_BASE_URL = os.environ.get("EMBEDDING_BASE_URL", "http://localhost:8013")
EMBEDDING_MODEL    = os.environ.get("EMBEDDING_MODEL",    "nomic-embed-text-v1.5")
QUERY_PREFIX       = os.environ.get("QUERY_PREFIX",       "search_query: ")
CHROMA_HOST        = os.environ.get("CHROMA_HOST",        "localhost")
CHROMA_PORT        = int(os.environ.get("CHROMA_PORT",    "8014"))
N_RESULTS_DEFAULT  = int(os.environ.get("N_RESULTS",      "5"))

# ---------------------------------------------------------------------------
# Tool definitions (returned on tools/list)
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "name": "list_collections",
        "description": (
            "List all knowledge collections available in the shared ChromaDB vector store. "
            "Returns collection names and document counts. "
            "Call this first to discover what knowledge is indexed."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "search_knowledge",
        "description": (
            "Semantic search over Open WebUI's knowledge base using vector similarity. "
            "Correctly prefixes queries for nomic-embed-text-v1.5. "
            "Use list_collections first to discover collection names. "
            "Leave collection_name empty to search all collections."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Natural language search query.",
                },
                "collection_name": {
                    "type": "string",
                    "description": (
                        "Target collection name from list_collections. "
                        "Empty string searches all collections."
                    ),
                    "default": "",
                },
                "n_results": {
                    "type": "integer",
                    "description": "Maximum results to return (default 5).",
                    "default": 5,
                },
            },
            "required": ["query"],
        },
    },
]

# ---------------------------------------------------------------------------
# MCP transport helpers
# ---------------------------------------------------------------------------

def send(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def error_response(msg_id, code: int, message: str) -> None:
    send({"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}})


def ok_response(msg_id, result: dict) -> None:
    send({"jsonrpc": "2.0", "id": msg_id, "result": result})

# ---------------------------------------------------------------------------
# Embedding
# ---------------------------------------------------------------------------

def embed(text: str) -> list[float]:
    """Embed text with the mandatory nomic query prefix."""
    with httpx.Client(timeout=30.0) as client:
        r = client.post(
            f"{EMBEDDING_BASE_URL}/v1/embeddings",
            headers={"Authorization": "Bearer x", "Content-Type": "application/json"},
            json={"model": EMBEDDING_MODEL, "input": [QUERY_PREFIX + text]},
        )
        r.raise_for_status()
        return r.json()["data"][0]["embedding"]

# ---------------------------------------------------------------------------
# Chroma helpers
# ---------------------------------------------------------------------------

def get_chroma() -> chromadb.HttpClient:
    return chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)

# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

def tool_list_collections() -> str:
    client = get_chroma()
    cols = client.list_collections()
    if not cols:
        return "No collections found in the vector store."
    return json.dumps(
        [{"name": c.name, "count": c.count()} for c in cols],
        indent=2,
    )


def tool_search_knowledge(
    query: str,
    collection_name: str = "",
    n_results: int = N_RESULTS_DEFAULT,
) -> str:
    vec = embed(query)
    client = get_chroma()

    if collection_name:
        targets = [client.get_collection(collection_name)]
    else:
        targets = client.list_collections()

    if not targets:
        return "No collections available to search."

    hits = []
    errors = []

    for col in targets:
        try:
            count = col.count()
            if count == 0:
                continue

            res = col.query(
                query_embeddings=[vec],
                n_results=min(n_results, count),
                include=["documents", "distances", "metadatas"],
            )

            for i, doc in enumerate(res["documents"][0]):
                # Chroma cosine distance: 0.0 = identical, 2.0 = opposite.
                # Report as-is; lower distance = higher relevance.
                hits.append({
                    "collection": col.name,
                    "distance":   round(res["distances"][0][i], 4),
                    "metadata":   (res["metadatas"][0][i] or {}) if res["metadatas"] else {},
                    "content":    doc,
                })
        except Exception as e:
            errors.append({"collection": col.name, "error": str(e)})

    hits.sort(key=lambda h: h["distance"])
    output = hits[:n_results]

    if errors:
        output.append({"errors": errors})

    return json.dumps(output, indent=2) if output else "No results found."


def dispatch(name: str, args: dict) -> str:
    if name == "list_collections":
        return tool_list_collections()
    if name == "search_knowledge":
        return tool_search_knowledge(
            query=args["query"],
            collection_name=args.get("collection_name", ""),
            n_results=int(args.get("n_results", N_RESULTS_DEFAULT)),
        )
    raise ValueError(f"Unknown tool: {name}")

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def main() -> None:
    for raw_line in sys.stdin:
        raw_line = raw_line.strip()
        if not raw_line:
            continue

        try:
            msg = json.loads(raw_line)
        except json.JSONDecodeError:
            continue

        method = msg.get("method", "")
        msg_id = msg.get("id")

        # Notifications carry no id and require no response.
        if msg_id is None:
            continue

        try:
            if method == "initialize":
                ok_response(msg_id, {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "owui-rag-mcp", "version": "1.0.0"},
                })

            elif method == "tools/list":
                ok_response(msg_id, {"tools": TOOLS})

            elif method == "tools/call":
                params = msg.get("params", {})
                result_text = dispatch(params["name"], params.get("arguments", {}))
                ok_response(msg_id, {
                    "content": [{"type": "text", "text": result_text}],
                })

            else:
                error_response(msg_id, -32601, f"Method not found: {method}")

        except Exception as exc:
            error_response(msg_id, -32603, str(exc))


if __name__ == "__main__":
    main()
