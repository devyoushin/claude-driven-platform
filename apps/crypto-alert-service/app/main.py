"""Crypto Alert Service - 가격 알림 관리 및 발송"""

import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

from app.api.routes import router
from app.services.alert_evaluator import AlertEvaluator
from app.models.database import engine, Base
from app.metrics import custom_metrics

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup/shutdown"""
    # Startup
    logger.info("Starting Crypto Alert Service")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Start alert evaluator background task
    evaluator = AlertEvaluator()
    task = asyncio.create_task(evaluator.run())

    yield

    # Shutdown
    task.cancel()
    await engine.dispose()
    logger.info("Crypto Alert Service stopped")


app = FastAPI(
    title="Crypto Alert Service",
    description="가격 알림 조건 관리 및 알림 발송 서비스",
    version="1.0.0",
    lifespan=lifespan,
)

# Prometheus metrics
Instrumentator().instrument(app).expose(app, endpoint="/metrics")
custom_metrics.init()

# Routes
app.include_router(router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/ready")
async def ready():
    try:
        async with engine.connect() as conn:
            await conn.execute("SELECT 1")
        return {"status": "ready"}
    except Exception as e:
        return {"status": "not ready", "error": str(e)}, 503
