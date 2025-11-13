from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
import structlog
from app.core.database import Database, get_db

logger = structlog.get_logger()
router = APIRouter()

@router.get("/health")
async def health_check(db: Database = Depends(get_db)):
    """Health check endpoint"""
    checks = {"api": "ok"}

    # Check database
    try:
        async with db.get_connection() as conn:
            await conn.fetchval("SELECT 1")
        checks["database"] = "ok"
    except Exception as e:
        logger.error("health_check_database_failed", error=str(e))
        checks["database"] = "error"

    all_ok = all(v == "ok" for v in checks.values())
    status_code = 200 if all_ok else 503

    return JSONResponse(
        status_code=status_code,
        content={
            "status": "ok" if all_ok else "degraded",
            "checks": checks
        }
    )
