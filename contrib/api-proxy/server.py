#!/usr/bin/env python3
# Copyright (c) 2026 The Gridcoin developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or https://opensource.org/licenses/mit-license.php.
"""
Gridcoin Network Status API Proxy

A thin FastAPI server that proxies read-only data from a local Gridcoin
wallet's JSON-RPC interface and scraper data files, serving it as a
public REST API for the Gridcoin website.

Configuration via environment variables:
    GRIDCOIN_CONF       Path to gridcoinresearch.conf (default: ~/.GridcoinResearch/gridcoinresearch.conf)
    SCRAPER_DATA_DIR    Path to Scraper data directory (default: ~/.GridcoinResearch/Scraper)
    CORS_ORIGINS        Comma-separated allowed origins (default: https://gridcoin.us)
    LISTEN_HOST         Bind address (default: 127.0.0.1)
    LISTEN_PORT         Bind port (default: 5000)
    CACHE_TTL           Cache refresh interval in seconds (default: 300)
"""

import asyncio
import csv
import gzip
import io
import json
import logging
import os
import re
import sys
import time
from collections import defaultdict
from contextlib import asynccontextmanager
from pathlib import Path

import duckdb
import httpx
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from starlette.responses import JSONResponse

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

GRIDCOIN_CONF = os.getenv(
    "GRIDCOIN_CONF",
    str(Path.home() / ".GridcoinResearch" / "gridcoinresearch.conf"),
)
SCRAPER_DATA_DIR = os.getenv(
    "SCRAPER_DATA_DIR",
    str(Path.home() / ".GridcoinResearch" / "Scraper"),
)
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "https://gridcoin.us").split(",")
LISTEN_HOST = os.getenv("LISTEN_HOST", "127.0.0.1")
LISTEN_PORT = int(os.getenv("LISTEN_PORT", "5000"))
CACHE_TTL = int(os.getenv("CACHE_TTL", "300"))
STATS_DB_PATH = os.getenv(
    "STATS_DB_PATH",
    str(Path.home() / ".GridcoinResearch" / "analytics" / "gridcoin_stats.duckdb"),
)
# Cache-Control max-age for history endpoints. The data only changes once a
# day when the refresh service runs, so long caches are fine.
HISTORY_CACHE_TTL = int(os.getenv("HISTORY_CACHE_TTL", "3600"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("gridcoin-api-proxy")

# ---------------------------------------------------------------------------
# Wallet RPC client
# ---------------------------------------------------------------------------


def read_wallet_config(conf_path: str) -> dict:
    """Parse rpcuser, rpcpassword, rpcport from the wallet config file."""
    config = {"rpcport": 15715}
    try:
        with open(conf_path, "r") as f:
            for line in f:
                line = line.strip()
                if line.startswith("#") or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip()
                if key == "rpcuser":
                    config["rpcuser"] = value
                elif key == "rpcpassword":
                    config["rpcpassword"] = value
                elif key == "rpcport":
                    config["rpcport"] = int(value)
    except FileNotFoundError:
        log.error("Wallet config not found: %s", conf_path)
        sys.exit(1)

    if "rpcuser" not in config or "rpcpassword" not in config:
        log.error("rpcuser/rpcpassword not found in %s", conf_path)
        sys.exit(1)

    return config


async def rpc_call(client: httpx.AsyncClient, url: str, auth: tuple,
                   method: str, params: list | None = None) -> dict:
    """Make a JSON-RPC call to the wallet."""
    payload = {
        "jsonrpc": "1.0",
        "id": method,
        "method": method,
        "params": params or [],
    }
    resp = await client.post(
        url,
        content=json.dumps(payload),
        headers={"Content-Type": "text/plain;"},
        auth=auth,
        timeout=60.0,
    )
    resp.raise_for_status()
    result = resp.json()
    if result.get("error"):
        raise RuntimeError(f"RPC error in {method}: {result['error']}")
    return result["result"]


# ---------------------------------------------------------------------------
# Data collection
# ---------------------------------------------------------------------------


def parse_converged_stats(scraper_dir: str) -> dict[str, int]:
    """Parse ConvergedStats.csv.gz and return per-project CPID counts."""
    stats_path = Path(scraper_dir) / "ConvergedStats.csv.gz"
    counts: dict[str, int] = defaultdict(int)

    try:
        with gzip.open(stats_path, "rt") as f:
            reader = csv.reader(f)
            for row in reader:
                if len(row) >= 2 and row[0] == "byCPIDbyProject":
                    counts[row[1]] += 1
    except FileNotFoundError:
        log.warning("ConvergedStats.csv.gz not found at %s", stats_path)
    except Exception as e:
        log.warning("Error parsing ConvergedStats.csv.gz: %s", e)

    return dict(counts)


async def collect_network_status(rpc_url: str, rpc_auth: tuple,
                                  scraper_dir: str) -> dict:
    """Fetch all data sources and merge into the API response."""
    async with httpx.AsyncClient() as client:
        # Fetch all RPC data concurrently.
        list_projects_task = rpc_call(client, rpc_url, rpc_auth,
                                      "listprojects", [True])
        greylist_task = rpc_call(client, rpc_url, rpc_auth,
                                 "getautogreylist", [True])
        superblock_task = rpc_call(client, rpc_url, rpc_auth,
                                   "superblocks", [1, True])

        list_projects, greylist_data, superblock_data = await asyncio.gather(
            list_projects_task, greylist_task, superblock_task
        )

    # Parse scraper stats (synchronous but fast — ~300KB gzipped).
    cpid_counts = parse_converged_stats(scraper_dir)

    # Extract superblock data.
    sb = superblock_data[0] if superblock_data else {}
    sb_projects = sb.get("contract_contents", {}).get("projects", {})

    # Build greylist lookup: project name → greylist metrics.
    # Note: the RPC output has a trailing colon in the key name ("project:").
    greylist_lookup = {}
    for entry in greylist_data.get("auto_greylist_projects", []):
        name = entry.get("project:", "").rstrip(":")
        if not name:
            name = entry.get("project", "")
        greylist_lookup[name] = entry

    # Merge everything into the response.
    projects = {}
    for name, proj in list_projects.items():
        status = proj.get("status", "Unknown")

        # Skip deleted projects.
        if status == "Deleted":
            continue

        project_entry = {
            "status": status,
            "gdpr_controls": proj.get("gdpr_controls", False),
            "display_name": proj.get("display_name", name),
            "display_url": proj.get("display_url", ""),
            "stats_url": proj.get("stats_url", ""),
        }

        # A project can be Active on the whitelist but excluded from the
        # current superblock if its stats have gone stale (no scraper
        # manifest parts updated in 48+ hours). Flag this explicitly so the
        # frontend can distinguish "active and earning" from "active but
        # temporarily excluded."
        in_superblock = name in sb_projects
        project_entry["in_superblock"] = in_superblock

        if in_superblock:
            sb_proj = sb_projects[name]
            project_entry["rac"] = sb_proj.get("rac", 0)
            project_entry["average_rac"] = sb_proj.get("average_rac", 0)
            project_entry["total_credit"] = sb_proj.get("total_credit", 0)

        # Add CPID count from scraper data.
        if name in cpid_counts:
            project_entry["cpid_count"] = cpid_counts[name]

        # Add greylist metrics.
        if name in greylist_lookup:
            gl = greylist_lookup[name]
            project_entry["zcd"] = gl.get("zcd", 0)
            project_entry["was"] = round(gl.get("was", 0), 4)
            project_entry["meets_greylist_criteria"] = gl.get(
                "meets_greylist_criteria", False)

        projects[name] = project_entry

    return {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "superblock": {
            "height": sb.get("height", 0),
            "date": sb.get("date", ""),
            "total_cpids": sb.get("total_cpids", 0),
            "active_beacons": sb.get("active_beacons", 0),
            "total_magnitude": sb.get("total_magnitude", 0),
            "total_projects": sb.get("total_projects", 0),
        },
        "projects": projects,
    }


# ---------------------------------------------------------------------------
# Cache
# ---------------------------------------------------------------------------

_cache: dict = {}
_cache_lock = asyncio.Lock()


async def get_cached_status(rpc_url: str, rpc_auth: tuple,
                             scraper_dir: str) -> dict:
    """Return cached network status, refreshing if stale."""
    global _cache

    async with _cache_lock:
        now = time.time()
        if _cache and now - _cache.get("_fetched_at", 0) < CACHE_TTL:
            return _cache

    try:
        data = await collect_network_status(rpc_url, rpc_auth, scraper_dir)
        data["_fetched_at"] = time.time()
        async with _cache_lock:
            _cache = data
        log.info("Cache refreshed: %d projects, superblock %s",
                 len(data.get("projects", {})),
                 data.get("superblock", {}).get("height", "?"))
        return data
    except Exception as e:
        log.error("Failed to refresh cache: %s", e)
        if _cache:
            log.info("Serving stale cache.")
            return _cache
        raise


# ---------------------------------------------------------------------------
# Background refresh
# ---------------------------------------------------------------------------

_refresh_task: asyncio.Task | None = None


async def background_refresh(rpc_url: str, rpc_auth: tuple,
                              scraper_dir: str):
    """Periodically refresh the cache in the background."""
    while True:
        await asyncio.sleep(CACHE_TTL)
        try:
            await get_cached_status(rpc_url, rpc_auth, scraper_dir)
        except Exception as e:
            log.error("Background refresh failed: %s", e)


# ---------------------------------------------------------------------------
# FastAPI application
# ---------------------------------------------------------------------------

wallet_conf = read_wallet_config(GRIDCOIN_CONF)
RPC_URL = f"http://127.0.0.1:{wallet_conf['rpcport']}/"
RPC_AUTH = (wallet_conf["rpcuser"], wallet_conf["rpcpassword"])

limiter = Limiter(key_func=get_remote_address)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start background cache refresh on startup."""
    global _refresh_task

    # Initial cache population.
    log.info("Populating initial cache...")
    try:
        await get_cached_status(RPC_URL, RPC_AUTH, SCRAPER_DATA_DIR)
    except Exception as e:
        log.error("Initial cache population failed: %s", e)

    # Start background refresh.
    _refresh_task = asyncio.create_task(
        background_refresh(RPC_URL, RPC_AUTH, SCRAPER_DATA_DIR)
    )
    log.info("Background refresh started (interval: %ds)", CACHE_TTL)

    yield

    # Shutdown.
    if _refresh_task:
        _refresh_task.cancel()
        try:
            await _refresh_task
        except asyncio.CancelledError:
            pass
    log.info("Shutdown complete.")


app = FastAPI(
    title="Gridcoin Network Status API",
    version="1.0.0",
    lifespan=lifespan,
)

app.state.limiter = limiter

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={"error": "Rate limit exceeded. Try again later."},
    )


@app.get("/api/v1/network-status")
@limiter.limit("30/minute")
async def network_status(request: Request):
    """Return current Gridcoin network status including project data."""
    data = await get_cached_status(RPC_URL, RPC_AUTH, SCRAPER_DATA_DIR)

    # Strip internal cache metadata.
    response_data = {k: v for k, v in data.items() if not k.startswith("_")}

    return JSONResponse(
        content=response_data,
        headers={"Cache-Control": f"public, max-age={CACHE_TTL}"},
    )


# ---------------------------------------------------------------------------
# Historical analytics endpoints (served from DuckDB summary tables)
# ---------------------------------------------------------------------------
#
# The analytics DB is rebuilt once a day at 00:00 UTC by the
# refresh-converged-stats.service systemd user unit. During that ~3 s write
# window the file is locked and reads will fail; we open a fresh short-lived
# read-only connection per request so no locks persist in the proxy process,
# and we translate lock errors into a retryable 503 response.


def _history_query(sql: str, params: tuple = ()) -> list[dict]:
    """Run a read-only query against the analytics DB and return a list of
    row dicts. Connection is opened and closed per call so the proxy never
    holds a reader lock that would block the nightly refresh. Date values
    are stringified to ISO-8601 for plain-JSON serialisation."""
    try:
        con = duckdb.connect(STATS_DB_PATH, read_only=True)
    except duckdb.IOException as e:
        # File locked by the refresh writer, or DB absent.
        raise HTTPException(
            status_code=503,
            detail="Analytics database is temporarily unavailable.",
        ) from e
    try:
        cursor = con.execute(sql, params)
        cols = [d[0] for d in cursor.description]
        rows = cursor.fetchall()
    finally:
        con.close()
    import datetime as _dt
    out = []
    for r in rows:
        d = {}
        for c, v in zip(cols, r):
            if isinstance(v, _dt.date):
                v = v.isoformat()
            d[c] = v
        out.append(d)
    return out


def _history_response(data: list[dict]) -> JSONResponse:
    return JSONResponse(
        content={"data": data},
        headers={"Cache-Control": f"public, max-age={HISTORY_CACHE_TTL}"},
    )


@app.get("/api/v1/history/cpid-churn")
@limiter.limit("30/minute")
async def history_cpid_churn(request: Request):
    """Daily time series of CPID activity — active count plus churn in/out."""
    return _history_response(_history_query("""
        SELECT obs_date,
               active_cpids,
               new_cpids,
               returning_cpids,
               churn_in,
               churn_out,
               departing_cpids
        FROM summary_cpid_churn
        ORDER BY obs_date
    """))


@app.get("/api/v1/history/project-active-cpids")
@limiter.limit("30/minute")
async def history_project_active_cpids(request: Request):
    """Daily time series of active (magnitude-positive) CPID counts per
    project. One row per (obs_date, project)."""
    return _history_response(_history_query("""
        SELECT obs_date, project, active_cpids, contributing_cpids,
               total_rac, total_mag
        FROM summary_project_active_cpids
        ORDER BY obs_date, project
    """))


@app.get("/api/v1/history/project-churn")
@limiter.limit("30/minute")
async def history_project_churn(request: Request):
    """Daily time series of projects in the superblock — total count
    plus day-over-day in/out counts (NULL on gap-adjacent days)."""
    return _history_response(_history_query("""
        SELECT obs_date, total_projects, projects_in, projects_out
        FROM summary_project_churn
        ORDER BY obs_date
    """))


@app.get("/api/v1/history/projects")
@limiter.limit("60/minute")
async def history_projects(request: Request):
    """List of all projects ever seen in the history, with first/last
    seen dates. Used to populate the per-project filter dropdown."""
    return _history_response(_history_query("""
        SELECT project                 AS name,
               min(obs_date)           AS first_seen,
               max(obs_date)           AS last_seen,
               count(DISTINCT obs_date) AS days_observed
        FROM fact_stats
        WHERE stats_type = 'byProject' AND project IS NOT NULL
        GROUP BY project
        ORDER BY project
    """))


@app.get("/api/v1/history/top-cpids")
@limiter.limit("30/minute")
async def history_top_cpids(
    request: Request,
    project: str | None = None,
    limit: int = 100,
    order_by: str = "lifetime_mag_sum",
):
    """Top CPIDs by lifetime magnitude. `project` filter switches the
    source table from network-wide to per-project rollup. `order_by`
    must be one of the allowed column names (prevents SQL injection)."""
    limit = max(1, min(500, limit))
    allowed_orders = {
        "lifetime_mag_avg_active",
        "lifetime_mag_avg_elapsed",
        "lifetime_mag_sum",
        "lifetime_rac_max",
        "lifetime_tc_max",
        "days_active",
    }
    if order_by not in allowed_orders:
        raise HTTPException(status_code=400, detail=f"order_by must be one of {sorted(allowed_orders)}")

    if project:
        rows = _history_query(
            f"""
            SELECT cpid, project, first_seen, last_seen,
                   days_active, days_observed, days_elapsed,
                   lifetime_mag_sum, lifetime_mag_avg_active,
                   lifetime_mag_avg_elapsed, lifetime_rac_max, lifetime_tc_max
            FROM summary_cpid_project_lifetime
            WHERE project = ?
            ORDER BY {order_by} DESC NULLS LAST
            LIMIT ?
            """,
            (project, limit),
        )
    else:
        rows = _history_query(
            f"""
            SELECT cpid, first_seen, last_seen,
                   days_active, days_observed, days_elapsed,
                   lifetime_mag_sum, lifetime_mag_avg_active,
                   lifetime_mag_avg_elapsed, lifetime_rac_max, lifetime_tc_max
            FROM summary_cpid_lifetime
            ORDER BY {order_by} DESC NULLS LAST
            LIMIT ?
            """,
            (limit,),
        )
    return _history_response(rows)


@app.get("/health")
async def health():
    """Health check endpoint."""
    has_cache = bool(_cache) and "_fetched_at" in _cache
    age = time.time() - _cache.get("_fetched_at", 0) if has_cache else None
    return {
        "status": "ok" if has_cache else "no_data",
        "cache_age_seconds": round(age) if age else None,
        "cache_ttl": CACHE_TTL,
    }


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "server:app",
        host=LISTEN_HOST,
        port=LISTEN_PORT,
        log_level="info",
    )
