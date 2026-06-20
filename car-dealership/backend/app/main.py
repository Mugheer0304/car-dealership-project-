"""
Car Dealership – FastAPI Backend
Loads secrets from AWS Secrets Manager (via External Secrets Operator injected env).
"""

import os
import time
import logging
import structlog
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_fastapi_instrumentator import Instrumentator

from app.database import engine, Base
from app.routes import cars, inquiries, health
from app.cache import get_redis_pool


# ── Structured logging ────────────────────────────────────────────────────────
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.JSONRenderer(),
    ]
)
logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown."""
    logger.info("startup", service="backend")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    app.state.redis = await get_redis_pool()
    yield
    logger.info("shutdown", service="backend")
    await app.state.redis.close()


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Car Dealership API",
    version="1.0.0",
    docs_url=None,      # Disable Swagger UI in production
    redoc_url=None,
    lifespan=lifespan,
)

# CORS – only allow requests from the frontend service
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "x-internal"],
)

# Prometheus metrics
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

# ── Request logging middleware ────────────────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    duration = (time.perf_counter() - start) * 1000
    logger.info(
        "request",
        method=request.method,
        path=request.url.path,
        status=response.status_code,
        duration_ms=round(duration, 2),
    )
    return response

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(health.router)
app.include_router(cars.router,      prefix="/api/cars",      tags=["cars"])
app.include_router(inquiries.router, prefix="/api/inquiries", tags=["inquiries"])

# ── Global error handler ─────────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_handler(request: Request, exc: Exception):
    logger.error("unhandled_error", error=str(exc), path=request.url.path)
    return JSONResponse(status_code=500, content={"error": "Internal server error"})
