# Gridcoin Network Status API Proxy

A thin FastAPI server that exposes read-only endpoints over the local
Gridcoin wallet's JSON-RPC interface and its Scraper data files.
Intended to run on the same host as a Gridcoin wallet running with the
`-scraper` option, so the website (and other read-only consumers) can
fetch live network data without each browser needing a direct
connection to the wallet.

## Endpoints

| Path | Source | Notes |
|---|---|---|
| `GET /health` | — | Cache freshness |
| `GET /api/v1/network-status` | Wallet RPC + Scraper `ConvergedStats.csv.gz` | Superblock + project snapshot; 5 min server-side cache |
| `GET /api/v1/history/cpid-churn` | `gridcoin_stats.duckdb` | Daily active / churn in-out CPID counts |
| `GET /api/v1/history/project-active-cpids` | `gridcoin_stats.duckdb` | Daily active CPID count per project |
| `GET /api/v1/history/project-churn` | `gridcoin_stats.duckdb` | Daily project count in superblock + adds/drops |
| `GET /api/v1/history/projects` | `gridcoin_stats.duckdb` | Distinct project names for UI filters |
| `GET /api/v1/history/top-cpids` | `gridcoin_stats.duckdb` | CPID leaderboard; `?project=` scopes to one project, `?limit=N`, `?order_by=COL` |

All `/api/v1/*` endpoints are rate-limited per remote IP. `GET` only;
CORS is explicit-origin-list (see `CORS_ORIGINS` env var).

## Configuration

Environment variables (all optional):

| Var | Default | Purpose |
|---|---|---|
| `GRIDCOIN_CONF` | `~/.GridcoinResearch/gridcoinresearch.conf` | Wallet config (for `rpcuser` / `rpcpassword` / `rpcport`) |
| `SCRAPER_DATA_DIR` | `~/.GridcoinResearch/Scraper` | Scraper output directory |
| `STATS_DB_PATH` | `~/.GridcoinResearch/analytics/gridcoin_stats.duckdb` | Analytics DuckDB (optional — history endpoints 503 if absent) |
| `CORS_ORIGINS` | `https://gridcoin.us` | Comma-separated allowed browser origins |
| `LISTEN_HOST` | `127.0.0.1` | Bind address |
| `LISTEN_PORT` | `5000` | Bind port |
| `CACHE_TTL` | `300` | In-memory cache TTL for `/api/v1/network-status` (seconds) |
| `HISTORY_CACHE_TTL` | `3600` | `Cache-Control: max-age` for history endpoints |

## Running locally

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
CORS_ORIGINS="https://gridcoin.us,http://localhost:4001" \
    .venv/bin/python server.py
```

## Concurrency model

- The wallet-RPC / scraper cache is refreshed on a background asyncio task every `CACHE_TTL` seconds.
- History endpoints open a fresh short-lived read-only DuckDB connection per request. The connection is closed immediately so the daily analytics refresh never contends with a long-lived reader. When the refresh writer briefly holds an exclusive lock, the endpoints return `503` and the client can retry.

## Deployment (production target: AWS scraper VPS)

The proxy runs behind nginx/caddy on the scraper host which terminates TLS for `api.gridcoin.us`. The analytics database is populated by the sibling systemd chain (`record-converged-stats` → `ingest-converged-stats` → `refresh-converged-stats`) documented alongside the analytics tooling.
