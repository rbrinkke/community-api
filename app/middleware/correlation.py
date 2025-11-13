import uuid
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
import structlog

class CorrelationMiddleware(BaseHTTPMiddleware):
    """
    Middleware to handle correlation IDs (X-Trace-ID)
    - Extracts existing correlation ID from request headers
    - Generates new correlation ID if not present
    - Binds correlation ID to structlog context
    - Adds correlation ID to response headers
    """

    async def dispatch(self, request: Request, call_next):
        # Extract or generate correlation ID
        correlation_id = request.headers.get("X-Trace-ID")
        if not correlation_id:
            correlation_id = str(uuid.uuid4())

        # Bind correlation ID to structlog context
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            correlation_id=correlation_id,
            path=request.url.path,
            method=request.method
        )

        # Process request
        response = await call_next(request)

        # Add correlation ID to response headers
        response.headers["X-Trace-ID"] = correlation_id

        return response
