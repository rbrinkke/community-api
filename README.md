# Community API

FastAPI microservice for community management with PostgreSQL stored procedures architecture.

## Features

- **20 REST API endpoints** for complete community management
- **18 stored procedures** - 100% database logic isolation (zero raw SQL in API code)
- **JWT authentication** - Compatible with auth-api
- **Rate limiting** - SlowAPI with Redis backend
- **Structured logging** - Correlation IDs on all requests
- **Type-safe** - Pydantic v2 models throughout
- **Docker-ready** - Full containerization with docker-compose

## Architecture

```
FastAPI ’ Service Layer ’ Stored Procedures ’ PostgreSQL
                “
         Rate Limiting (Redis)
                “
    Structured Logging (structlog)
```

## Tech Stack

- **Framework**: FastAPI 0.109
- **Database**: PostgreSQL 15 (asyncpg)
- **Cache/Rate Limiting**: Redis 7
- **Authentication**: JWT (python-jose)
- **Validation**: Pydantic v2
- **Logging**: structlog
- **Testing**: pytest + httpx

## Quick Start

### 1. Setup Environment

```bash
cp .env.example .env
# Edit .env with your configuration
```

### 2. Run with Docker

```bash
docker-compose up --build
```

The API will be available at `http://localhost:8000`

### 3. Initialize Database

The stored procedures are automatically loaded from `database/stored_procedures.sql` on first startup.

## API Endpoints

### Communities (7 endpoints)
- `POST /api/v1/communities` - Create community
- `GET /api/v1/communities/{id}` - Get community details
- `PATCH /api/v1/communities/{id}` - Update community
- `POST /api/v1/communities/{id}/join` - Join community
- `POST /api/v1/communities/{id}/leave` - Leave community
- `GET /api/v1/communities/{id}/members` - List members
- `GET /api/v1/communities/search` - Search communities

### Posts (4 endpoints)
- `POST /api/v1/communities/{id}/posts` - Create post
- `PATCH /api/v1/communities/{id}/posts/{post_id}` - Update post
- `DELETE /api/v1/communities/{id}/posts/{post_id}` - Delete post
- `GET /api/v1/communities/{id}/posts` - Get post feed

### Comments (4 endpoints)
- `POST /api/v1/communities/{id}/posts/{post_id}/comments` - Create comment
- `PATCH /api/v1/communities/{id}/posts/{post_id}/comments/{comment_id}` - Update comment
- `DELETE /api/v1/communities/{id}/posts/{post_id}/comments/{comment_id}` - Delete comment
- `GET /api/v1/communities/{id}/posts/{post_id}/comments` - Get comments

### Reactions (4 endpoints)
- `POST /api/v1/communities/{id}/posts/{post_id}/reactions` - React to post
- `DELETE /api/v1/communities/{id}/posts/{post_id}/reactions` - Remove post reaction
- `POST /api/v1/communities/{id}/posts/{post_id}/comments/{comment_id}/reactions` - React to comment
- `DELETE /api/v1/communities/{id}/posts/{post_id}/comments/{comment_id}/reactions` - Remove comment reaction

### Activity Links (1 endpoint)
- `POST /api/v1/communities/{id}/activities` - Link activity to community

## Documentation

- **OpenAPI Docs**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`
- **Health Check**: `http://localhost:8000/health`

## Development

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Run Locally

```bash
# Set up .env file first
uvicorn app.main:app --reload
```

### Run Tests

```bash
pytest
```

## Environment Variables

See `.env.example` for all configuration options:

- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `JWT_SECRET_KEY` - JWT signing key (must match auth-api)
- `RATE_LIMIT_ENABLED` - Enable/disable rate limiting
- `LOG_LEVEL` - Logging level (DEBUG, INFO, WARNING, ERROR)
- `ENVIRONMENT` - Environment name (development, production)

## Rate Limits

- Create community: 10/hour
- Update community: 20/hour
- Join community: 30/hour
- Leave community: 20/hour
- Create post: 50/hour
- Create comment: 100/hour
- Create reaction: 200/hour
- Link activity: 20/hour

## Error Handling

All errors return consistent JSON structure:

```json
{
  "detail": "Human-readable error message",
  "error_code": "MACHINE_READABLE_CODE",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**HTTP Status Codes**:
- 200/201: Success
- 400: Bad Request (business logic error)
- 401: Unauthorized (invalid/missing JWT)
- 403: Forbidden (insufficient permissions)
- 404: Not Found
- 409: Conflict (duplicate resource)
- 422: Validation Error
- 429: Rate Limit Exceeded
- 500: Internal Server Error

## Database Schema

The API uses stored procedures exclusively. See `database/stored_procedures.sql` for the complete database layer implementation.

**18 Stored Procedures**:
- Community operations (7)
- Post operations (4)
- Comment operations (4)
- Reaction operations (2)
- Activity linking (1)

## Logging

Structured logging with correlation IDs:

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "info",
  "event": "creating_community",
  "correlation_id": "abc-123",
  "slug": "my-community"
}
```

## Security

- JWT token validation on protected endpoints
- SQL injection prevention (stored procedures only)
- Rate limiting on mutation operations
- CORS configuration
- Input validation with Pydantic

## License

Proprietary

## Support

For issues and questions, contact the development team.
