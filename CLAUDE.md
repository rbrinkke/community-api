# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a **FastAPI microservice** for community management that follows a **stored procedure architecture**:

```
Routes (app/routes/) → Services (app/services/) → Stored Procedures (database/) → PostgreSQL
```

**Key principle**: Zero raw SQL in application code. All database logic lives in stored procedures.

### Architecture Layers

1. **Routes** (`app/routes/`): HTTP endpoint definitions, request validation, JWT auth
2. **Services** (`app/services/`): Business logic orchestration, calls stored procedures via `execute_stored_procedure()`
3. **Stored Procedures** (`database/stored_procedures.sql`): All database logic, constraints, and error handling
4. **Models** (`app/models/`): Pydantic v2 models for request/response validation

### Middleware Stack

Applied in order (see `app/main.py:41-48`):
1. `CorrelationMiddleware` - Adds correlation IDs to all requests
2. `CORSMiddleware` - CORS configuration (permissive in dev, restricted in prod)
3. Rate limiting via SlowAPI (Redis-backed)

## Database Integration

### Central Database Architecture

This service connects to a **shared PostgreSQL database** (`activity-postgres-db`) with a multi-schema design:
- Database: `activitydb`
- Schema: `activity`
- Shared with: `auth-api`, `moderation-api`

**CRITICAL**: When making database changes:
1. Update `database/stored_procedures.sql` with new/modified procedures
2. Test locally first with Docker rebuild
3. Database schema is managed centrally - coordinate with other services

### Stored Procedure Convention

All procedures follow: `activity.sp_community_<action>`

Example from `app/services/community_service.py:33-46`:
```python
results = await execute_stored_procedure(
    self.db,
    "activity.sp_community_create",  # Full procedure name with schema
    p_creator_user_id=creator_user_id,  # All params prefixed with p_
    p_slug=request.slug,
    # ... more parameters
)
```

Error handling is in the procedure - it raises exceptions like `RAISE EXCEPTION 'USER_NOT_FOUND'` which are caught and converted to HTTP exceptions by `app/core/errors.py`.

## Authentication

### JWT Integration

This service **validates** JWTs but does **not issue** them. JWTs come from `auth-api`.

**JWT Configuration** (must match auth-api):
- Secret key: `JWT_SECRET_KEY` env var (MUST be identical across services)
- Algorithm: HS256
- Token lifetime: 15 minutes

### Auth Dependencies

From `app/core/auth.py`:
- `get_current_user()` - Required auth, returns `CurrentUser` object
- `get_current_user_optional()` - Optional auth, returns `Optional[CurrentUser]`

`CurrentUser` fields:
- `user_id` (UUID from JWT `sub`)
- `email`
- `subscription_level` (free/premium/enterprise)
- `ghost_mode` (bool)
- `org_id` (optional)

## Common Development Commands

### Docker Development (Recommended)

**Build and start**:
```bash
docker compose build --no-cache && docker compose up -d
```

**IMPORTANT**: After code changes, always rebuild:
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

Note: `docker compose restart` does NOT pick up code changes - you MUST rebuild.

**View logs**:
```bash
docker compose logs -f community-api
```

**Stop service**:
```bash
docker compose down
```

### Local Development (Without Docker)

**Setup**:
```bash
cp .env.example .env
# Edit .env with local database/redis URLs
pip install -r requirements.txt
```

**Run service**:
```bash
uvicorn app.main:app --reload --port 8003
```

**Run tests**:
```bash
pytest
pytest tests/test_communities.py  # Single test file
pytest -v  # Verbose output
pytest -s  # Show print statements
```

## Service Configuration

### Port Assignments

- **Local development**: Port 8003
- **Docker**: Exposes 8003 (internally runs on 8000)
- **Other services**: auth-api (8000), moderation-api (8002)

### Docker Network

Uses external network `activity_default`:
- All activity services communicate on this network
- Must exist before starting this service
- Created by docker-compose in parent project

### Environment Variables

Critical vars (see `.env.example`):
- `DATABASE_URL` - PostgreSQL connection (points to `activity-postgres-db:5432`)
- `REDIS_URL` - Redis connection (points to `auth-redis:6379`)
- `JWT_SECRET_KEY` - **MUST match auth-api**
- `JWT_ALGORITHM` - Usually HS256
- `RATE_LIMIT_ENABLED` - Enable/disable rate limiting
- `LOG_LEVEL` - INFO (dev) or WARNING (prod)
- `ENVIRONMENT` - development/production

## Testing Strategy

Tests are in `tests/` directory using pytest + httpx.

`tests/conftest.py` provides:
- `event_loop` - Async event loop fixture
- `client` - AsyncClient for making test requests
- `setup_database` - Connects to DB before tests, disconnects after

## Logging

Uses **structlog** for structured JSON logging with correlation IDs.

All logs include:
- `timestamp`
- `level` (info, warning, error)
- `event` (e.g., "creating_community")
- `correlation_id` (from middleware)
- Context-specific fields (e.g., `slug`, `user_id`)

## Rate Limiting

SlowAPI with Redis backend. Limits are per-endpoint (see README.md for specific limits).

**How to add rate limiting** to an endpoint:
```python
from app.core.rate_limit import limiter

@router.post("/communities")
@limiter.limit("10/hour")  # 10 requests per hour
async def create_community(...):
    ...
```

## Common Gotchas

1. **Docker changes not appearing**: You MUST rebuild with `--no-cache`, not just restart
2. **JWT validation fails**: Ensure `JWT_SECRET_KEY` matches auth-api exactly
3. **Database connection fails**: Check that `activity_default` network exists and `activity-postgres-db` is running
4. **Rate limiting not working**: Verify `auth-redis` container is running and `RATE_LIMIT_ENABLED=true`
5. **Stored procedure errors**: Check logs for specific error codes raised by procedures (e.g., `USER_NOT_FOUND`)

## API Documentation

When service is running:
- **Swagger UI**: http://localhost:8003/docs
- **ReDoc**: http://localhost:8003/redoc
- **Health check**: http://localhost:8003/health
