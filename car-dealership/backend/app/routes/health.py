from fastapi import APIRouter
import time

router = APIRouter()
_start = time.time()

@router.get("/health")
async def health():
    return {"status": "ok", "service": "backend", "uptime_s": round(time.time() - _start)}

@router.get("/ready")
async def ready():
    return {"status": "ready"}
