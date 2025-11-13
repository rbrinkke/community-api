from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
import structlog

from app.config import settings
from app.core.logging_config import setup_logging
from app.core.database import db
from app.core.rate_limit import limiter
from app.middleware.correlation import CorrelationMiddleware
from app.routes import health

# Setup logging
setup_logging(settings.ENVIRONMENT)
logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    # Startup
    logger.info("starting_application", environment=settings.ENVIRONMENT)
    await db.connect()
    yield
    # Shutdown
    logger.info("shutting_down_application")
    await db.disconnect()

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    lifespan=lifespan
)

# Rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Middleware
app.add_middleware(CorrelationMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.DEBUG else [],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(health.router, tags=["health"])

# API Routes (Phase 7)
from app.routes import communities, posts, comments, reactions, activity_links
app.include_router(
    communities.router,
    prefix=f"{settings.API_V1_PREFIX}/communities",
    tags=["communities"]
)
app.include_router(
    posts.router,
    prefix=f"{settings.API_V1_PREFIX}/communities",
    tags=["posts"]
)
app.include_router(
    comments.router,
    prefix=f"{settings.API_V1_PREFIX}/communities",
    tags=["comments"]
)
app.include_router(
    reactions.router,
    prefix=f"{settings.API_V1_PREFIX}/communities",
    tags=["reactions"]
)
app.include_router(
    activity_links.router,
    prefix=f"{settings.API_V1_PREFIX}/communities",
    tags=["activity-links"]
)

@app.get("/")
async def root():
    return {
        "service": settings.PROJECT_NAME,
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT
    }
