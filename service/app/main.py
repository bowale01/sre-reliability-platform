"""
Demo multi-tenant SaaS API.

This service intentionally produces realistic SLI signals:
  - request latency (with a tunable slow path)
  - error rate (with a tunable fault-injection rate)
  - traffic, tagged per tenant

It exposes:
  - /healthz   liveness  (process is up)
  - /readyz    readiness (dependencies are reachable)
  - /metrics   Prometheus metrics (RED: Rate, Errors, Duration)
  - /api/...   tenant-aware business endpoints

Observability:
  - Prometheus metrics via prometheus_client
  - Datadog APM traces via ddtrace (auto-instruments FastAPI when run with `ddtrace-run`)
  - Structured JSON logs for Datadog log ingestion

Environment variables:
  SERVICE_NAME        logical service name (default: demo-service)
  FAULT_INJECTION     float 0..1, probability a request returns 5xx (default: 0.0)
  LATENCY_SLOW_RATIO  float 0..1, probability a request takes the slow path (default: 0.05)
  LATENCY_SLOW_MS     slow-path added latency in ms (default: 400)
  READY               "true"/"false" to simulate readiness state (default: true)
"""

from __future__ import annotations

import json
import logging
import os
import random
import time
from contextlib import asynccontextmanager
from typing import Callable

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse, PlainTextResponse
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #
SERVICE_NAME = os.getenv("SERVICE_NAME", "demo-service")
FAULT_INJECTION = float(os.getenv("FAULT_INJECTION", "0.0"))
LATENCY_SLOW_RATIO = float(os.getenv("LATENCY_SLOW_RATIO", "0.05"))
LATENCY_SLOW_MS = int(os.getenv("LATENCY_SLOW_MS", "400"))
_READY = os.getenv("READY", "true").lower() == "true"

VALID_TENANTS = {"acme", "globex", "initech", "umbrella", "default"}

# --------------------------------------------------------------------------- #
# Structured logging (JSON lines -> Datadog)
# --------------------------------------------------------------------------- #
class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "service": SERVICE_NAME,
        }
        for key in ("tenant", "path", "status_code", "duration_ms"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        return json.dumps(payload)


_handler = logging.StreamHandler()
_handler.setFormatter(JsonFormatter())
logging.basicConfig(level=logging.INFO, handlers=[_handler])
log = logging.getLogger(SERVICE_NAME)

# --------------------------------------------------------------------------- #
# Prometheus metrics (RED method)
# --------------------------------------------------------------------------- #
REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests.",
    ["service", "method", "path", "status_code", "tenant"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds.",
    ["service", "method", "path", "tenant"],
    # Buckets chosen so the 300ms latency SLO threshold sits on a boundary.
    buckets=(0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.0, 5.0),
)


def _tenant_from_request(request: Request) -> str:
    tenant = request.headers.get("x-tenant-id", "default").lower()
    return tenant if tenant in VALID_TENANTS else "default"


@asynccontextmanager
async def lifespan(_: FastAPI):
    log.info("starting up", extra={"path": "-"})
    yield
    log.info("shutting down", extra={"path": "-"})


app = FastAPI(title=SERVICE_NAME, lifespan=lifespan)


# --------------------------------------------------------------------------- #
# Middleware: record RED metrics + structured access log for every request
# --------------------------------------------------------------------------- #
@app.middleware("http")
async def observability_middleware(request: Request, call_next: Callable):
    # Don't instrument the scrape endpoint itself (keeps metrics clean).
    if request.url.path == "/metrics":
        return await call_next(request)

    tenant = _tenant_from_request(request)
    start = time.perf_counter()
    status_code = 500
    try:
        response: Response = await call_next(request)
        status_code = response.status_code
        return response
    finally:
        duration = time.perf_counter() - start
        path_label = request.scope.get("route").path if request.scope.get("route") else request.url.path
        REQUESTS.labels(
            SERVICE_NAME, request.method, path_label, str(status_code), tenant
        ).inc()
        REQUEST_LATENCY.labels(
            SERVICE_NAME, request.method, path_label, tenant
        ).observe(duration)
        log.info(
            "request",
            extra={
                "tenant": tenant,
                "path": path_label,
                "status_code": status_code,
                "duration_ms": round(duration * 1000, 2),
            },
        )


# --------------------------------------------------------------------------- #
# Health & readiness probes
# --------------------------------------------------------------------------- #
@app.get("/healthz", response_class=PlainTextResponse)
async def healthz() -> str:
    """Liveness: the process is running and the event loop responds."""
    return "ok"


@app.get("/readyz")
async def readyz() -> Response:
    """Readiness: report whether we should receive traffic."""
    if _READY:
        return JSONResponse({"status": "ready"}, status_code=200)
    return JSONResponse({"status": "not-ready"}, status_code=503)


@app.get("/metrics")
async def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


# --------------------------------------------------------------------------- #
# Business endpoints (tenant-aware) with injected latency / faults
# --------------------------------------------------------------------------- #
def _maybe_inject_latency() -> None:
    if random.random() < LATENCY_SLOW_RATIO:
        time.sleep(LATENCY_SLOW_MS / 1000.0)


def _maybe_inject_fault() -> bool:
    return random.random() < FAULT_INJECTION


@app.get("/api/courses")
async def list_courses(request: Request):
    tenant = _tenant_from_request(request)
    _maybe_inject_latency()
    if _maybe_inject_fault():
        return JSONResponse(
            {"error": "upstream dependency unavailable", "tenant": tenant},
            status_code=503,
        )
    return {
        "tenant": tenant,
        "courses": [
            {"id": "c-101", "title": "Intro to Reliability"},
            {"id": "c-102", "title": "Observability Fundamentals"},
            {"id": "c-103", "title": "Incident Command"},
        ],
    }


@app.get("/api/courses/{course_id}")
async def get_course(course_id: str, request: Request):
    tenant = _tenant_from_request(request)
    _maybe_inject_latency()
    if _maybe_inject_fault():
        return JSONResponse(
            {"error": "upstream dependency unavailable", "tenant": tenant},
            status_code=503,
        )
    return {"tenant": tenant, "course": {"id": course_id, "title": "Sample Course"}}


@app.get("/")
async def root():
    return {"service": SERVICE_NAME, "status": "running"}
