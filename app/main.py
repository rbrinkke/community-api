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
    version=settings.API_VERSION,
    description="""Community and group management service with member roles and permissions.

Features 5 feature domains, stored procedure architecture, and comprehensive community lifecycle management.

## Key Features
- Community creation and management
- Member roles (owner/admin/member)
- Join requests and invitations
- Community settings and privacy
- Stored procedure architecture
- 5 feature domains (core/members/settings/moderation/analytics)

## Architecture
- Database: PostgreSQL with `activity` schema
- Auth: JWT Bearer with role validation
- Rate limiting: Per-endpoint rate limits""",
    lifespan=lifespan,
    docs_url="/docs" if settings.ENABLE_DOCS else None,
    redoc_url="/redoc" if settings.ENABLE_DOCS else None,
    openapi_url="/openapi.json" if settings.ENABLE_DOCS else None,
    contact={"name": "Activity Platform Team", "email": "dev@activityapp.com"},
    license_info={"name": "Proprietary"}
)


def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    from fastapi.openapi.utils import get_openapi
    openapi_schema = get_openapi(
        title=settings.PROJECT_NAME,
        version=settings.API_VERSION,
        description=app.description,
        routes=app.routes,
    )
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
            "description": "Enter JWT token from auth-api"
        }
    }
    openapi_schema["security"] = [{"BearerAuth": []}]
    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi

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
